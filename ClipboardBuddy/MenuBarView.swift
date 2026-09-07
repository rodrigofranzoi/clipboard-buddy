import SwiftUI
import BuddyUI
import BuddyCore
import AppKit

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pause.isPaused {
                Text(pause.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .top])
            }

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
                            subtitle: String(fav.content.prefix(40)),
                            colorSwatch: color.map { Color(nsColor: $0) },
                            openAction: url.map { link in { NSWorkspace.shared.open(link) } },
                            copyAction: { store.copyFavorite(fav) },
                            showsSeparator: index < favorites.count - 1
                        ) {
                            // Favorites stay one-click paste shortcuts.
                            store.copyFavorite(fav)
                        }
                        .padding(.horizontal)
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
                    guard thumbnail == nil, let color = item.listColor else { return nil }
                    return Color(nsColor: color)
                }()
                let openURL = item.listOpenableURL
                MenuBarRow(
                    title: store.displayPreview(for: item),
                    subtitle: item.tags.map(\.rawValue).joined(separator: ", "),
                    thumbnail: thumbnail,
                    thumbnailBlur: isHidden ? 8 : 0,
                    colorSwatch: colorSwatch,
                    openAction: openURL.map { url in
                        {
                            if isHidden {
                                store.reveal(item: item) { success in
                                    if success { NSWorkspace.shared.open(url) }
                                }
                            } else {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    },
                    copyAction: { copyItem(item) },
                    showsSeparator: index < recent.count - 1
                ) {
                    store.selectedId = item.id
                    BuddyMainWindow.show()
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 0)

            BuddyPauseControls(pause: pause)
            BuddyClearHistoryButton(itemNoun: "clippings") {
                store.clearAllHistory()
            }
            BuddyMenuBarAppControls(appName: "Clipboard Buddy", brand: .clipboardBuddy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("menu-bar-root")
    }

    private func copyItem(_ item: ClipboardHistoryItem) {
        if store.isHidden(item) {
            store.reveal(item: item) { success in
                if success { store.copyToPasteboard(item) }
            }
        } else {
            store.copyToPasteboard(item)
        }
    }
}
