# Screenshots — Clipboard Buddy

```
docs/screenshots/{locale}/raw/      # real app window captures
docs/screenshots/{locale}/banners/ # framed 1280×800 marketing images
docs/screenshots/mock-content.md
```

Locales: `en`, `nl`, `pt`, `es`, `fr`, `it`, `ar`, `zh`, `ru`, `ja`.

## Capture real UI

```bash
./shared-buddy/scripts/marketing/capture_real_screenshots.sh all
./shared-buddy/scripts/marketing/capture_real_screenshots.sh clipboard
```

Frame existing raws only:

```bash
python3 shared-buddy/scripts/marketing/generate_marketing_banners.py --frame-only
```

Banner size: **1280×800**. Brand frame uses the Clipboard Buddy mint / emerald / lime icon gradient.

## Required shots

| ID | Feature | Banner title (en) | Banner description (en) |
|----|---------|-------------------|-------------------------|
| history | History list | Never lose a copy | Search every text, image, and file you copied on your Mac. |
| tags | Tagged + blurred | Smart tags | Passwords stay blurred until you unlock with Touch ID or password. |
| favorites | Menu bar favorites | One-click favorites | Pin shortcuts to the menu bar for instant paste. |
| qr | Make QR | Make a QR | Turn any history item into a scannable QR code image. |
| detail | Detail pane | Rich detail | Preview text, images, and pasteboard flavors before you paste. |
| menubar | Menu bar | Always nearby | Favorites and recent clips live in the menu bar. |
