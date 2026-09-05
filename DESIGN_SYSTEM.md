# Design System — *-buddy

Shared visual language for Clipboard, Screenshot, and OTP Buddy. Implemented in **BuddyUI** (`shared-buddy`).

## Principles

1. **One system** — all apps share tokens and atoms; no per-app palette forks.
2. **Semantic tokens** — prefer `BuddyTheme.Color.surface` over raw `Color.gray`.
3. **Atomic UI** — build screens from atoms → molecules → organisms.
4. **Accessible by default** — every atom ships labels, contrast-safe colors, and scaled fonts.
5. **Mac-native** — feel like a utility, not a web kit; respect system appearance.

## Tokens (`BuddyTheme`)

| Token group | Examples |
|-------------|---------|
| Color | `background`, `surface`, `surfaceElevated`, `textPrimary`, `textSecondary`, `accent`, `danger`, `border`, `chipFill` |
| Typography | `title`, `body`, `caption`, `label` (Dynamic Type aware) |
| Spacing | `xxs` 2 · `xs` 4 · `sm` 8 · `md` 12 · `lg` 16 · `xl` 24 · `xxl` 32 |
| Radius | `sm` 4 · `md` 6 · `lg` 10 · `xl` 14 |
| Motion | `quick` 0.15s · `standard` 0.25s (honors Reduce Motion) |

## Atomic components

| Atom | Type | Notes |
|------|------|-------|
| `BuddyText` | Atom | Semantic text styles |
| `BuddyIcon` | Atom | SF Symbol wrapper + a11y label |
| `BuddyButton` | Atom | Primary / secondary / ghost / danger |
| `BuddyBadge` | Atom | Count or status pill |
| `BuddyDivider` | Atom | Contrast-aware separator |
| `BuddySpacer` | Atom | Tokenized spacing |
| `TagChip` | Atom | Content-tag chip |
| `BuddySearchField` | Molecule | Labeled search |
| `MenuBarRow` | Molecule | Title + subtitle action row |
| `SensitiveBlurView` | Molecule | Blur + reveal for secrets |
| `BuddyListChrome` | Molecule | Search + content chrome |

## Adding a component

1. Prefer extending an existing atom.
2. If new: add to `Sources/BuddyUI/`, use only `BuddyTheme` tokens.
3. Mark accessibility (label / hint / traits).
4. Update this file + `FEATURES.md`.
5. Consume from apps; delete duplicated local styles.

## App checklist

- [ ] No hard-coded hex colors in app UI
- [ ] Buttons/fields use `BuddyButton` / `BuddySearchField` (or documented exception)
- [ ] Menu bar popovers use `MenuBarRow` + theme spacing
- [ ] Dark Mode and Increase Contrast verified
