import AppKit
import Foundation
import BuddyCore
import BuddyFirebase
import Combine

@MainActor
final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published var items: [ClipboardHistoryItem] = []
    @Published var favorites: [FavoriteShortcut] = []
    @Published var selectedId: UUID?
    @Published var query: String = ""
    @Published var retentionDays: Int = UserDefaults.standard.object(forKey: BuddySettingsKey.clipboardRetentionDays) as? Int ?? 30
    @Published var maxHistoryCount: Int = ClipboardIgnoreSettings.maxHistoryCount

    let unlockSession = SensitiveUnlockSession.shared

    private var timer: Timer?
    private var lastChangeCount: Int = -1

    private let historyKey = "clipboard.history"
    private let favoritesKey = "clipboard.favorites"

    /// Skip individual flavors larger than this.
    private static let maxRepresentationBytes = 15_000_000
    /// Cap total stored bytes per clipboard change.
    private static let maxTotalBytes = 30_000_000

    private static let skippedTypePrefixes = [
        "com.apple.pasteboard.promised-",
        "dyn."
    ]

    init() {
        load()
    }

    var filtered: [ClipboardHistoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter {
            ($0.text?.lowercased().contains(q) ?? false)
                || $0.ocrText.lowercased().contains(q)
                || $0.tags.contains { $0.rawValue.contains(q) }
                || $0.preview.lowercased().contains(q)
                || $0.filePaths.contains { $0.lowercased().contains(q) }
                || $0.representations.contains { $0.type.lowercased().contains(q) }
        }
    }

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func pollPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if ClipboardIgnoreSettings.shouldIgnoreFrontmostApp() { return }

        guard let capture = Self.capturePasteboard(pb) else { return }

        if let text = capture.text, ContentSafety.evaluate(text: text).isBlocked {
            handleBlockedContent()
            return
        }

        if let imageData = capture.imageData {
            let change = lastChangeCount
            Task { @MainActor in
                let safety = await ContentSafety.evaluate(imageData: imageData)
                guard self.lastChangeCount == change else { return }
                if safety.isBlocked {
                    self.handleBlockedContent()
                    return
                }
                var item = capture.makeItem()
                item.ocrText = await Task.detached(priority: .utility) {
                    ScreenshotOCR.recognizedText(in: imageData)
                }.value
                self.prepend(item)
            }
            return
        }

        prepend(capture.makeItem())
    }

    /// Snapshot of everything currently on the general pasteboard.
    private struct PasteboardCapture {
        var text: String?
        var imageData: Data?
        var representations: [ClipboardRepresentation]
        var filePaths: [String]
        var tags: [ContentTag]
        var isSensitive: Bool

        func makeItem() -> ClipboardHistoryItem {
            ClipboardHistoryItem(
                text: text,
                imageData: imageData,
                representations: representations,
                filePaths: filePaths,
                tags: tags,
                isSensitive: isSensitive
            )
        }
    }

    private static func capturePasteboard(_ pb: NSPasteboard) -> PasteboardCapture? {
        var representations: [ClipboardRepresentation] = []
        var totalBytes = 0
        var seenTypes = Set<String>()

        if let items = pb.pasteboardItems {
            for item in items {
                for type in item.types {
                    let raw = type.rawValue
                    guard !seenTypes.contains(raw) else { continue }
                    if skippedTypePrefixes.contains(where: { raw.hasPrefix($0) }) { continue }
                    guard let data = item.data(forType: type), !data.isEmpty else { continue }
                    guard data.count <= maxRepresentationBytes else { continue }
                    guard totalBytes + data.count <= maxTotalBytes else { continue }
                    seenTypes.insert(raw)
                    totalBytes += data.count
                    representations.append(ClipboardRepresentation(type: raw, data: data))
                }
            }
        }

        // Fallback: types listed on the pasteboard itself (single-item / legacy writers).
        if representations.isEmpty, let types = pb.types {
            for type in types {
                let raw = type.rawValue
                guard !seenTypes.contains(raw) else { continue }
                if skippedTypePrefixes.contains(where: { raw.hasPrefix($0) }) { continue }
                guard let data = pb.data(forType: type), !data.isEmpty else { continue }
                guard data.count <= maxRepresentationBytes else { continue }
                guard totalBytes + data.count <= maxTotalBytes else { continue }
                seenTypes.insert(raw)
                totalBytes += data.count
                representations.append(ClipboardRepresentation(type: raw, data: data))
            }
        }

        let text = pb.string(forType: .string).flatMap { $0.isEmpty ? nil : $0 }
        var imageData: Data?
        if let image = NSImage(pasteboard: pb), let tiff = image.tiffRepresentation {
            imageData = tiff
        }

        var filePaths: [String] = []
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            filePaths = urls.filter(\.isFileURL).map(\.path)
        }
        if filePaths.isEmpty {
            for rep in representations where rep.type == NSPasteboard.PasteboardType.fileURL.rawValue
                || rep.type == "public.file-url"
            {
                if let s = String(data: rep.data, encoding: .utf8),
                   let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                   url.isFileURL
                {
                    filePaths.append(url.path)
                }
            }
        }

        guard text != nil || imageData != nil || !representations.isEmpty || !filePaths.isEmpty else {
            return nil
        }

        let tags = tagsForCapture(
            text: text,
            hasImage: imageData != nil,
            filePaths: filePaths,
            representations: representations
        )
        let sensitive = ContentTagger.containsSensitive(tags)
            || (text.map { ContentTagger.tag(text: $0).isSensitive } ?? false)

        return PasteboardCapture(
            text: text,
            imageData: imageData,
            representations: representations,
            filePaths: filePaths,
            tags: tags,
            isSensitive: sensitive
        )
    }

    private static func tagsForCapture(
        text: String?,
        hasImage: Bool,
        filePaths: [String],
        representations: [ClipboardRepresentation]
    ) -> [ContentTag] {
        var tags = Set<ContentTag>()
        if let text {
            tags.formUnion(ContentTagger.tag(text: text).tags)
        }
        if hasImage { tags.insert(.image) }
        if !filePaths.isEmpty {
            tags.insert(.file)
            tags.insert(.filePath)
        }
        for rep in representations {
            let t = rep.type.lowercased()
            if t.contains("rtf") || t.contains("html") { tags.insert(.richText) }
            if t.contains("pdf") { tags.insert(.pdf) }
            if t.contains("image") || t.contains("tiff") || t.contains("png") || t.contains("jpeg") {
                tags.insert(.image)
            }
            if t.contains("file-url") || t.contains("fileurl") {
                tags.insert(.file)
            }
        }
        if tags.isEmpty { tags.insert(.other) }
        return Array(tags)
    }

    func addFavorite(name: String, content: String) {
        if ContentSafety.evaluate(text: content).isBlocked {
            handleBlockedContent()
            return
        }
        favorites.insert(FavoriteShortcut(name: name, content: content), at: 0)
        save()
    }

    func isFavorited(content: String) -> Bool {
        favorites.contains { $0.content == content }
    }

    func toggleFavorite(name: String, content: String) {
        if let existing = favorites.first(where: { $0.content == content }) {
            removeFavorite(existing.id)
        } else {
            addFavorite(name: name, content: content)
        }
    }

    private func handleBlockedContent() {
        BuddyFirebase.log(event: BuddyFirebase.Event.contentBlocked)
        ContentSafety.notifyBlocked()
    }

    func prepend(_ item: ClipboardHistoryItem) {
        if let first = items.first {
            if first.text == item.text
                && first.imageData == item.imageData
                && first.filePaths == item.filePaths
                && first.representations.map(\.type) == item.representations.map(\.type)
                && first.representations.map(\.data) == item.representations.map(\.data)
            {
                return
            }
        }
        items.insert(item, at: 0)
        prune()
        save()
    }

    func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        items.removeAll { $0.createdAt < cutoff }
        let limit = max(maxHistoryCount, 1)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        if let selectedId, !items.contains(where: { $0.id == selectedId }) {
            self.selectedId = items.first?.id
        }
    }

    /// Applies current UserDefaults limits and persists if anything was trimmed.
    func applyHistoryLimits() {
        maxHistoryCount = ClipboardIgnoreSettings.maxHistoryCount
        let before = items.count
        prune()
        if items.count != before {
            save()
        } else {
            UserDefaults.standard.set(maxHistoryCount, forKey: BuddySettingsKey.clipboardMaxHistoryCount)
            UserDefaults.standard.set(retentionDays, forKey: BuddySettingsKey.clipboardRetentionDays)
        }
    }

    func clearAllHistory() {
        items.removeAll()
        selectedId = nil
        save()
    }

    func copyToPasteboard(_ item: ClipboardHistoryItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        if !item.representations.isEmpty {
            let pbItem = NSPasteboardItem()
            var wrote = false
            for rep in item.representations {
                if pbItem.setData(rep.data, forType: .init(rep.type)) {
                    wrote = true
                }
            }
            if wrote {
                pb.writeObjects([pbItem])
                // Don't re-stack our own restore into history.
                lastChangeCount = pb.changeCount
                return
            }
        }

        if let data = item.imageData, let image = NSImage(data: data) {
            pb.writeObjects([image])
        } else if !item.filePaths.isEmpty {
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
        } else if let text = item.text {
            pb.setString(text, forType: .string)
        }
        // Don't re-stack our own restore into history.
        lastChangeCount = pb.changeCount
    }

    func copyFavorite(_ favorite: FavoriteShortcut) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(favorite.content, forType: .string)
        // Favorites are explicit restores — don't duplicate into history.
        lastChangeCount = pb.changeCount
        BuddyFirebase.log(event: BuddyFirebase.Event.favoriteCopied)
    }

    /// Text payload suitable for encoding into a QR code.
    func qrPayload(for item: ClipboardHistoryItem) -> String? {
        if let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if !item.filePaths.isEmpty {
            return item.filePaths.joined(separator: "\n")
        }
        return nil
    }

    func makeQRImage(for item: ClipboardHistoryItem) -> NSImage? {
        guard let payload = qrPayload(for: item) else { return nil }
        return QRCodeGenerator.makeImage(from: payload)
    }

    func copyQRCodeToPasteboard(for item: ClipboardHistoryItem) -> Bool {
        guard let image = makeQRImage(for: item) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        // Don't capture the generated QR image as a new history entry.
        lastChangeCount = pb.changeCount
        return true
    }

    func removeFavorite(_ id: UUID) {
        favorites.removeAll { $0.id == id }
        save()
    }

    func isHidden(_ item: ClipboardHistoryItem) -> Bool {
        let sensitive = ContentTagger.containsSensitive(item.tags)
            || (item.text.map { ContentTagger.tag(text: $0).isSensitive } ?? false)
        return unlockSession.shouldHide(isSensitive: sensitive)
    }

    func reveal(item: ClipboardHistoryItem, completion: @escaping (Bool) -> Void) {
        unlockSession.unlock(reason: "Reveal sensitive clipboard item") { success in
            if success {
                BuddyFirebase.log(event: BuddyFirebase.Event.sensitiveRevealed)
            }
            completion(success)
        }
    }

    /// Preview text safe for menu bar / list when sensitive and locked.
    func displayPreview(for item: ClipboardHistoryItem) -> String {
        if isHidden(item) { return "•••• Sensitive" }
        return item.preview
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
        UserDefaults.standard.set(retentionDays, forKey: BuddySettingsKey.clipboardRetentionDays)
        UserDefaults.standard.set(maxHistoryCount, forKey: BuddySettingsKey.clipboardMaxHistoryCount)
    }

    /// Replaces history/favorites for App Store marketing captures.
    func installMarketingSeed() {
        UserDefaults.standard.set(true, forKey: BuddySettingsKey.requireAuthSensitiveContent)
        UserDefaults.standard.set(
            "password,iban,creditCard,apiKey,bearerToken,otp,email,phone,amount",
            forKey: BuddySettingsKey.protectedContentTags
        )
        SensitiveUnlockSession.shared.lock()

        let now = Date()
        let url = ClipboardHistoryItem(
            id: MarketingClipID.url,
            text: "https://docs.buddy.app",
            representations: [
                ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("https://docs.buddy.app".utf8))
            ],
            tags: [.url, .text],
            isSensitive: false,
            createdAt: now.addingTimeInterval(-360),
            isFavorite: true
        )
        let agenda = ClipboardHistoryItem(
            id: MarketingClipID.agenda,
            text: "Meeting agenda draft\n1. Screenshots\n2. Localization\n3. Store copy",
            representations: [
                ClipboardRepresentation(
                    type: "public.utf8-plain-text",
                    data: Data("Meeting agenda draft\n1. Screenshots\n2. Localization\n3. Store copy".utf8)
                )
            ],
            tags: [.text],
            isSensitive: false,
            createdAt: now.addingTimeInterval(-300)
        )
        let color = ClipboardHistoryItem(
            id: MarketingClipID.color,
            text: "#10B981",
            representations: [
                ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("#10B981".utf8))
            ],
            tags: [.colorHex, .text],
            isSensitive: false,
            createdAt: now.addingTimeInterval(-240),
            isFavorite: true
        )
        let password = ClipboardHistoryItem(
            id: MarketingClipID.password,
            text: "SuperSecret-Clipboard-Passphrase!",
            representations: [
                ClipboardRepresentation(
                    type: "public.utf8-plain-text",
                    data: Data("SuperSecret-Clipboard-Passphrase!".utf8)
                )
            ],
            tags: [.password, .text],
            isSensitive: true,
            createdAt: now.addingTimeInterval(-180)
        )
        let iban = ClipboardHistoryItem(
            id: MarketingClipID.iban,
            text: "NL91 ABNA 0417 1643 00",
            representations: [
                ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("NL91 ABNA 0417 1643 00".utf8))
            ],
            tags: [.iban, .text],
            isSensitive: true,
            createdAt: now.addingTimeInterval(-120)
        )
        let apiKey = ClipboardHistoryItem(
            id: MarketingClipID.apiKey,
            text: "buddy_demo_api_key_51HqMarketingOnly",
            representations: [
                ClipboardRepresentation(
                    type: "public.utf8-plain-text",
                    data: Data("buddy_demo_api_key_51HqMarketingOnly".utf8)
                )
            ],
            tags: [.apiKey, .text],
            isSensitive: true,
            createdAt: now.addingTimeInterval(-90)
        )
        let release = ClipboardHistoryItem(
            id: MarketingClipID.release,
            text: "Release notes draft\n• Faster OCR\n• Menu bar pause\n• Privacy unlock session",
            representations: [
                ClipboardRepresentation(
                    type: "public.utf8-plain-text",
                    data: Data("Release notes draft\n• Faster OCR\n• Menu bar pause\n• Privacy unlock session".utf8)
                ),
                ClipboardRepresentation(
                    type: "public.rtf",
                    data: Data("{\\rtf1 Release notes draft}".utf8)
                )
            ],
            tags: [.text, .richText],
            isSensitive: false,
            createdAt: now.addingTimeInterval(-60)
        )
        let share = ClipboardHistoryItem(
            id: MarketingClipID.share,
            text: "https://buddy.app/share/42",
            representations: [
                ClipboardRepresentation(type: "public.utf8-plain-text", data: Data("https://buddy.app/share/42".utf8))
            ],
            tags: [.url, .text],
            isSensitive: false,
            createdAt: now.addingTimeInterval(-30)
        )
        let image = ClipboardHistoryItem(
            id: MarketingClipID.image,
            text: nil,
            imageData: BuddyMarketingFixtures.tinySwatch(),
            representations: [
                ClipboardRepresentation(type: "public.png", data: BuddyMarketingFixtures.tinySwatch())
            ],
            tags: [.image],
            isSensitive: false,
            createdAt: now
        )

        items = [url, agenda, color, password, iban, apiKey, release, share, image]
        favorites = [
            FavoriteShortcut(id: MarketingClipID.favSupport, name: "Support link", content: "https://help.buddy.app", createdAt: now.addingTimeInterval(-400)),
            FavoriteShortcut(id: MarketingClipID.favEmail, name: "Work email", content: "you@company.com", createdAt: now.addingTimeInterval(-380)),
            FavoriteShortcut(id: MarketingClipID.favColor, name: "Brand green", content: "#10B981", createdAt: now.addingTimeInterval(-360))
        ]
        selectedId = MarketingClipID.url
        save()
    }

    enum MarketingClipID {
        static let url = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000001")!
        static let agenda = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000002")!
        static let color = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000003")!
        static let password = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000004")!
        static let iban = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000005")!
        static let apiKey = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000006")!
        static let release = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000007")!
        static let share = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000008")!
        static let image = UUID(uuidString: "BBBBBBBB-0001-4000-8000-000000000009")!
        static let favSupport = UUID(uuidString: "BBBBBBBB-0001-4000-8000-0000000000A1")!
        static let favEmail = UUID(uuidString: "BBBBBBBB-0001-4000-8000-0000000000A2")!
        static let favColor = UUID(uuidString: "BBBBBBBB-0001-4000-8000-0000000000A3")!
    }

    private func load() {
        maxHistoryCount = ClipboardIgnoreSettings.maxHistoryCount
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) {
            items = decoded
        }
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteShortcut].self, from: data) {
            favorites = decoded
        }
        let before = items.count
        prune()
        if items.count != before {
            save()
        }
        backfillMissingOCR()
    }

    /// Fills OCR search text for older image items that predate `ocrText`.
    private func backfillMissingOCR() {
        // Avoid long Vision work while unit tests construct stores against real defaults.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        let pending = items.compactMap { item -> (UUID, Data)? in
            guard let data = item.imageData, item.ocrText.isEmpty else { return nil }
            return (item.id, data)
        }
        guard !pending.isEmpty else { return }
        Task { @MainActor in
            var didChange = false
            for (id, data) in pending {
                let text = await Task.detached(priority: .utility) {
                    ScreenshotOCR.recognizedText(in: data)
                }.value
                guard let idx = items.firstIndex(where: { $0.id == id }),
                      items[idx].imageData == data,
                      items[idx].ocrText.isEmpty else { continue }
                items[idx].ocrText = text
                didChange = true
            }
            if didChange { save() }
        }
    }
}
