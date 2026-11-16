#!/system/bin/sh
# ==============================================================================
# Ocore v3.0.0-NextGen — Safe Thermal Performance Wrapper
# Applies gaming/performance cooler ceiling via thermod while keeping OEM
# hardware thermal protection and emergency trip points active!
# ==============================================================================
MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}/../.."
TMP_ICON="/data/local/tmp/ocore.webp"

echo "on" > "$MODDIR/cortex/thermal/mode.txt" 2>/dev/null
echo "off" > "$MODDIR/cortex/thermal/lite-mode.txt" 2>/dev/null
[ -x "$MODDIR/system/bin/thermod" ] && "$MODDIR/system/bin/thermod" profile gaming >/dev/null 2>&1

su -lp 2000 -c "/system/bin/cmd notification post \
    -t 'Ocore' \
    -i file://$TMP_ICON \
    -I file://$TMP_ICON \
    'Ocore' 'Ocore Gaming Thermal Intelligence Enabled'" >/dev/null 2>&1
exit 0
