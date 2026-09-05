import SwiftUI
import BuddyUI

struct MenuBarView: View {
    @EnvironmentObject private var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("menu-bar-root")
    }
}
