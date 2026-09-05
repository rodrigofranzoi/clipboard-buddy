# Clipboard Buddy

macOS menu-bar clipboard history with tags, favorites, and accessibility support.

## Develop

```bash
# Ensure shared package is available
ln -sfn ../../shared-buddy Vendor/shared-buddy
xcodegen generate
xcodebuild -scheme ClipboardBuddy -destination 'platform=macOS' test
```

Requires macOS 13+, Xcode 15+.
