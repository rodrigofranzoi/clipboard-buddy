# Firebase (macOS)

1. Create a Firebase project (shared suite project recommended).
2. Add a **macOS** app with the bundle ID from MANIFEST.md.
3. Download `GoogleService-Info.plist` into the app target root (do not commit secrets to public forks if restricted).
4. Add Firebase Analytics + Crashlytics SPM products in Xcode.
5. Keep `BuddyFirebase.configure()` as the first launch call.

No clipboard, screenshot pixels, email bodies, or OTP codes may be logged.
