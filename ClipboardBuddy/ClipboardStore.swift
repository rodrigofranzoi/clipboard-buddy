import AppKit
import Foundation
import LocalAuthentication
import BuddyCore
import BuddyFirebase
import Combine

@MainActor
final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published var items: [ClipboardHistoryItem] = []
    @Published var favorites: [FavoriteShortcut] = []
    @Published var query: String = ""
    @Published var revealedIds: Set<UUID> = []
    @Published var retentionDays: Int = UserDefaults.standard.object(forKey: BuddySettingsKey.clipboardRetentionDays) as? Int ?? 30

    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private let defaultsKey = "clipboard.history"
    private let favoritesKey = "clipboard.favorites"

    init() {
        load()
    }

    var filtered: [ClipboardHistoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter {
            ($0.text?.lowercased().contains(q) ?? false)
                || $0.tags.contains { $0.rawValue.contains(q) }
                || $0.preview.lowercased().contains(q)
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

    func pollPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let image = NSImage(pasteboard: pb), let tiff = image.tiffRepresentation {
            let tagged = ContentTagger.tag(.image)
            let item = ClipboardHistoryItem(imageData: tiff, tags: Array(tagged.tags), isSensitive: tagged.isSensitive)
            prepend(item)
            return
        }

        if let str = pb.string(forType: .string), !str.isEmpty {
            let tagged = ContentTagger.tag(text: str)
            let item = ClipboardHistoryItem(text: str, tags: Array(tagged.tags), isSensitive: tagged.isSensitive)
            prepend(item)
        }
    }

    func prepend(_ item: ClipboardHistoryItem) {
        if let first = items.first {
            if first.text == item.text && first.imageData == item.imageData { return }
        }
        items.insert(item, at: 0)
        prune()
        save()
    }

    func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        items.removeAll { $0.createdAt < cutoff }
    }

    func copyToPasteboard(_ item: ClipboardHistoryItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let data = item.imageData, let image = NSImage(data: data) {
            pb.writeObjects([image])
        } else if let text = item.text {
            pb.setString(text, forType: .string)
        }
    }

    func copyFavorite(_ favorite: FavoriteShortcut) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(favorite.content, forType: .string)
        BuddyFirebase.log(event: BuddyFirebase.Event.favoriteCopied)
    }

    func addFavorite(name: String, content: String) {
        favorites.insert(FavoriteShortcut(name: name, content: content), at: 0)
        save()
    }

    func removeFavorite(_ id: UUID) {
        favorites.removeAll { $0.id == id }
        save()
    }

    func reveal(item: ClipboardHistoryItem, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Reveal sensitive clipboard item") { success, _ in
                Task { @MainActor in
                    if success {
                        self.revealedIds.insert(item.id)
                        BuddyFirebase.log(event: BuddyFirebase.Event.sensitiveRevealed)
                    }
                    completion(success)
                }
            }
        } else {
            revealedIds.insert(item.id)
            completion(true)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
        UserDefaults.standard.set(retentionDays, forKey: BuddySettingsKey.clipboardRetentionDays)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) {
            items = decoded
        }
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteShortcut].self, from: data) {
            favorites = decoded
        }
    }
}
