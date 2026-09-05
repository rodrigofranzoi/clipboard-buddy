# Accessibility — shared-buddy

## Requirements (all Buddy apps + shared UI)

| Capability | Expectation |
|------------|-------------|
| Dark Mode | All colors via semantic / asset colors |
| Dynamic Type | Prefer `@ScaledMetric` / relative fonts |
| VoiceOver | Every control has label; sensitive values use custom actions to reveal |
| Increase Contrast | Borders/separators visible when enabled |
| Reduce Motion | Disable non-essential animation |
| Reduce Transparency | Prefer opaque backgrounds when enabled |
| Keyboard | Lists and buttons focusable |

## BuddyUI checklist

- [x] `TagChip` — accessibility label = tag name
- [x] `SensitiveBlurView` — announces “Hidden sensitive content”; reveal action
- [x] `BuddySearchField` — labeled “Search”
- [x] Menu bar rows — title + secondary value summary (not raw secrets)

## Testing

1. Enable VoiceOver → navigate tag list and blurred rows
2. Increase Contrast → verify chip borders
3. Largest Dynamic Type → list still readable
4. Dark / Light appearance flip
