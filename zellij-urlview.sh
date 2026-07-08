#!/usr/bin/env bash
# zellij-urlview.sh — a tmux-urlview equivalent for zellij.
#
# Reads a screen dump (produced by zellij's `DumpScreen` keybind action),
# extracts every URL it can find, lets you pick one (or several) with fzf, and
# opens the selection in your browser.
#
# Usage: zellij-urlview.sh <dump-file>
# Intended to be launched in a floating pane from a zellij keybind. See README.
#
# Environment:
#   URLVIEW_OPENER   command used to open a URL (default: auto-detected —
#                      xdg-open, open, or $BROWSER)

set -u

dump="${1:-}"

cleanup() {
    [[ -n "${dump:-}" && -f "$dump" ]] && rm -f "$dump"
}
trap cleanup EXIT

pause() {
    # Keep the floating pane visible long enough to read the message.
    printf '\n%s' "press any key to close…"
    read -r -n1 -s _ || true
}

# Pick the command used to open URLs.
detect_opener() {
    if [[ -n "${URLVIEW_OPENER:-}" ]]; then
        echo "$URLVIEW_OPENER"
    elif command -v xdg-open >/dev/null 2>&1; then
        echo "xdg-open"
    elif command -v open >/dev/null 2>&1; then  # macOS
        echo "open"
    elif [[ -n "${BROWSER:-}" ]]; then
        echo "$BROWSER"
    else
        echo ""
    fi
}

# Launch a URL detached so it survives this floating pane closing.
open_url() {
    local url="$1"
    if command -v setsid >/dev/null 2>&1; then
        setsid --fork "$opener" "$url" >/dev/null 2>&1 </dev/null
    else
        nohup "$opener" "$url" >/dev/null 2>&1 </dev/null &
    fi
}

if [[ -z "$dump" ]]; then
    echo "zellij-urlview: no dump path given." >&2
    pause
    exit 1
fi

# DumpScreen runs just before this pane opens; give it a moment to finish
# writing so we don't read a missing or half-written file.
for _ in $(seq 1 40); do
    [[ -s "$dump" ]] && break
    sleep 0.05
done

if [[ ! -f "$dump" ]]; then
    echo "zellij-urlview: no screen dump found." >&2
    pause
    exit 1
fi

# Extract URLs:
#  - http(s)/ftp/file schemes, plus bare www.* hosts
#  - strip trailing punctuation that commonly hugs URLs in prose
#  - dedupe while preserving order, then reverse so the most recently printed
#    URLs (bottom of the screen) appear first in urlview.
mapfile -t urls < <(
    # Determine terminal width as the longest line in the dump.  Lines that
    # fill this width were wrapped by the terminal and must be joined with the
    # next line so a URL that crosses a wrap boundary is reconstructed whole.
    # Shorter lines ended naturally and keep their newline as a separator.
    width=$(awk '{ gsub(/\r/,""); if (length > max) max = length } END { print max+0 }' "$dump")
    awk -v w="$width" '{ gsub(/\r/,""); printf "%s%s", $0, (length($0)==w && w>0 ? "" : "\n") }' "$dump" \
        | grep -aoE '((https?|ftp|file)://|www\.)[A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+' \
        | sed -E 's/[].,;:!?")>'"'"']+$//' \
        | awk '!seen[$0]++' \
        | tac
)

if [[ ${#urls[@]} -eq 0 ]]; then
    echo "zellij-urlview: no URLs on screen." >&2
    pause
    exit 0
fi

# Pick with fzf (Tab to multi-select). Fall back to urlview if fzf is absent.
if command -v fzf >/dev/null 2>&1; then
    mapfile -t chosen < <(printf '%s\n' "${urls[@]}" \
        | fzf --multi --no-sort --prompt='open url> ' \
              --height=100% --border --reverse \
              --header='Enter: open · Tab: multi-select · Esc: cancel')
elif command -v urlview >/dev/null 2>&1; then
    printf '%s\n' "${urls[@]}" | urlview
    exit 0
else
    echo "zellij-urlview: neither fzf nor urlview found." >&2
    pause
    exit 1
fi

[[ ${#chosen[@]} -eq 0 ]] && exit 0

opener="$(detect_opener)"
if [[ -z "$opener" ]]; then
    echo "zellij-urlview: no URL opener found (set URLVIEW_OPENER)." >&2
    pause
    exit 1
fi

for url in "${chosen[@]}"; do
    [[ -z "$url" ]] && continue
    # www.* hosts need a scheme for the opener to route them to the browser.
    [[ "$url" == www.* ]] && url="https://$url"
    open_url "$url"
done
