import SwiftUI
import BuddyCore
import BuddyUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var store: ClipboardStore
    @State private var qrPreviewItem: ClipboardHistoryItem?

    private var selected: ClipboardHistoryItem? {
        store.items.first { $0.id == store.selectedId }
    }

    private var selectedIsFavorited: Bool {
        guard let text = selected?.text else { return false }
        return store.isFavorited(content: text)
    }

    var body: some View {
        NavigationSplitView {
            BuddyListChrome(query: $store.query) {
                List(store.filtered, selection: $store.selectedId) { item in
                    HistoryRow(item: item)
                        .tag(item.id)
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(BuddyTheme.BuddyColor.border.opacity(0.4))
                        .accessibilityIdentifier("history-row")
                        .contextMenu {
                            if store.qrPayload(for: item) != nil {
                                Button("Make QR Code") {
                                    presentQR(for: item)
                                }
                            }
                            Button("Copy to Clipboard") {
                                store.copyToPasteboard(item)
                            }
                        }
                }
                .listStyle(.inset)
                .accessibilityIdentifier("history-list")
            }
            .navigationTitle("History")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 420)
        } detail: {
            if let selected {
                DetailPane(item: selected, onMakeQRCode: { presentQR(for: selected) })
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
                Button {
                    guard let selected, let text = selected.text else { return }
                    store.toggleFavorite(name: selected.preview, content: text)
                } label: {
                    Image(systemName: selectedIsFavorited ? "star.fill" : "star")
                }
                .disabled(selected?.text == nil)
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
        .onReceive(NotificationCenter.default.publisher(for: .buddyMarketingStageScene)) { note in
            guard let scene = note.userInfo?[BuddyMarketingCapture.sceneKey] as? String,
                  scene == "qr",
                  let item = store.items.first(where: { $0.id == ClipboardStore.MarketingClipID.share })
            else { return }
            qrPreviewItem = item
        }
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

    private var isHidden: Bool {
        _ = protectedTagsRaw
        _ = requireAuth
        _ = unlock.unlockedUntil
        return store.isHidden(item)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            leadingVisual

            VStack(alignment: .leading, spacing: 6) {
                SensitiveBlurView(isHidden: isHidden) {
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
            Spacer(minLength: 0)

            if let url = item.listOpenableURL {
                Button {
                    if isHidden {
                        store.reveal(item: item) { success in
                            if success { NSWorkspace.shared.open(url) }
                        }
                    } else {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open link")
                .help("Open link")
            }

            Button {
                store.copyToPasteboard(item)
                justCopied = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    justCopied = false
                }
            } label: {
                Image(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(justCopied ? Color.green : Color.primary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(justCopied ? "Copied" : "Copy")
            .help(justCopied ? "Copied" : "Copy to clipboard")
        }
        .padding(.vertical, BuddyTheme.Spacing.sm)
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if let data = item.imageData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipped()
                .cornerRadius(4)
                .blur(radius: isHidden ? 8 : 0)
                .accessibilityLabel("Image preview")
        } else if let color = item.listColor {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .accessibilityLabel("Color swatch")
        }
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
