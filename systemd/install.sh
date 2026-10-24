#!/usr/bin/env bash
# Install the systemd user services so ComfyUI and the comparison server start at boot.
# Run once:  bash systemd/install.sh
#
# Why user services and not a hand-written unit: systemd splits ExecStart on whitespace,
# so a repository path containing spaces silently becomes the wrong command (status
# 203/EXEC, restarting forever). This script writes the paths already quoted.
set -Eeuo pipefail
trap 'echo "!! install.sh failed at line $LINENO (exit $?). Nothing further was changed." >&2' ERR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

COMFYUI_DIR="$REPO/comfyui"
COMPARE_DIR="$REPO/compare"
for f in "$COMFYUI_DIR/run.sh" "$COMPARE_DIR/run.sh"; do
  [[ -x "$f" ]] || { echo "!! $f is missing or not executable." >&2; exit 1; }
done

q() { printf '"%s"' "$1"; }   # systemd accepts double quotes around an Exec argument

# Anything already listening on these ports will make the new units crash-loop, and a
# process whose PID file has been deleted can no longer be stopped by stop.sh. Clear
# what we can, then refuse to continue rather than installing a service that cannot bind.
"$COMPARE_DIR/stop.sh" >/dev/null 2>&1 || true
systemctl --user stop comfyui.service llm-compare.service 2>/dev/null || true
sleep 1

# Print the PIDs listening on a TCP port. ss is the usual tool; lsof is the fallback.
listeners_on() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    # No listener means grep exits 1, which under set -e + pipefail would kill the
    # script silently — exactly the case this check exists to pass.
    ss -ltnp 2>/dev/null | awk -v p=":$port\$" '$4 ~ p {print}' \
      | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u || true
  elif command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | sort -u || true
  else
    echo "!! Neither ss nor lsof found; skipping the port check." >&2
  fi
}

stale=""
for port in 8188 8890; do
  holders="$(listeners_on "$port")"
  [[ -n "$holders" ]] || continue
  echo "!! Port $port is still in use:" >&2
  for pid in $holders; do
    printf '   pid %s  %s\n' "$pid" "$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" >&2
    stale="$stale $pid"
  done
done
if [[ -n "$stale" ]]; then
  echo >&2
  echo "These are leftover processes from an earlier start. If their PID file was" >&2
  echo "deleted, stop.sh can no longer reach them. Stop them, then run this again:" >&2
  echo >&2
  echo "  kill$stale" >&2
  echo >&2
  exit 1
fi

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
