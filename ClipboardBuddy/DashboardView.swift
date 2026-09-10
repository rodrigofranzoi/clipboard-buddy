import SwiftUI
import BuddyCore
import BuddyUI
import AppKit

private enum DashboardListMode: String, CaseIterable, Identifiable {
    case history
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "History"
        case .favorites: return "Favorites"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var listMode: DashboardListMode = .history
    @State private var selectedFavoriteId: UUID?
    @State private var qrPreviewItem: ClipboardHistoryItem?

    private var selected: ClipboardHistoryItem? {
        store.items.first { $0.id == store.selectedId }
    }

    private var selectedFavorite: FavoriteShortcut? {
        store.favorites.first { $0.id == selectedFavoriteId }
    }

    private var selectedIsFavorited: Bool {
        guard let text = selected?.text else { return false }
        return store.isFavorited(content: text)
    }

    private var filteredFavorites: [FavoriteShortcut] {
        let q = store.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.favorites }
        return store.favorites.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.content.localizedCaseInsensitiveContains(q)
        }
    }

    private var historySelection: Binding<UUID?> {
        Binding(
            get: { store.selectedId },
            set: { newValue in
                guard store.selectedId != newValue else { return }
                DispatchQueue.main.async {
                    store.selectedId = newValue
                }
            }
        )
    }

    private var favoriteSelection: Binding<UUID?> {
        Binding(
            get: { selectedFavoriteId },
            set: { newValue in
                guard selectedFavoriteId != newValue else { return }
                DispatchQueue.main.async {
                    selectedFavoriteId = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: BuddyTheme.Spacing.md) {
                Picker(selection: $listMode) {
                    ForEach(DashboardListMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, BuddyTheme.Spacing.lg)
                .padding(.top, BuddyTheme.Spacing.md)
                .accessibilityLabel("History or Favorites")
                .accessibilityIdentifier("dashboard-list-mode")

                BuddyListChrome(query: $store.query) {
                    switch listMode {
                    case .history:
                        historyList
                    case .favorites:
                        favoritesList
                    }
                }
            }
            .navigationTitle(listMode == .favorites ? "Favorites" : "History")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 420)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        NotificationCenter.default.post(name: .clipboardToggleFloatingHistory, object: nil)
                    } label: {
                        Image(systemName: "clock")
                    }
                    .help("Floating History")
                    .accessibilityIdentifier("toolbar-floating-history")

                    Button {
                        NotificationCenter.default.post(name: .clipboardToggleFloatingFavorites, object: nil)
                    } label: {
                        Image(systemName: "swatchpalette")
                    }
                    .help("Floating Favorites")
                    .accessibilityIdentifier("toolbar-floating-favorites")
                }
            }
        } detail: {
            Group {
                switch listMode {
                case .history:
                    if let selected {
                        DetailPane(item: selected, onMakeQRCode: { presentQR(for: selected) })
                    } else {
                        emptyDetail(systemImage: "doc.on.clipboard", message: "Select an item")
                    }
                case .favorites:
                    if let selectedFavorite {
                        FavoriteDetailPane(favorite: selectedFavorite)
                    } else {
                        emptyDetail(systemImage: "star", message: "Select an item")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard listMode == .history, let selected, let text = selected.text else { return }
                    store.toggleFavorite(name: selected.preview, content: text)
                } label: {
                    Image(systemName: selectedIsFavorited ? "star.fill" : "star")
                }
                .disabled(listMode != .history || selected?.text == nil)
                .help(selectedIsFavorited ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(selectedIsFavorited ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityIdentifier("add-favorite")
            }
            ToolbarItem(placement: .primaryAction) {
                BuddyClearHistoryButton(itemNoun: "clippings", style: .toolbar) {
                    store.clearAllHistory()
                }
                .disabled(store.items.isEmpty)
            }
        }
        .sheet(item: $qrPreviewItem) { item in
            QRCodePreviewSheet(item: item)
                .environmentObject(store)
        }
        .onChange(of: listMode) { mode in
            if mode == .favorites, selectedFavoriteId == nil {
                selectedFavoriteId = filteredFavorites.first?.id
            }
        }
        .onChange(of: store.items.first?.id) { id in
            guard id != nil, listMode != .history else { return }
            listMode = .history
        }
        .onReceive(NotificationCenter.default.publisher(for: .buddyMarketingStageScene)) { note in
            guard let scene = note.userInfo?[BuddyMarketingCapture.sceneKey] as? String,
                  scene == "qr",
                  let item = store.items.first(where: { $0.id == ClipboardStore.MarketingClipID.share })
            else { return }
            qrPreviewItem = item
        }
        .buddyDigitCopyShortcuts(itemCount: digitCopyCount) { index in
            copyItem(atDigitIndex: index)
        }
    }

    private var digitCopyCount: Int {
        switch listMode {
        case .history: return min(store.filtered.count, 10)
        case .favorites: return min(filteredFavorites.count, 10)
        }
    }

    private func copyItem(atDigitIndex index: Int) {
        switch listMode {
        case .history:
            let items = store.filtered
            guard items.indices.contains(index) else { return }
            let item = items[index]
            guard !store.isHidden(item) else { return }
            store.selectedId = item.id
            store.copyToPasteboard(item)
        case .favorites:
            let items = filteredFavorites
            guard items.indices.contains(index) else { return }
            let favorite = items[index]
            selectedFavoriteId = favorite.id
            store.copyFavorite(favorite)
        }
    }

    @ViewBuilder
    private var historyList: some View {
        ScrollViewReader { proxy in
            List(selection: historySelection) {
                ForEach(Array(store.filtered.enumerated()), id: \.element.id) { index, item in
                    HistoryRow(
                        item: item,
                        shortcutHint: index < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: index) : nil
                    )
                    .tag(item.id)
                    .id(item.id)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(BuddyTheme.BuddyColor.border.opacity(0.4))
                    .accessibilityIdentifier("history-row")
                    .contextMenu {
                        if !store.isHidden(item) {
                            if store.qrPayload(for: item) != nil {
                                Button("Make QR Code") {
                                    presentQR(for: item)
                                }
                            }
                            if let text = item.text {
                                Button(store.isFavorited(content: text) ? "Remove from Favorites" : "Add to Favorites") {
                                    store.toggleFavorite(name: item.preview, content: text)
                                }
                            }
                            Button("Copy to Clipboard") {
                                store.copyToPasteboard(item)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityIdentifier("history-list")
            .onAppear {
                focusHistory(on: store.selectedId, proxy: proxy)
            }
            .onChange(of: store.selectedId) { id in
                focusHistory(on: id, proxy: proxy)
            }
            .onChange(of: store.items.first?.id) { id in
                focusHistory(on: id ?? store.selectedId, proxy: proxy)
            }
        }
    }

    private func focusHistory(on id: UUID?, proxy: ScrollViewProxy) {
        guard let id, store.filtered.contains(where: { $0.id == id }) else { return }
        DispatchQueue.main.async {
            if listMode != .history {
                listMode = .history
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    @ViewBuilder
    private var favoritesList: some View {
        if filteredFavorites.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "star")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No favorites yet")
                    .foregroundStyle(.secondary)
                Text("Star a history item to pin it here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .accessibilityIdentifier("favorites-list-empty")
        } else {
            List(selection: favoriteSelection) {
                ForEach(Array(filteredFavorites.enumerated()), id: \.element.id) { index, favorite in
                    FavoriteRow(
                        favorite: favorite,
                        shortcutHint: index < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: index) : nil
                    )
                    .tag(favorite.id)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(BuddyTheme.BuddyColor.border.opacity(0.4))
                    .accessibilityIdentifier("favorite-row")
                    .contextMenu {
                        Button("Copy to Clipboard") {
                            store.copyFavorite(favorite)
                        }
                        Button("Remove from Favorites", role: .destructive) {
                            if selectedFavoriteId == favorite.id {
                                selectedFavoriteId = nil
                            }
                            store.removeFavorite(favorite.id)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityIdentifier("favorites-list")
        }
    }

    private func emptyDetail(systemImage: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
            Text(LocalizedStringKey(message))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presentQR(for item: ClipboardHistoryItem) {
        guard store.qrPayload(for: item) != nil else { return }
        if store.isHidden(item) {
            store.reveal(item: item) { success in
                if success { qrPreviewItem = item }
            }
        } else {
            qrPreviewItem = item
        }
    }
}

struct HistoryRow: View {
    @EnvironmentObject private var store: ClipboardStore
    @ObservedObject private var unlock = SensitiveUnlockSession.shared
    @AppStorage(BuddySettingsKey.autoBlurContentTags) private var protectedTagsRaw: String = ""
    @AppStorage(BuddySettingsKey.requireAuthSensitiveContent) private var requireAuth = false
    @State private var justCopied = false
    let item: ClipboardHistoryItem
    var shortcutHint: String? = nil

    private var isHidden: Bool {
        _ = protectedTagsRaw
        _ = requireAuth
        _ = unlock.unlockedUntil
        return store.isHidden(item)
    }

    var body: some View {
        HStack(alignment: .center, spacing: BuddyTheme.Spacing.sm) {
            ClipboardCellLeadingIcon(kind: .resolve(item: item, isHidden: isHidden))

            SensitiveBlurView(isHidden: isHidden) {
                store.reveal(item: item) { _ in }
            } content: {
                Text(item.preview)
                    .font(.buddyBody)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let shortcutHint {
                Text(verbatim: shortcutHint)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            if !isHidden {
                Button {
                    store.copyToPasteboard(item)
                    justCopied = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        justCopied = false
                    }
                } label: {
                    Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundStyle(justCopied ? BuddyTheme.BuddyColor.success : Color.primary)
                }
                .buttonStyle(.borderless)
                .frame(width: 18, height: 18)
                .accessibilityLabel(justCopied ? "Copied" : "Copy")
                .help(justCopied ? "Copied" : "Copy to clipboard")
            }
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .accessibilityValue(shortcutHint.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
    }
}

struct FavoriteRow: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var justCopied = false
    let favorite: FavoriteShortcut
    var shortcutHint: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: BuddyTheme.Spacing.sm) {
            ClipboardCellLeadingIcon(kind: .resolve(favorite: favorite))

            Text(favorite.name)
                .font(.buddyBody)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutHint {
                Text(verbatim: shortcutHint)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            Button {
                store.copyFavorite(favorite)
                justCopied = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    justCopied = false
                }
            } label: {
                Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(justCopied ? BuddyTheme.BuddyColor.success : Color.primary)
            }
            .buttonStyle(.borderless)
            .frame(width: 18, height: 18)
            .accessibilityLabel(justCopied ? "Copied" : "Copy")
            .help(justCopied ? "Copied" : "Copy to clipboard")
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
        .accessibilityValue(shortcutHint.map { Text(verbatim: $0) } ?? Text(verbatim: ""))
    }
}

struct ColorSwatchView: View {
    let color: NSColor
    var size: CGFloat = 18
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: color))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .accessibilityLabel("Color swatch")
    }
}

struct DetailPane: View {
    @EnvironmentObject private var store: ClipboardStore
    @ObservedObject private var unlock = SensitiveUnlockSession.shared
    @AppStorage(BuddySettingsKey.autoBlurContentTags) private var protectedTagsRaw: String = ""
    @AppStorage(BuddySettingsKey.requireAuthSensitiveContent) private var requireAuth = false
    @State private var justCopied = false
    let item: ClipboardHistoryItem
    var onMakeQRCode: () -> Void = {}

    private var isHidden: Bool {
        _ = protectedTagsRaw
        _ = requireAuth
        _ = unlock.unlockedUntil
        return store.isHidden(item)
    }

    private var canMakeQR: Bool {
        store.qrPayload(for: item) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let color = item.listColor {
                    colorPreview(color)
                }
                if let data = item.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .accessibilityLabel("Clipboard image")
                }
                if !item.filePaths.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Files")
                            .font(.headline)
                        ForEach(item.filePaths, id: \.self) { path in
                            Text(path)
                                .font(.buddyBody)
                                .textSelection(.enabled)
                        }
                    }
                }
                SensitiveBlurView(isHidden: isHidden) {
                    store.reveal(item: item) { _ in }
                } content: {
                    Text(detailBodyText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !item.representations.isEmpty {
                    Text("\(item.representations.count) pasteboard flavor\(item.representations.count == 1 ? "" : "s") stored")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    ForEach(item.tags, id: \.self) { TagChip(tag: $0) }
                }
                HStack(spacing: 12) {
                    if let url = item.listOpenableURL {
                        Button("Open Link") {
                            if isHidden {
                                store.reveal(item: item) { success in
                                    if success { NSWorkspace.shared.open(url) }
                                }
                            } else {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    Button(justCopied ? "Copied" : "Copy to Clipboard") {
                        store.copyToPasteboard(item)
                        justCopied = true
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            justCopied = false
                        }
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    if canMakeQR {
                        Button("Make QR Code") {
                            onMakeQRCode()
                        }
                        .accessibilityIdentifier("make-qr-code")
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("detail-pane")
    }

    private var detailBodyText: String {
        if let text = item.text, !text.isEmpty { return text }
        if item.imageData != nil { return "Image" }
        if !item.filePaths.isEmpty {
            return item.filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: "\n")
        }
        return item.preview
    }
}

struct FavoriteDetailPane: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var justCopied = false
    let favorite: FavoriteShortcut

    private var color: NSColor? {
        DetectedContentExtractor.extractTokens(from: favorite.content, limit: 4)
            .first(where: { $0.kind == .color })?
            .nsColor
    }

    private var openURL: URL? {
        DetectedContentToken.openableURL(from: favorite.content)
            ?? DetectedContentExtractor.extractTokens(from: favorite.content, limit: 4)
            .first(where: { $0.kind == .url })?
            .openableURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let color {
                    colorPreview(color)
                }
                Text(favorite.name)
                    .font(.title2.weight(.semibold))
                Text(favorite.content)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    if let openURL {
                        Button("Open Link") {
                            NSWorkspace.shared.open(openURL)
                        }
                    }
                    Button(justCopied ? "Copied" : "Copy to Clipboard") {
                        store.copyFavorite(favorite)
                        justCopied = true
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            justCopied = false
                        }
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    Button("Remove from Favorites", role: .destructive) {
                        store.removeFavorite(favorite.id)
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("favorite-detail-pane")
    }
}

@ViewBuilder
private func colorPreview(_ color: NSColor) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Color")
            .font(.headline)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: color))
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel("Color swatch")
    }
}

struct QRCodePreviewSheet: View {
    @EnvironmentObject private var store: ClipboardStore
    @Environment(\.dismiss) private var dismiss
    let item: ClipboardHistoryItem
    @State private var copied = false

    private var qrImage: NSImage? {
        store.makeQRImage(for: item)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("QR Code")
                .font(.headline)
            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .accessibilityLabel("QR code")
            } else {
                Text("Could not create a QR code for this item.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let payload = store.qrPayload(for: item) {
                Text(payload)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: 320)
            }
            HStack {
                Button("Copy Image") {
                    if store.copyQRCodeToPasteboard(for: item) {
                        copied = true
                    }
                }
                .disabled(qrImage == nil)
                .keyboardShortcut("c", modifiers: [.command])
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            if copied {
                Text("Copied to clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .accessibilityIdentifier("qr-code-sheet")
    }
}
