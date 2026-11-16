#!/system/bin/sh
DIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}/cortex/cpu"
[ ! -d "$DIR" ] && DIR="${0%/*}"

run_bg() {
  _rb_bin="$DIR/$1"
  if [ -f "$_rb_bin" ]; then
    chmod 0755 "$_rb_bin" 2>/dev/null
    nohup "$_rb_bin" --force >/dev/null 2>&1 &
  fi
}

run_bg "backup"
exit 0
