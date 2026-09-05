import SwiftUI
import BuddyCore
import BuddyUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var favoriteName = ""
    @State private var selectedId: UUID?

    private var selected: ClipboardHistoryItem? {
        store.items.first { $0.id == selectedId }
    }

    var body: some View {
        NavigationSplitView {
            BuddyListChrome(query: $store.query) {
                List(store.filtered, selection: $selectedId) { item in
                    HistoryRow(item: item)
                        .tag(item.id)
                        .accessibilityIdentifier("history-row")
                }
                .listStyle(.inset)
                .accessibilityIdentifier("history-list")
            }
            .navigationTitle("History")
        } detail: {
            if let selected {
                DetailPane(item: selected)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.largeTitle)
                    Text("Select an item")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Favorite") {
                    guard let selected, let text = selected.text else { return }
                    store.addFavorite(name: favoriteName.isEmpty ? selected.preview : favoriteName, content: text)
                    favoriteName = ""
                }
                .disabled(selected?.text == nil)
                .accessibilityIdentifier("add-favorite")
            }
        }
    }
}

struct HistoryRow: View {
    @EnvironmentObject private var store: ClipboardStore
    let item: ClipboardHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                SensitiveBlurView(isHidden: item.isSensitive && !store.revealedIds.contains(item.id)) {
                    store.reveal(item: item) { _ in }
                } content: {
                    Text(item.preview)
                        .font(.buddyBody)
                        .lineLimit(2)
                }
                HStack {
                    ForEach(Array(item.tags.prefix(4)), id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
            Spacer()
            Button {
                store.copyToPasteboard(item)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy")
        }
        .padding(.vertical, 4)
    }
}

struct DetailPane: View {
    @EnvironmentObject private var store: ClipboardStore
    let item: ClipboardHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let data = item.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .accessibilityLabel("Clipboard image")
                }
                SensitiveBlurView(isHidden: item.isSensitive && !store.revealedIds.contains(item.id)) {
                    store.reveal(item: item) { _ in }
                } content: {
                    Text(item.text ?? "Image")
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    ForEach(item.tags, id: \.self) { TagChip(tag: $0) }
                }
                Button("Copy to Clipboard") {
                    store.copyToPasteboard(item)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .padding()
        }
        .accessibilityIdentifier("detail-pane")
    }
}
