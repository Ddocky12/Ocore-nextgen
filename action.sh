#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Action Button & CLI Recovery
# Supports:
#   - Standard root manager tap (no args): Cycles Global Profile & runs One-Tap Boost
#   - Emergency recovery args: sh action.sh --safe-mode | --restore-all | --diag
# ==============================================================================
MODDIR=${0%/*}
OCORE_CONF="/data/adb/ocore/config.conf"

if [ "$1" = "--safe-mode" ] || [ "$1" = "safe" ]; then
  echo "========================================================"
  echo "   OCORE v3.2.0-NextGen — EMERGENCY SAFE MODE RECOVERY  "
  echo "========================================================"
  "$MODDIR/system/bin/ocorectl" recovery emergency_safe_mode
  exit 0
elif [ "$1" = "--restore-all" ] || [ "$1" = "restore" ]; then
  echo "========================================================"
  echo "   OCORE v3.2.0-NextGen — FULL STOCK RESTORE            "
  echo "========================================================"
  "$MODDIR/system/bin/ocorectl" recovery restore_all_stock
  exit 0
elif [ "$1" = "--diag" ] || [ "$1" = "diag" ]; then
  "$MODDIR/system/bin/ocorectl" diag
  exit 0
fi

GLOBAL_PROFILE="balanced"
[ -f "$OCORE_CONF" ] && . "$OCORE_CONF"

case "$GLOBAL_PROFILE" in
  balanced)    NEXT="performance" ;;
  performance) NEXT="gaming" ;;
  gaming)      NEXT="powersave" ;;
  powersave)   NEXT="balanced" ;;
  *)           NEXT="balanced" ;;
esac

echo "========================================================"
echo "   OCORE v3.2.0-NextGen — Unified Performance Switcher  "
echo "========================================================"
echo "- Switching Active Profile: $GLOBAL_PROFILE ---> $NEXT"
"$MODDIR/system/bin/ocorectl" profile "$NEXT"
echo ""
echo "- Running Ocore Safe One-Tap Memory & Cache Optimization..."
"$MODDIR/system/bin/ocorectl" one_tap_boost
echo ""
"$MODDIR/system/bin/thermod" status
echo "--------------------------------------------------------"
echo "Tip: Run 'su -c ocorectl recovery emergency_safe_mode' for CLI recovery."
echo "========================================================"
