#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$APP_DIR"
DELL_IP="169.254.118.3"
VDISPLAY_PID=""
SUNSHINE_PID=""

cleanup() {
  trap - EXIT TERM INT
  [[ -n "$SUNSHINE_PID" ]] && kill "$SUNSHINE_PID" 2>/dev/null || true
  [[ -n "$VDISPLAY_PID" ]] && kill "$VDISPLAY_PID" 2>/dev/null || true
  rm -f "$RUN_DIR/worker.pid" "$RUN_DIR/sunshine.pid" "$RUN_DIR/vdisplay.pid"
}
trap cleanup EXIT
trap 'exit 0' TERM INT
echo "$$" > "$RUN_DIR/worker.pid"

MAC_IP="$(ifconfig bridge0 | awk '/^[[:space:]]*inet / { print $2; exit }')"
if [[ "$MAC_IP" != 169.254.* ]] || ! ping -c 1 -W 1000 "$DELL_IP" >/dev/null 2>&1; then
  echo "USB4 连接暂不可用；后台服务稍后重试。" >&2
  exit 1
fi

rm -f "$RUN_DIR/sunshine.pid" "$RUN_DIR/vdisplay.pid"
"$APP_DIR/vdisplay" -w 1920 -h 1080 -r 60 -n 'Dell Virtual' --no-hidpi >"$RUN_DIR/vdisplay.log" 2>&1 &
VDISPLAY_PID=$!
echo "$VDISPLAY_PID" > "$RUN_DIR/vdisplay.pid"

DISPLAY_ID=""
for _ in {1..40}; do
  DISPLAY_ID="$(sed -n 's/.*display id \([0-9][0-9]*\).*/\1/p' "$RUN_DIR/vdisplay.log" | head -1)"
  [[ -n "$DISPLAY_ID" ]] && break
  if ! kill -0 "$VDISPLAY_PID" 2>/dev/null; then
    cat "$RUN_DIR/vdisplay.log" >&2
    exit 1
  fi
  sleep 0.25
done
if [[ -z "$DISPLAY_ID" ]]; then
  echo "虚拟显示器没有返回显示 ID。" >&2
  exit 1
fi

cat > "$APP_DIR/sunshine.conf" <<EOF
output_name = $DISPLAY_ID
bind_address = $MAC_IP
address_family = ipv4
upnp = disabled
stream_audio = disabled
EOF

/Applications/Sunshine.app/Contents/MacOS/Sunshine "$APP_DIR/sunshine.conf" >"$RUN_DIR/sunshine.log" 2>&1 &
SUNSHINE_PID=$!
echo "$SUNSHINE_PID" > "$RUN_DIR/sunshine.pid"
echo "Dell 虚拟显示器 ID ${DISPLAY_ID}；Sunshine 监听 ${MAC_IP}"

while kill -0 "$SUNSHINE_PID" 2>/dev/null && kill -0 "$VDISPLAY_PID" 2>/dev/null; do
  sleep 2
done
echo "显示器或 Sunshine 已退出，服务将重新启动。" >&2
exit 1
