# Localization — *-buddy

## Supported locales

| Code | Language |
|------|----------|
| en | English (source) |
| nl | Dutch |
| pt | Portuguese |
| es | Spanish |
| fr | French |
| it | Italian |
| ar | Arabic (RTL) |
| zh | Chinese (Simplified) |
| ru | Russian |
| ja | Japanese |

> Note: product brief used `zn` / `jp`; ISO codes are `zh` / `ja`.

## Workflow

1. Add keys to Xcode String Catalog (`.xcstrings`)
2. Export / translate all 10 locales
3. Verify RTL layout with `ar`
4. Update [STORE.md](STORE.md) per locale for App Store Connect

## shared-buddy

Shared package ships `BuddyLocalization` with locale metadata and RTL helper. UI strings primarily live in each app’s catalog; shared UI uses catalog keys under `Buddy.*`.
