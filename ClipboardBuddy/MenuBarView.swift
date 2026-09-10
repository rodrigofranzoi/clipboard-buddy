import SwiftUI
import BuddyUI
import BuddyCore
import AppKit

private enum MenuBarPinShortcutTarget {
    case favorite(FavoriteShortcut)
    case history(ClipboardHistoryItem)

    var id: UUID {
        switch self {
        case .favorite(let favorite): return favorite.id
        case .history(let item): return item.id
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var pause: BuddyPauseController
    @ObservedObject private var unlock = SensitiveUnlockSession.shared
    @AppStorage(BuddySettingsKey.autoBlurContentTags) private var protectedTagsRaw: String = ""
    @AppStorage(BuddySettingsKey.requireAuthSensitiveContent) private var requireAuth = false
    @AppStorage(BuddySettingsKey.clipboardMenuBarRecentCount) private var menuBarRecentCount =
        ClipboardIgnoreSettings.defaultMenuBarRecentCount
    @AppStorage(BuddySettingsKey.clipboardMenuBarFavoriteCount) private var menuBarFavoriteCount =
        ClipboardIgnoreSettings.defaultMenuBarFavoriteCount

    @State private var selectedPinId: UUID?
    @State private var dismissTask: Task<Void, Never>?

    /// Favorites (if shown) then recent — ⌘1…⌘0 copy by this order.
    private var pinShortcutTargets: [MenuBarPinShortcutTarget] {
        var targets: [MenuBarPinShortcutTarget] = []
        if menuBarFavoriteCount > 0 {
            targets.append(contentsOf: store.favorites.prefix(menuBarFavoriteCount).map { .favorite($0) })
        }
        targets.append(contentsOf: store.items.prefix(max(menuBarRecentCount, 1)).map { .history($0) })
        return Array(targets.prefix(10))
    }

    private var favoriteShortcutBaseCount: Int {
        menuBarFavoriteCount > 0 ? min(store.favorites.count, menuBarFavoriteCount) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pause.isPaused {
                Text(pause.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .top])
            }

            HStack(spacing: BuddyTheme.Spacing.sm) {
                Button {
                    NotificationCenter.default.post(name: .clipboardToggleFloatingHistory, object: nil)
                } label: {
                    Image(systemName: "clock")
                }
                .buttonStyle(.borderless)
                .help("Floating History")
                .accessibilityLabel("Floating History")
                .accessibilityIdentifier("menubar-floating-history")

                Button {
                    NotificationCenter.default.post(name: .clipboardToggleFloatingFavorites, object: nil)
                } label: {
                    Image(systemName: "swatchpalette")
                }
                .buttonStyle(.borderless)
                .help("Floating Favorites")
                .accessibilityLabel("Floating Favorites")
                .accessibilityIdentifier("menubar-floating-favorites")

                Spacer(minLength: 0)
            }
            .padding([.horizontal, .top])

            if menuBarFavoriteCount > 0 {
                Text("Favorites")
                    .font(.headline)
                    .padding([.horizontal, .top])
                    .accessibilityIdentifier("favorites-header")

                if store.favorites.isEmpty {
                    Text("No favorites yet")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    let favorites = Array(store.favorites.prefix(menuBarFavoriteCount))
                    ForEach(Array(favorites.enumerated()), id: \.element.id) { index, fav in
                        let color = DetectedContentExtractor.extractTokens(from: fav.content, limit: 1)
                            .first(where: { $0.kind == .color })?
                            .nsColor
                        let url = DetectedContentToken.openableURL(from: fav.content)
                            ?? DetectedContentExtractor.extractTokens(from: fav.content, limit: 4)
                            .first(where: { $0.kind == .url })?
                            .openableURL
                        MenuBarRow(
                            title: fav.name,
                            colorSwatch: color.map { Color(nsColor: $0) },
                            openAction: url.map { link in { NSWorkspace.shared.open(link) } },
                            copyAction: {
                                selectCopyAndDismiss(id: fav.id) {
                                    store.copyFavorite(fav)
                                }
                            },
                            showsSeparator: index < favorites.count - 1,
                            shortcutHint: index < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: index) : nil
                        ) {
                            selectCopyAndDismiss(id: fav.id) {
                                store.copyFavorite(fav)
                            }
                        }
                        .padding(.horizontal)
                        .background(pinSelectionBackground(for: fav.id))
                    }
                }

                BuddyDivider().padding(.vertical, 8)
            }

            Text("Recent")
                .font(.headline)
                .padding(.horizontal)

            let recent = Array(store.items.prefix(max(menuBarRecentCount, 1)))
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                let _ = protectedTagsRaw
                let _ = requireAuth
                let _ = unlock.unlockedUntil
                let isHidden = store.isHidden(item)
                let thumbnail: Image? = {
                    guard let data = item.imageData, let nsImage = NSImage(data: data) else { return nil }
                    return Image(nsImage: nsImage)
                }()
                let colorSwatch: Color? = {
                    guard !isHidden, thumbnail == nil, let color = item.listColor else { return nil }
                    return Color(nsColor: color)
                }()
                let openURL = isHidden ? nil : item.listOpenableURL
                let shortcutIndex = favoriteShortcutBaseCount + index
                MenuBarRow(
                    title: store.displayPreview(for: item),
                    thumbnail: thumbnail,
                    thumbnailBlur: isHidden ? 8 : 0,
                    colorSwatch: colorSwatch,
                    openAction: openURL.map { url in { NSWorkspace.shared.open(url) } },
                    copyAction: isHidden ? nil : {
                        selectCopyAndDismiss(id: item.id) {
                            copyItem(item)
                        }
                    },
                    showsSeparator: index < recent.count - 1,
                    shortcutHint: shortcutIndex < 10 ? BuddyDigitCopyShortcutsModifier.hint(for: shortcutIndex) : nil
                ) {
                    guard !isHidden else { return }
                    selectCopyAndDismiss(id: item.id) {
                        copyItem(item)
                    }
                }
                .padding(.horizontal)
                .background(pinSelectionBackground(for: item.id))
            }

            Spacer(minLength: 0)

            BuddyPauseControls(pause: pause)
            BuddyClearHistoryButton(itemNoun: "clippings") {
                store.clearAllHistory()
            }
            BuddyMenuBarAppControls(appName: BuddyBrand.clipboardBuddy.displayName, brand: .clipboardBuddy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("menu-bar-root")
        .buddyDigitCopyShortcuts(itemCount: pinShortcutTargets.count) { index in
            copyPinTarget(at: index)
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    @ViewBuilder
    private func pinSelectionBackground(for id: UUID) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(selectedPinId == id ? BuddyTheme.BuddyColor.success.opacity(0.28) : Color.clear)
            .padding(.vertical, 1)
    }

    private func selectCopyAndDismiss(id: UUID, copy: () -> Void) {
        copy()
        selectedPinId = id
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            // Brief highlight so the selection is visible before the pin closes.
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: .clipboardDismissMenuBarPopover, object: nil)
        }
    }

    private func copyPinTarget(at index: Int) {
        guard pinShortcutTargets.indices.contains(index) else { return }
        switch pinShortcutTargets[index] {
        case .favorite(let favorite):
            selectCopyAndDismiss(id: favorite.id) {
                store.copyFavorite(favorite)
            }
        case .history(let item):
            guard !store.isHidden(item) else { return }
            selectCopyAndDismiss(id: item.id) {
                copyItem(item)
            }
        }
    }

    private func copyItem(_ item: ClipboardHistoryItem) {
        guard !store.isHidden(item) else { return }
        store.copyToPasteboard(item)
    }
}
