#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="${XCODE_SPM_SETUP_PATH:-}"
if [[ -z "$SKILL" ]]; then
  SKILL=$(find "$HOME/.cursor/plugins/cache/cursor-public/firebase" -type d -path "*/xcode-project-setup/scripts/xcode_spm_setup" 2>/dev/null | head -1 || true)
fi
if [[ -z "$SKILL" || ! -d "$SKILL" ]]; then
  echo "xcode_spm_setup skill not found; ensure GoogleService-Info.plist is already in the Xcode project."
  exit 0
fi
cd "$ROOT"
swift run --package-path "$SKILL" xcode_spm_setup \
  "ClipboardBuddy.xcodeproj" \
  "https://github.com/firebase/firebase-ios-sdk" \
  "12.18.0" \
  --plist "ClipboardBuddy/Resources/GoogleService-Info.plist" \
  FirebaseCore FirebaseAnalytics FirebaseCrashlytics
