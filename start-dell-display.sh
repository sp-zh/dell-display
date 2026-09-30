#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="/private/tmp/dell-display-$(id -u)"
DELL_IP="169.254.118.3"

if [[ ! -x "$APP_DIR/bin/vdisplay" || ! -x /Applications/Sunshine.app/Contents/MacOS/Sunshine ]]; then
  echo "缺少虚拟显示器程序或 Sunshine；请查看 $APP_DIR/README.md" >&2
  exit 1
fi

MAC_IP="$(ifconfig bridge0 | awk '/^[[:space:]]*inet / { print $2; exit }')"
if [[ "$MAC_IP" != 169.254.* ]]; then
  echo "USB4 连接未就绪。请检查两台电脑间的数据线。" >&2
  exit 1
fi
if ! ping -c 1 -W 1000 "$DELL_IP" >/dev/null 2>&1; then
  echo "无法通过 USB4 联系 Dell ($DELL_IP)。" >&2
  exit 1
fi

mkdir -p "$RUN_DIR"
chmod 700 "$RUN_DIR"
if [[ -f "$RUN_DIR/worker.pid" ]] && kill -0 "$(cat "$RUN_DIR/worker.pid")" 2>/dev/null; then
  if [[ -f "$RUN_DIR/sunshine.pid" && -f "$RUN_DIR/vdisplay.pid" ]] &&
     kill -0 "$(cat "$RUN_DIR/sunshine.pid")" 2>/dev/null &&
     kill -0 "$(cat "$RUN_DIR/vdisplay.pid")" 2>/dev/null &&
     grep -Eq 'Found H.264 encoder|Found HEVC encoder' "$RUN_DIR/sunshine.log" 2>/dev/null &&
     ! grep -Eq 'No screen capture permission|Fatal:' "$RUN_DIR/sunshine.log" 2>/dev/null; then
    echo "Mac 端的 Dell 扩展屏已经运行。请在 Dell 的 Moonlight 中打开 Desktop。"
    exit 0
  fi
  echo "先前的 Dell 扩展屏进程仍在启动或需要排查：$RUN_DIR/worker.log" >&2
  exit 1
fi

cp "$APP_DIR/dell-display-worker.sh" "$RUN_DIR/worker.sh"
cp "$APP_DIR/bin/vdisplay" "$RUN_DIR/vdisplay"
chmod 700 "$RUN_DIR/worker.sh" "$RUN_DIR/vdisplay"
rm -f "$RUN_DIR/worker.pid" "$RUN_DIR/sunshine.pid" "$RUN_DIR/vdisplay.pid" \
      "$RUN_DIR/worker.log" "$RUN_DIR/sunshine.log" "$RUN_DIR/vdisplay.log"

RUN_DIR="$RUN_DIR" /opt/homebrew/bin/python3 - <<'PY'
import os
import subprocess

run_dir = os.environ['RUN_DIR']
with open(os.path.join(run_dir, 'worker.log'), 'wb') as output:
    subprocess.Popen(
        ['/bin/bash', os.path.join(run_dir, 'worker.sh')],
        cwd=run_dir,
        stdin=subprocess.DEVNULL,
        stdout=output,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
PY

for _ in {1..40}; do
  if [[ -f "$RUN_DIR/sunshine.pid" && -f "$RUN_DIR/vdisplay.pid" ]] &&
     kill -0 "$(cat "$RUN_DIR/sunshine.pid")" 2>/dev/null &&
     kill -0 "$(cat "$RUN_DIR/vdisplay.pid")" 2>/dev/null &&
     grep -Eq 'Found H.264 encoder|Found HEVC encoder' "$RUN_DIR/sunshine.log" 2>/dev/null &&
     ! grep -Eq 'No screen capture permission|Fatal:' "$RUN_DIR/sunshine.log" 2>/dev/null; then
    echo "Mac 端已启动 1920×1080、60 Hz 扩展屏。请在 Dell 的 Moonlight 中打开 Desktop。"
    exit 0
  fi
  if [[ -f "$RUN_DIR/sunshine.log" ]] && grep -Eq 'No screen capture permission|Fatal:' "$RUN_DIR/sunshine.log" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

echo "启动失败。最近的运行记录：" >&2
tail -n 20 "$RUN_DIR/worker.log" "$RUN_DIR/sunshine.log" 2>/dev/null >&2 || true
exit 1
