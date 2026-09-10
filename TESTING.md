# Testing — ClipLog Buddy

## Unit

```bash
xcodebuild test -scheme ClipboardBuddy -destination 'platform=macOS'
```

## UI / e2e

XCUITest smoke: launch, open dashboard accessibility id, favorites list exists.

## CI

GitHub Actions: `xcodebuild test` on `macos-latest`.
