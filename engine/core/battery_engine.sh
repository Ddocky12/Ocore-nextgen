#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #10: Battery Intelligence & Emergency Recovery
# ==============================================================================
emergency_charging_recovery() {
  graceful_stop_proc "ocore-bypass" "$STATE_DIR/pid_ocore_bypass"
  save_ocore_key "BYPASS_CHG_ENABLE" "0"
  save_ocore_key "SMART_CHARGE_LIMIT" "0"
  echo "0" > "$MODDIR/cortex/bypass/status.txt" 2>/dev/null
  echo "0" > "$AZ_CONF_DIR/bypasschgconfig/bypasschg" 2>/dev/null

  for _ecn in \
    "/proc/mtk_battery_cmd/current_cmd" \
    "/sys/class/power_supply/battery/charging_enabled" \
    "/sys/class/power_supply/battery/BatteryChargingEnabled" \
    "/sys/class/power_supply/battery/input_suspend" \
    "/sys/class/power_supply/battery/battery_input_suspend" \
    "/proc/driver/charger_limit_enable" \
    "/sys/devices/platform/mt-battery/disable_charger" \
    "/sys/devices/platform/charger/bypass_charger"; do
    if [ -e "$_ecn" ]; then
      chmod 0644 "$_ecn" 2>/dev/null
      case "$_ecn" in
        *current_cmd) echo "0 0" > "$_ecn" 2>/dev/null ;;
        *input_suspend|*disable_charger|*bypass_charger) echo "0" > "$_ecn" 2>/dev/null ;;
        *charging_enabled|*BatteryChargingEnabled|*charger_limit_enable) echo "1" > "$_ecn" 2>/dev/null ;;
      esac
    fi
  done
  log_tx "APPLIED" "emergency_charge_recover" "Restored normal battery charging across all charger nodes"
  echo "[OK] Emergency Charging Recovery completed: normal charging re-enabled."
}
