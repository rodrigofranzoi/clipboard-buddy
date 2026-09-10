import AppKit
import SwiftUI
import BuddyCore
import BuddyUI

extension Notification.Name {
    static let clipboardToggleFloatingHistory = Notification.Name("clipboard.buddy.toggleFloatingHistory")
    static let clipboardToggleFloatingFavorites = Notification.Name("clipboard.buddy.toggleFloatingFavorites")
    static let clipboardDismissMenuBarPopover = Notification.Name("clipboard.buddy.dismissMenuBarPopover")
}

enum FloatingClipboardKind: Equatable {
    case history
    case favorites

    var title: String {
        switch self {
        case .history: return "History"
        case .favorites: return "Favorites"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .history: return "floating-clipboard-history"
        case .favorites: return "floating-clipboard-favorites"
        }
    }
}

@MainActor
final class FloatingClipboardPanelController {
    private var panel: NSPanel?
    private weak var store: ClipboardStore?
    private let kind: FloatingClipboardKind

    init(kind: FloatingClipboardKind) {
        self.kind = kind
    }

    func attach(store: ClipboardStore) {
        self.store = store
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        guard let store else { return }
        if panel == nil {
            panel = makePanel(store: store)
        }
        guard let panel else { return }
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    var panelWindow: NSWindow? {
        panel?.isVisible == true ? panel : nil
    }

    private func makePanel(store: ClipboardStore) -> NSPanel {
        let hosting = NSHostingController(
            rootView: FloatingClipboardPanelView(kind: kind)
                .environmentObject(store)
                .buddyAppearance(brand: .clipboardBuddy)
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 440),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = kind == .history
            ? BuddyBrand.clipboardBuddy.displayName
            : String(localized: "Favorites")
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 240, height: 280)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let offset: CGFloat = kind == .history ? 320 : 640
            panel.setFrameOrigin(NSPoint(x: frame.maxX - offset, y: frame.midY - 220))
        }
        return panel
    }
}

struct FloatingClipboardPanelView: View {
    @EnvironmentObject private var store: ClipboardStore
    let kind: FloatingClipboardKind

    @AppStorage(BuddySettingsKey.clipboardMenuBarRecentCount) private var recentCount =
        ClipboardIgnoreSettings.defaultMenuBarRecentCount
    @State private var copiedItemId: UUID?

    private var historyItems: [ClipboardHistoryItem] {
        Array(store.items.prefix(max(recentCount * 2, 20)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch kind {
            case .history:
                historyContent
            case .favorites:
                favoritesContent
            }
        }
        .frame(minWidth: 240, minHeight: 280)
        .accessibilityIdentifier(kind.accessibilityIdentifier)
        .buddyDigitCopyShortcuts(itemCount: digitCopyCount) { index in
            copyDigitItem(at: index)
        }
    }

    private var digitCopyCount: Int {
        switch kind {
        case .history: return min(historyItems.count, 10)
        case .favorites: return min(store.favorites.count, 10)
        }
    }

    private func copyDigitItem(at index: Int) {
        switch kind {
        case .history:
            guard historyItems.indices.contains(index) else { return }
            let item = historyItems[index]
            guard !store.isHidden(item) else { return }
            store.selectedId = item.id
            store.copyToPasteboard(item)
            markCopied(item.id)
        case .favorites:
            guard store.favorites.indices.contains(index) else { return }
            let favorite = store.favorites[index]
            store.copyFavorite(favorite)
            markCopied(favorite.id)
        }
    }

    private var header: some View {
        HStack(spacing: BuddyTheme.Spacing.xs) {
            Text(LocalizedStringKey(kind.title))
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                BuddyMainWindow.show()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.borderless)
            .help("Open")
            .accessibilityLabel("Open")
        }
        .padding(.horizontal, BuddyTheme.Spacing.sm)
        .padding(.vertical, BuddyTheme.Spacing.xs)
    }

    @ViewBuilder
    private var historyContent: some View {
        if historyItems.isEmpty {
            Text("Copy text, images, or files to build history")
                .foregroundStyle(.secondary)
                .padding()
            Spacer()
        } else {
            ScrollViewReader { proxy in
                List(selection: $store.selectedId) {
                    ForEach(Array(historyItems.enumerated()), id: \.element.id) { index, item in
                        FloatingHistoryRow(
                            title: store.displayPreview(for: item),
                            leading: .resolve(item: item, isHidden: store.isHidden(item)),
                            isCopied: copiedItemId == item.id,
                            shortcutHint: index < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: index) : nil,
                            onCopy: { copyHistory(item) }
                        )
                        .tag(item.id)
                        .id(item.id)
                    }
                }
                .listStyle(.inset)
                .onChange(of: historyItems.first?.id) { id in
                    scrollToHistory(id, proxy: proxy)
                }
                .onChange(of: store.selectedId) { id in
                    guard let id, historyItems.contains(where: { $0.id == id }) else { return }
                    scrollToHistory(id, proxy: proxy)
                }
                .onAppear {
                    scrollToHistory(store.selectedId ?? historyItems.first?.id, proxy: proxy)
                }
            }
        }
    }

    private func scrollToHistory(_ id: UUID?, proxy: ScrollViewProxy) {
        guard let id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if store.favorites.isEmpty {
            Text("No favorites yet")
                .foregroundStyle(.secondary)
                .padding()
            Spacer()
        } else {
            List {
                ForEach(Array(store.favorites.enumerated()), id: \.element.id) { index, favorite in
                    FloatingHistoryRow(
                        title: favorite.name,
                        leading: .resolve(favorite: favorite),
                        isCopied: copiedItemId == favorite.id,
                        shortcutHint: index < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: index) : nil,
                        onCopy: { copyFavorite(favorite) }
                    )
                    .id(favorite.id)
                }
            }
            .listStyle(.inset)
        }
    }

    private func copyHistory(_ item: ClipboardHistoryItem) {
        store.selectedId = item.id
        guard !store.isHidden(item) else { return }
        store.copyToPasteboard(item)
        markCopied(item.id)
    }

    private func copyFavorite(_ favorite: FavoriteShortcut) {
        store.copyFavorite(favorite)
        markCopied(favorite.id)
    }

    private func markCopied(_ id: UUID) {
        copiedItemId = id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedItemId == id {
                copiedItemId = nil
            }
        }
    }
}

private struct FloatingHistoryRow: View {
    let title: String
    let leading: ClipboardCellLeadingKind
    let isCopied: Bool
    var shortcutHint: String? = nil
    let onCopy: () -> Void

    private static let shortcutSlot: CGFloat = 28
    private static let copySlot: CGFloat = 18

    var body: some View {
        HStack(spacing: BuddyTheme.Spacing.sm) {
            ClipboardCellLeadingIcon(kind: leading)

            Text(title)
                .font(.buddyBody)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let shortcutHint {
                    Text(verbatim: shortcutHint)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                }
            }
            .frame(width: Self.shortcutSlot, alignment: .trailing)

            Button(action: onCopy) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(isCopied ? BuddyTheme.BuddyColor.success : Color.primary)
            }
            .buttonStyle(.borderless)
            .frame(width: Self.copySlot, height: Self.copySlot)
            .accessibilityLabel(isCopied ? "Copied" : "Copy")
        }
        .padding(.vertical, 4)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCopied ? BuddyTheme.BuddyColor.success.opacity(0.22) : Color.clear)
                .padding(.vertical, 1)
        )
    }
}
