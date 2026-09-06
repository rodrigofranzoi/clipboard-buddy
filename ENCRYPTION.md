# Encryption & App Store disclosure — *-buddy

Use this when filling **App Privacy**, **Export Compliance**, and review notes in App Store Connect.

## What we store (on device only)

| Data | How | Where |
|------|-----|-------|
| Clipboard history (text + images) | JSON in UserDefaults | On device |
| Clipboard favorites | JSON in UserDefaults | On device |
| Screenshot gallery (images + notes) | JSON in UserDefaults | On device |
| IMAP password (OTP Buddy) | Keychain item | Keychain |
| OTP codes | Not written to disk | Memory only, short TTL |

**Preferences** (retention days, analytics, auto-copy) also live in UserDefaults — no secrets.

**We do not** send clipboard, screenshots, email bodies, or OTP codes to Firebase or any server.

Clipboard / screenshot payloads are **not** encrypted at rest (plain JSON in UserDefaults).

---

## App Store Connect — Export Compliance

When asked about encryption:

1. **Does your app use encryption?** → **Yes** (HTTPS / TLS only for Firebase Analytics & Crashlytics, and IMAP TLS for OTP Buddy)
2. **Is it exempt under US EAR?** → Typically **Yes** — encryption limited to HTTPS / TLS, not a custom crypto product

**ITSAppUsesNonExemptEncryption** in Info.plist: set to **`false`** (exempt) when your use matches the above.

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## App Privacy (nutrition labels)

Recommended declarations:

| Category | Answer |
|----------|--------|
| Contact Info / User Content (clipboard, screenshots, email) | **Not collected** (stays on device) |
| Crash data | Collected if Crashlytics enabled (diagnostics) |
| Analytics | Enabled; no content payloads |

Privacy policy should state:

- Clipboard / screenshots / favorites are stored on device (UserDefaults).
- OTP codes are not persisted.
- IMAP passwords are Keychain-only.
- Analytics never includes clipboard, image, or email content.

---

## Review notes (paste into App Store Connect)

```
Storage: clipboard/screenshot history as JSON in UserDefaults (on device only).
IMAP password (OTP Buddy): macOS Keychain.
No proprietary crypto. No cloud sync of clipboard/screenshots.
Export: exempt — HTTPS/TLS only.
```

---

## Developer notes

- Clipboard / screenshot persistence: UserDefaults in each app’s store
- OTP IMAP credentials: `BuddyKeychain` in BuddyCore
- Old `buddy.sqlite` sealed stores and Keychain AES keys are unused; safe to delete locally
