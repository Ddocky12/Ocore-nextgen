#!/system/bin/sh
# Ocore Balanced CPU & GPU Profile Script
MOD="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
export PATH=/sbin:/system/bin:/system/xbin:$PATH
BAL="$MOD/cortex/thunderclash"
DEBUG_PATH="/proc/cpudvfs/cpufreq_debug"
OCORE_CONF="/data/adb/ocore/config.conf"
LOCK_FREQ="0"
SWP_VAL="100"
if [ -f "$OCORE_CONF" ]; then
  LOCK_FREQ=$(grep "^THUNDER_LOCK_FREQ=" "$OCORE_CONF" 2>/dev/null | cut -d= -f2)
  SWP_VAL=$(grep "^ZRAM_SWAPPINESS=" "$OCORE_CONF" 2>/dev/null | cut -d= -f2)
fi

mkdir -p "$MOD/backup" "$MOD/state" "/data/adb/ocore/state" 2>/dev/null

run_sync() {
  bin="$BAL/$1"
  if [ -f "$bin" ]; then
    chmod 0755 "$bin" 2>/dev/null
    rm -f "$MOD/ocoin_"*.log "$MOD/rairin_"*.log /data/local/tmp/ocoin_*.log /data/local/tmp/rairin_*.log 2>/dev/null
    "$bin" --log="$MOD/ocore_balance.log" >/dev/null 2>&1
  fi
}

apply_policy_bal() {
  policy="$1"
  cid=$(basename "$policy" | sed 's/policy//')
  avail_file="$policy/scaling_available_frequencies"

  if [ -f "$avail_file" ]; then
    freqs=$(tr ' ' '\n' < "$avail_file" | grep -v '^[[:space:]]*$' | sort -n)
    min_f=$(printf '%s\n' "$freqs" | head -n 1)
    max_f=$(printf '%s\n' "$freqs" | tail -n 1)
  else
    min_f=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
    max_f=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
  fi
  [ -z "$max_f" ] || [ -z "$min_f" ] && return 1

  chmod 0644 "$policy/scaling_max_freq" "$policy/scaling_min_freq" 2>/dev/null
  echo "$max_f" > "$policy/scaling_max_freq" 2>/dev/null
  echo "$min_f" > "$policy/scaling_min_freq" 2>/dev/null

  if [ "$LOCK_FREQ" = "1" ]; then
    chmod 0444 "$policy/scaling_max_freq" "$policy/scaling_min_freq" 2>/dev/null
  fi

  if [ -f "$DEBUG_PATH" ]; then
    chmod 0644 "$DEBUG_PATH" 2>/dev/null
    echo "$cid $min_f $max_f" > "$DEBUG_PATH" 2>/dev/null
  fi
}

sh "$BAL/oom_adj.sh" >/dev/null 2>&1
run_sync "balance1"

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] && apply_policy_bal "$policy"
done

[ -f "$BAL/gpu_balance" ] && "$BAL/gpu_balance" >/dev/null 2>&1

if [ -f "/proc/gpufreq/gpufreq_power_limited" ]; then
  echo "ignore_thermal_protect 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
  echo "ignore_batt_oc 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
  echo "ignore_low_batt 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
fi
[ -f "/proc/mtk_batoc_throttling/battery_oc_protect_stop" ] && echo "stop 0" > /proc/mtk_batoc_throttling/battery_oc_protect_stop 2>/dev/null
[ -n "$SWP_VAL" ] && [ -f "/proc/sys/vm/swappiness" ] && echo "$SWP_VAL" > /proc/sys/vm/swappiness 2>/dev/null
[ -f "/proc/sys/vm/vfs_cache_pressure" ] && echo "100" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
exit 0
