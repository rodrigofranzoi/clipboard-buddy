import SwiftUI
import BuddyUI
import BuddyCore

struct MenuBarView: View {
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var pause: BuddyPauseController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pause.isPaused {
                Text(pause.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .top])
            }

            Text("Favorites")
                .font(.headline)
                .padding([.horizontal, .top])
                .accessibilityIdentifier("favorites-header")

            if store.favorites.isEmpty {
                Text("No favorites yet")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(store.favorites.prefix(8)) { fav in
                    MenuBarRow(title: fav.name, subtitle: String(fav.content.prefix(40))) {
                        store.copyFavorite(fav)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }

            Divider().padding(.vertical, 8)

            Text("Recent")
                .font(.headline)
                .padding(.horizontal)

            ForEach(store.items.prefix(10)) { item in
                MenuBarRow(title: item.preview, subtitle: item.tags.map(\.rawValue).joined(separator: ", ")) {
                    store.copyToPasteboard(item)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            BuddyPauseControls(pause: pause)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("menu-bar-root")
    }
}
