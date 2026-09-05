# Encryption & App Store disclosure — *-buddy

Use this when filling **App Privacy**, **Export Compliance**, and review notes in App Store Connect.

## What we encrypt (on device only)

| Data | How | Where key lives |
|------|-----|-----------------|
| Clipboard history (text + images) | AES-256-GCM (CryptoKit) | Keychain, This Device Only |
| Clipboard favorites | AES-256-GCM | Same key |
| Screenshot gallery (images + notes) | AES-256-GCM | Same key |
| IMAP password (OTP Buddy) | Keychain item | Keychain |
| OTP codes | Not written to disk | Memory only, short TTL |

**Not encrypted:** preference toggles (retention days, analytics opt-in, auto-copy) in UserDefaults — no secrets.

**Storage:** SQLite file in Application Support (`buddy.sqlite`). Values are sealed blobs, not plaintext columns.

**Algorithm:** Apple CryptoKit `AES.GCM` with a random 256-bit key created once per Mac user install.

**We do not** send clipboard, screenshots, email bodies, or OTP codes to Firebase or any server.

---

## App Store Connect — Export Compliance

When asked about encryption:

1. **Does your app use encryption?** → **Yes**
2. **Is it exempt under US EAR?** → Typically **Yes**, because encryption is limited to:
   - HTTPS / TLS for Firebase Analytics & Crashlytics (and IMAP TLS for OTP Buddy)
   - Encrypting data stored **only on the user’s device**
3. In the common questionnaire, choose the options that match:
   - Uses encryption
   - Only for authentication / HTTPS **and/or** local data protection on device
   - **Not** a custom/proprietary crypto product, VPN, or proprietary cipher

If Apple’s form offers: *“App uses encryption only for… local storage / HTTPS”* — select that.

**ITSAppUsesNonExemptEncryption** in Info.plist: set to **`false`** (exempt) when your use matches the above. Document that choice here and keep it consistent across apps.

Suggested Info.plist entry (already appropriate for these utilities):

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Re-verify if you later add custom crypto, your own messaging protocol, or a VPN.

---

## App Privacy (nutrition labels)

Recommended declarations:

| Category | Answer |
|----------|--------|
| Contact Info / User Content (clipboard, screenshots, email) | **Not collected** (stays on device) |
| Crash data | Collected if Crashlytics enabled (diagnostics) |
| Analytics | **Optional** — only if user opts in; no content payloads |
| Encryption | Data encrypted on device; keys in Keychain |

Privacy policy should state:

- Clipboard / screenshots / favorites are stored encrypted on device.
- OTP codes are not persisted.
- IMAP passwords are Keychain-only.
- Analytics never includes clipboard, image, or email content.

---

## Review notes (paste into App Store Connect)

```
Encryption: AES-256-GCM (CryptoKit) for local clipboard/screenshot storage.
Key: random 256-bit key in macOS Keychain (AccessibleAfterFirstUnlockThisDeviceOnly).
No proprietary crypto. No cloud sync of clipboard/screenshots.
Export: exempt — HTTPS + on-device storage encryption only.
```

---

## Developer notes

- Code: `BuddySeal` + `BuddyDatabase` in `shared-buddy` / BuddyCore
- First launch migrates old UserDefaults plaintext into sealed SQLite, then deletes the defaults keys
- Losing the Keychain key (e.g. new machine without migration) makes old `buddy.sqlite` unreadable — expected
