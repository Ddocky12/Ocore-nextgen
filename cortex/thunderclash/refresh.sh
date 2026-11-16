#!/system/bin/sh
# ==============================================================================
# Ocore Display Refresh Rate Controller (refresh.sh v2.1)
# Synchronizes SurfaceFlinger display mode index AND Android Settings provider
# (peak_refresh_rate, min_refresh_rate, user_refresh_rate, tran_refresh_mode)
# for Android 11-16 & MediaTek / Infinix / Transsion compatibility.
# ==============================================================================

IDX="${1:--1}"
STATUS_FILE="/data/adb/modules/Ocore/cortex/thunderclash/refresh_index.txt"
STATE_DIR="/data/adb/ocore/state"
SAVE_FILE="$STATE_DIR/saved_refresh_settings.env"

mkdir -p "$STATE_DIR" 2>/dev/null

get_setting() {
  v="$(settings get "$1" "$2" 2>/dev/null)"
  case "$v" in
    ""|"null") echo "" ;;
    *) echo "$v" ;;
  esac
}

put_setting() {
  settings put "$1" "$2" "$3" >/dev/null 2>&1
}

sf_call() {
  service call SurfaceFlinger 1035 i32 "$1" >/dev/null 2>&1
}

# Save initial settings before first override
if [ ! -f "$SAVE_FILE" ] && [ "$IDX" != "-1" ]; then
  cat << EOS > "$SAVE_FILE"
SAVED_PEAK=$(get_setting system peak_refresh_rate)
SAVED_MIN=$(get_setting system min_refresh_rate)
SAVED_USER=$(get_setting system user_refresh_rate)
SAVED_TRAN=$(get_setting system tran_refresh_mode)
EOS
fi

case "$IDX" in
  -1)
    sf_call -1
    if [ -f "$SAVE_FILE" ]; then
      . "$SAVE_FILE"
      [ -n "$SAVED_PEAK" ] && put_setting system peak_refresh_rate "$SAVED_PEAK" || settings delete system peak_refresh_rate >/dev/null 2>&1
      [ -n "$SAVED_MIN" ] && put_setting system min_refresh_rate "$SAVED_MIN" || put_setting system min_refresh_rate "60.0"
      [ -n "$SAVED_USER" ] && put_setting system user_refresh_rate "$SAVED_USER" || put_setting system user_refresh_rate "0"
      [ -n "$SAVED_TRAN" ] && put_setting system tran_refresh_mode "$SAVED_TRAN"
      rm -f "$SAVE_FILE" 2>/dev/null
    else
      put_setting system min_refresh_rate "60.0"
      put_setting system peak_refresh_rate "120.0"
      put_setting system user_refresh_rate "0"
    fi
    echo "-1" > "$STATUS_FILE" 2>/dev/null
    echo "Refresh rate set to Auto (-1)"
    ;;
  0)
    sf_call 0
    put_setting system peak_refresh_rate "120.0"
    put_setting system min_refresh_rate "120.0"
    put_setting system user_refresh_rate "120"
    put_setting system tran_refresh_mode "120"
    echo "0" > "$STATUS_FILE" 2>/dev/null
    echo "Refresh rate locked to 120Hz (Index 0)"
    ;;
  1)
    sf_call 1
    put_setting system peak_refresh_rate "90.0"
    put_setting system min_refresh_rate "90.0"
    put_setting system user_refresh_rate "90"
    put_setting system tran_refresh_mode "90"
    echo "1" > "$STATUS_FILE" 2>/dev/null
    echo "Refresh rate locked to 90Hz (Index 1)"
    ;;
  2|3)
    sf_call "$IDX"
    put_setting system peak_refresh_rate "60.0"
    put_setting system min_refresh_rate "60.0"
    put_setting system user_refresh_rate "60"
    put_setting system tran_refresh_mode "60"
    echo "$IDX" > "$STATUS_FILE" 2>/dev/null
    echo "Refresh rate locked to 60Hz (Index $IDX)"
    ;;
  *)
    echo "$IDX" | grep -Eq '^-?[0-9]+$' || exit 1
    sf_call "$IDX"
    echo "$IDX" > "$STATUS_FILE" 2>/dev/null
    echo "Set refresh rate index to $IDX"
    ;;
esac

exit 0