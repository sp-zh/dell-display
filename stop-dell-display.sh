#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="/private/tmp/dell-display-$(id -u)"

# Also clean up a process left by the earlier terminal-bound script.
stop_if_ours() {
  local pid_file="$1" expected="$2" pid command
  [[ -f "$pid_file" ]] || return 0
  pid="$(cat "$pid_file")"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$command" == *"$expected"* ]]; then
      kill "$pid"
    fi
  fi
  rm -f "$pid_file"
}

stop_if_ours "$RUN_DIR/worker.pid" "$RUN_DIR/worker.sh"
for _ in {1..20}; do
  [[ ! -f "$RUN_DIR/sunshine.pid" && ! -f "$RUN_DIR/vdisplay.pid" ]] && break
  sleep 0.1
done
stop_if_ours "$RUN_DIR/sunshine.pid" '/Sunshine.app/Contents/MacOS/Sunshine'
stop_if_ours "$RUN_DIR/vdisplay.pid" '/vdisplay'
stop_if_ours "$APP_DIR/.run/sunshine.pid" '/Sunshine.app/Contents/MacOS/Sunshine'
stop_if_ours "$APP_DIR/.run/vdisplay.pid" '/bin/vdisplay'
echo "Dell 扩展屏已关闭。"
