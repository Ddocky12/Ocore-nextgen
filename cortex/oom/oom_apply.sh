#!/system/bin/sh
BASE_DIR="/data/adb/modules/Ocore/cortex/oom"
BIN="$BASE_DIR/oom-bin"
chmod +x "$BIN"
"$BIN" "$@"
