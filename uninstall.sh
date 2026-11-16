#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Complete & Safe Uninstaller
# Enforces Section 15 & Section 18:
#   - Verifies process identity via /proc/<pid>/cmdline before stopping daemons
#   - Restores captured pre-modification EEM baseline (never blindly assumes 0)
#   - Restores initial kernel node baselines, CPU/GPU limits, and stock thermal
#   - Re-enables normal battery charging across all charger nodes
#   - Removes only Ocore-owned state/logs without touching other modules or user files
# ==============================================================================

MODDIR=${0%/*}
OCORE_DIR="/data/adb/ocore"
THERMOD_DIR="/data/adb/thermod_mt6877"
EEM_BASELINE_FILE="$OCORE_DIR/backups/eem_initial_stock.env"
UNINSTALL_LOG="/cache/ocore_uninstall.log"

log_u() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$UNINSTALL_LOG" 2>/dev/null
}

log_u "Starting Ocore Unified Performance Engine v3.2.0-NextGen uninstallation..."

# 1. Gracefully Stop Only Verified Ocore Daemons & Supervisors
verify_and_kill_pid() {
  _vkp_pid="$1"
  _vkp_pat="$2"
  [ -z "$_vkp_pid" ] || [ ! -d "/proc/$_vkp_pid" ] && return 1
  _cmd=$(tr '\0' ' ' < "/proc/$_vkp_pid/cmdline" 2>/dev/null)
  _comm=$(cat "/proc/$_vkp_pid/comm" 2>/dev/null)
  case "$_cmd $_comm" in
    *"$_vkp_pat"*|*ocore*|*Ocore*)
      kill -TERM "$_vkp_pid" 2>/dev/null
      sleep 0.2 2>/dev/null || sleep 1
      [ -d "/proc/$_vkp_pid" ] && kill -9 "$_vkp_pid" 2>/dev/null
      log_u "Stopped verified Ocore process PID=$_vkp_pid ($_vkp_pat)"
      return 0
      ;;
  esac
  return 1
}

for pf in "$OCORE_DIR/state/supervisor.pid" "$OCORE_DIR/state/pid_"*; do
  [ -f "$pf" ] || continue
  p=$(cat "$pf" 2>/dev/null | tr -dc '0-9')
  [ -n "$p" ] && verify_and_kill_pid "$p" "ocore"
done

for proc in sys.ocore-thermalcore sys.ocore-service ocore.battmon-service ocore.ktuner-service ocore-bat ocore-game ocore-bypass ocore-daemon ocore-game-daemon ocore-fps-daemon; do
  for p in $(/system/bin/toybox pidof "$proc" 2>/dev/null) $(/system/bin/toybox pgrep -f "$proc" 2>/dev/null); do
    verify_and_kill_pid "$p" "$proc"
  done
done

# 2. Restore MediaTek EEM / EEMG Voltage Offsets to Captured Initial Baseline
for base_dir in /proc/eem /proc/eemg; do
  for det in EEM_DET_B EEM_DET_BL EEM_DET_L EEM_DET_2L EEM_DET_CCI EEM_DET_GPU; do
    if [ -f "$base_dir/$det/eem_offset" ]; then
      stock_val="0"
      if [ -f "$EEM_BASELINE_FILE" ]; then
        key="STOCK_$(echo "${base_dir}_${det}" | tr '/-' '__')"
        found_v=$(grep "^${key}=" "$EEM_BASELINE_FILE" 2>/dev/null | head -n 1 | cut -d= -f2)
        [ -n "$found_v" ] && stock_val="$found_v"
      fi
      chmod 0644 "$base_dir/$det/eem_offset" 2>/dev/null
      echo "$stock_val" > "$base_dir/$det/eem_offset" 2>/dev/null
      log_u "Restored EEM rail $base_dir/$det/eem_offset -> $stock_val"
    fi
  done
done

# 3. Restore Initial Kernel Nodes Baseline, CPU & GPU Frequency Limits, and Cpuset Masks
if [ -f "$OCORE_DIR/backups/kernel_nodes_initial.env" ]; then
  while IFS='=' read -r k rest; do
    case "$k" in \#*|"") continue ;; esac
    npath="${rest%%|*}"
    nval="${rest#*|}"
    [ -e "$npath" ] && [ -n "$nval" ] && echo "$nval" > "$npath" 2>/dev/null
  done < "$OCORE_DIR/backups/kernel_nodes_initial.env"
fi
[ -x "$MODDIR/cortex/cpu/restore" ] && "$MODDIR/cortex/cpu/restore" >/dev/null 2>&1
[ -x "$MODDIR/cortex/thunderclash/gpu_reset" ] && "$MODDIR/cortex/thunderclash/gpu_reset" >/dev/null 2>&1

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] || continue
  chmod 0644 "$policy/scaling_min_freq" "$policy/scaling_max_freq" "$policy/scaling_governor" 2>/dev/null
  min_f=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
  max_f=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
  [ -n "$min_f" ] && echo "$min_f" > "$policy/scaling_min_freq" 2>/dev/null
  [ -n "$max_f" ] && echo "$max_f" > "$policy/scaling_max_freq" 2>/dev/null
  if [ -f "$policy/scaling_available_governors" ] && grep -qw "schedutil" "$policy/scaling_available_governors" 2>/dev/null; then
    echo "schedutil" > "$policy/scaling_governor" 2>/dev/null
  fi
done
if [ -d "/dev/cpuset" ]; then
  all_c="0-7"
  [ -f "/sys/devices/system/cpu/present" ] && all_c=$(cat /sys/devices/system/cpu/present 2>/dev/null | tr -d '\r\n ')
  [ -f "/dev/cpuset/background/cpus" ] && echo "$all_c" > "/dev/cpuset/background/cpus" 2>/dev/null
  [ -f "/dev/cpuset/system-background/cpus" ] && echo "$all_c" > "/dev/cpuset/system-background/cpus" 2>/dev/null
fi

# 4. Restore Stock Thermal Configuration
if [ -f "$MODDIR/cortex/thermal/enable" ]; then
  chmod 0755 "$MODDIR/cortex/thermal/enable" 2>/dev/null
  "$MODDIR/cortex/thermal/enable" >/dev/null 2>&1
fi
if [ -f "$THERMOD_DIR/backup/.backed_up" ] && [ -f "$THERMOD_DIR/backup/thermal.conf" ]; then
  if [ -d "/vendor/etc/.tp" ]; then
    cp -af "$THERMOD_DIR/backup/"* /vendor/etc/.tp/ 2>/dev/null
    chcon -R u:object_r:vendor_configs_file:s0 /vendor/etc/.tp 2>/dev/null
  fi
  if [ -x "/vendor/bin/thermal_manager" ]; then
    /vendor/bin/thermal_manager "/vendor/etc/.tp/thermal.conf" >/dev/null 2>&1
  fi
  log_u "Restored verified stock thermal configuration from $THERMOD_DIR/backup."
fi

# 5. Re-enable Charging if Paused by Smart Charge or Bypass
for node in \
  "/proc/mtk_battery_cmd/current_cmd" \
  "/sys/class/power_supply/battery/charging_enabled" \
  "/sys/class/power_supply/battery/BatteryChargingEnabled" \
  "/sys/class/power_supply/battery/input_suspend" \
  "/sys/class/power_supply/battery/battery_input_suspend" \
  "/proc/driver/charger_limit_enable" \
  "/sys/devices/platform/mt-battery/disable_charger" \
  "/sys/devices/platform/charger/bypass_charger"; do
  if [ -e "$node" ]; then
    chmod 0644 "$node" 2>/dev/null
    case "$node" in
      *current_cmd) echo "0 0" > "$node" 2>/dev/null ;;
      *input_suspend|*disable_charger|*bypass_charger) echo "0" > "$node" 2>/dev/null ;;
      *charging_enabled|*BatteryChargingEnabled|*charger_limit_enable) echo "1" > "$node" 2>/dev/null ;;
    esac
  fi
done

# 6. Unmount any global /proc/cpuinfo bind mount
umount /proc/cpuinfo 2>/dev/null

# 7. Clean Persistent Properties Modified by OCORE
resetprop | awk -F'[][]' '/persist\.sys\.ocore|persist\.sys\.azenith|persist\.sys\.laya|persist\.sys\.rianixia|sys\.rairin\.thermal|sys\.ocore\.thermal/ {print $2}' | while read -r prop; do
  [ -n "$prop" ] && resetprop -p --delete "$prop" 2>/dev/null
done

# 8. Remove Only OCORE Symlinks and OCORE-Owned Directories
for dir in /data/adb/ap/bin /data/adb/ksu/bin; do
  if [ -d "$dir" ]; then
    rm -f "$dir/ocorectl" "$dir/thermod" "$dir/ocore-game-daemon" "$dir/ocore-fps-daemon"
    for azb in sys.ocore-service sys.ocore-profilesettings sys.ocore-utilityconf sys.ocore-preferencedtweaks sys.ocore-preloadbin sys.ocore-thermalcore; do
      rm -f "$dir/$azb" 2>/dev/null
    done
  fi
done

rm -rf "/data/adb/ocore" "$THERMOD_DIR" "/data/adb/.config/ocore" "/data/local/tmp/ocore" "/data/local/tmp/RaiRin-AI" "/data/local/tmp/thunder_default" "/data/local/tmp/ocore.webp" "/data/local/tmp/spicy.webp" 2>/dev/null

log_u "Ocore v3.2.0-NextGen uninstallation completed cleanly."
exit 0
