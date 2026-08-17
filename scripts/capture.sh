#!/usr/bin/env bash
# Region capture for screenshot-actions plugin
# Outputs: absolute path of saved screenshot to stdout

set -euo pipefail

# Read config from environment (passed by service.luau)
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots}"
FILENAME_FORMAT="${FILENAME_FORMAT:-%Y-%b_%H-%M-%S}"

mkdir -p "$SCREENSHOT_DIR"

time=$(date "+$FILENAME_FORMAT")
file="Screenshot_${time}_${RANDOM}.png"
check_file="$SCREENSHOT_DIR/$file"

# Capture region
tmpfile=$(mktemp --suffix=.png)
wayfreeze --hide-cursor &
frozen=$!
trap 'kill "$frozen" 2>/dev/null; wait "$frozen" 2>/dev/null || true; rm -f "$tmpfile"' EXIT

sleep 0.2
geometry=$(slurp)
if [[ -n "$geometry" ]]; then
    grim -g "$geometry" - >"$tmpfile"
fi
kill "$frozen" 2>/dev/null
wait "$frozen" 2>/dev/null || true
trap - EXIT

if [[ ! -s "$tmpfile" ]]; then
    echo "cancelled" >&2
    exit 1
fi

# Save screenshot
mv "$tmpfile" "$check_file"

# Copy to clipboard
wl-copy <"$check_file"

# Play sound if available
if command -v paplay >/dev/null 2>&1; then
    paplay /usr/share/sounds/freedesktop/stereo/screen-capture.oga 2>/dev/null &
elif command -v pw-play >/dev/null 2>&1; then
    pw-play /usr/share/sounds/freedesktop/stereo/screen-capture.oga 2>/dev/null &
fi

# Notify
notify-send -u low -t 2000 -i "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots" \
    "Screenshot" " Saved to $(basename "$check_file")" 2>/dev/null || true

# Output path for service to capture
echo "$check_file"