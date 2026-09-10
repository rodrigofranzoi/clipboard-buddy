#!/usr/bin/env bash
# Generate App Store screenshots (raw captures + framed 1280×800 banners) for ClipLog Buddy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SHARED="$ROOT/shared-buddy/scripts/marketing/capture_real_screenshots.sh"
if [[ ! -f "$SHARED" ]]; then
  SHARED="$(cd "$(dirname "$0")/../../shared-buddy/scripts/marketing" && pwd)/capture_real_screenshots.sh"
fi
if [[ ! -f "$SHARED" ]]; then
  echo "ERROR: shared capture_real_screenshots.sh not found (link Vendor/shared-buddy or keep sibling shared-buddy)." >&2
  exit 1
fi

exec "$SHARED" clipboard
