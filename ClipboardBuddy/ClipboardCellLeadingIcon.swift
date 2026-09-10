import AppKit
import SwiftUI
import BuddyCore
import BuddyUI

/// Leading glyph for clipboard list cells: image, color swatch, clickable link, or muted text.
enum ClipboardCellLeadingKind: Equatable {
    case image(NSImage, blur: CGFloat)
    case color(NSColor)
    case link(URL)
    case text

    static func resolve(
        imageData: Data?,
        color: NSColor?,
        url: URL?,
        isHidden: Bool = false
    ) -> ClipboardCellLeadingKind {
        if let imageData, let image = NSImage(data: imageData) {
            return .image(image, blur: isHidden ? 8 : 0)
        }
        if !isHidden, let color {
            return .color(color)
        }
        if !isHidden, let url {
            return .link(url)
        }
        return .text
    }

    static func resolve(item: ClipboardHistoryItem, isHidden: Bool) -> ClipboardCellLeadingKind {
        resolve(
            imageData: item.imageData,
            color: item.listColor,
            url: item.listOpenableURL,
            isHidden: isHidden
        )
    }

    static func resolve(favorite: FavoriteShortcut) -> ClipboardCellLeadingKind {
        let color = DetectedContentExtractor.extractTokens(from: favorite.content, limit: 1)
            .first(where: { $0.kind == .color })?
            .nsColor
        let url = DetectedContentToken.openableURL(from: favorite.content)
            ?? DetectedContentExtractor.extractTokens(from: favorite.content, limit: 4)
            .first(where: { $0.kind == .url })?
            .openableURL
        return resolve(imageData: nil, color: color, url: url)
    }
}

struct ClipboardCellLeadingIcon: View {
    let kind: ClipboardCellLeadingKind
    var size: CGFloat = 18

    var body: some View {
        Group {
            switch kind {
            case .image(let image, let blur):
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size + 10, height: size + 10)
                    .clipped()
                    .cornerRadius(4)
                    .blur(radius: blur)
                    .accessibilityLabel("Image preview")
            case .color(let color):
                ColorSwatchView(color: color, size: size)
            case .link(let url):
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: size * 0.85, weight: .semibold))
                        .foregroundStyle(BuddyTheme.BuddyColor.accent)
                        .frame(width: size, height: size)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open link")
                .help("Open link")
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.system(size: size * 0.85, weight: .medium))
                    .foregroundStyle(BuddyTheme.BuddyColor.textSecondary)
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size + 10, height: size + 10, alignment: .center)
    }
}
