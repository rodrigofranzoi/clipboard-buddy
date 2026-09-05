# Clipboard Buddy Manifest

See suite contract patterns from [shared-buddy](https://github.com/rodrigofranzoi/shared-buddy).

## Identity

| Field | Value |
|-------|-------|
| Name | Clipboard Buddy |
| Bundle ID | com.buddy.clipboard |
| Platform | macOS 13.0+ |
| UI | SwiftUI + AppKit status item |
| Shared | shared-buddy SPM |
| Firebase | Analytics + Crashlytics (macOS) |
| Google Play | N/A — macOS only |

## Locales

`en`, `nl`, `pt`, `es`, `fr`, `it`, `ar`, `zh`, `ru`, `ja`

## Purpose

Clipboard history with images, auto-tags, favorites, and menu-bar shortcuts.


## Design system & atomic components

Apps **must** use the shared Buddy design system (tokens + atomic components) from `shared-buddy` / `BuddyUI`.

- Do not invent one-off colors, radii, or spacing in this app.
- Compose screens from atoms/molecules; upstream new UI to `BuddyUI`.
- Full contract: [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) (source of truth also in shared-buddy).

## Related docs

- [FEATURES.md](FEATURES.md)
- [STORE.md](STORE.md)
- [ACCESSIBILITY.md](ACCESSIBILITY.md)
- [LOCALIZATION.md](LOCALIZATION.md)
- [TESTING.md](TESTING.md)
- [SCREENSHOTS.md](SCREENSHOTS.md)
