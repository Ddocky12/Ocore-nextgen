#!/system/bin/sh
# ==============================================================================
# Ocore v3.0.0-NextGen — Stock Thermal Restoration Wrapper
# ==============================================================================
MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}/../.."
TMP_ICON="/data/local/tmp/ocore.webp"
BIN="$MODDIR/cortex/thermal/enable"

echo "off" > "$MODDIR/cortex/thermal/mode.txt" 2>/dev/null
echo "off" > "$MODDIR/cortex/thermal/lite-mode.txt" 2>/dev/null

if [ -f "$BIN" ]; then
  chmod 0755 "$BIN" 2>/dev/null
  nohup "$BIN" >/dev/null 2>&1 &
fi
[ -x "$MODDIR/system/bin/thermod" ] && "$MODDIR/system/bin/thermod" restore_stock >/dev/null 2>&1

su -lp 2000 -c "/system/bin/cmd notification post \
    -t 'Ocore' \
    -i file://$TMP_ICON \
    -I file://$TMP_ICON \
    'Ocore' 'OEM Stock Thermal Restored'" >/dev/null 2>&1
exit 0
