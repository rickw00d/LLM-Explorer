#!/usr/bin/env bash
# Install the systemd user services so ComfyUI and the comparison server start at boot.
# Run once:  bash systemd/install.sh
#
# Why user services and not a hand-written unit: systemd splits ExecStart on whitespace,
# so a repository path containing spaces silently becomes the wrong command (status
# 203/EXEC, restarting forever). This script writes the paths already quoted.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

COMFYUI_DIR="$REPO/comfyui"
COMPARE_DIR="$REPO/compare"
for f in "$COMFYUI_DIR/run.sh" "$COMPARE_DIR/run.sh"; do
  [[ -x "$f" ]] || { echo "!! $f is missing or not executable." >&2; exit 1; }
done

q() { printf '"%s"' "$1"; }   # systemd accepts double quotes around an Exec argument

mkdir -p "$UNIT_DIR"
for name in comfyui llm-compare; do
  sed -e "s|@COMFYUI_DIR@|$COMFYUI_DIR|g" \
      -e "s|@COMPARE_DIR@|$COMPARE_DIR|g" \
      -e "s|@COMFYUI_RUN@|$(q "$COMFYUI_DIR/run.sh")|g" \
      -e "s|@COMPARE_RUN@|$(q "$COMPARE_DIR/run.sh")|g" \
      -e "s|@COMPARE_ENV@|$COMPARE_DIR/.env|g" \
      "$SCRIPT_DIR/$name.service.in" > "$UNIT_DIR/$name.service"
  echo ">> wrote $UNIT_DIR/$name.service"
done

# An older all-in-one unit shipped in compare/; retire it so the two do not fight
# over the same ports.
if systemctl --user list-unit-files 2>/dev/null | grep -q '^llm-explorer\.service'; then
  echo ">> Found the old llm-explorer.service — disabling it."
  systemctl --user disable --now llm-explorer.service || true
  systemctl --user reset-failed llm-explorer.service 2>/dev/null || true
  rm -f "$UNIT_DIR/llm-explorer.service"
fi

systemctl --user daemon-reload
systemctl --user enable comfyui.service llm-compare.service

# Without lingering, user services wait for a graphical login instead of starting at boot.
if ! loginctl show-user "$USER" -p Linger --value 2>/dev/null | grep -qx yes; then
  echo ">> Enabling lingering so the services start at boot without a login…"
  sudo loginctl enable-linger "$USER"
fi

systemctl --user restart comfyui.service llm-compare.service
echo
echo ">> Done. Status:"
systemctl --user --no-pager --lines=0 status comfyui.service llm-compare.service || true
echo
echo ">> Logs:    journalctl --user -u comfyui -f"
echo ">>          journalctl --user -u llm-compare -f"
echo ">> Control: systemctl --user restart|stop llm-compare"
echo ">> Open WebUI runs under Docker with --restart unless-stopped; it needs nothing here."
