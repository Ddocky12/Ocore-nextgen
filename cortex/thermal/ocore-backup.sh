#!/system/bin/sh
MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}/../.."
BIN="$MODDIR/cortex/thermal"

run_bg() {
  _rb_bin="$BIN/$1"
  if [ -f "$_rb_bin" ]; then
    chmod 0755 "$_rb_bin" 2>/dev/null
    nohup "$_rb_bin" >/dev/null 2>&1 &
  fi
}

run_bg "backup"
exit 0
