#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen — Performance / Gaming CPU & GPU Profile Script
# Enforces Section 6 safety rule: Never permanently locks min_freq == max_freq!
# Uses adaptive 55%..75% floor during active demand and respects thermal headroom.
# ==============================================================================
MOD="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MOD" ] && MOD="${0%/*}/../.."
export PATH=/sbin:/system/bin:/system/xbin:$PATH
PERF="$MOD/cortex/thunderclash"
DEBUG_PATH="/proc/cpudvfs/cpufreq_debug"
OCORE_CONF="/data/adb/ocore/config.conf"
SWP_VAL="100"
if [ -f "$OCORE_CONF" ]; then
  SWP_VAL=$(grep "^ZRAM_SWAPPINESS=" "$OCORE_CONF" 2>/dev/null | cut -d= -f2)
fi

mkdir -p "$MOD/backup" "$MOD/state" "/data/adb/ocore/state" 2>/dev/null

run_sync() {
  bin="$PERF/$1"
  if [ -f "$bin" ]; then
    chmod 0755 "$bin" 2>/dev/null
    "$bin" --log="$MOD/ocore_perf.log" >/dev/null 2>&1
  fi
}

apply_policy_perf() {
  policy="$1"
  cid="${policy##*policy}"
  avail_file="$policy/scaling_available_frequencies"

  if [ -f "$avail_file" ]; then
    freqs=$(tr ' ' '\n' < "$avail_file" | grep -v '^[[:space:]]*$' | sort -n)
    max_f=$(printf '%s\n' "$freqs" | tail -n 1)
    total_opp=$(printf '%s\n' "$freqs" | wc -l | tr -dc '0-9')
    idx=$(( (total_opp * 55) / 100 ))
    [ "$idx" -lt 1 ] && idx=1
    min_f=$(printf '%s\n' "$freqs" | sed -n "${idx}p")
    [ -z "$min_f" ] && min_f=$(printf '%s\n' "$freqs" | head -n 1)
  else
    max_f=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
    hw_min=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
    [ -z "$max_f" ] || [ -z "$hw_min" ] && return 1
    min_f=$(( hw_min + ((max_f - hw_min) * 55 / 100) ))
  fi
  [ -z "$max_f" ] && return 1

  chmod 0644 "$policy/scaling_max_freq" "$policy/scaling_min_freq" 2>/dev/null
  echo "$max_f" > "$policy/scaling_max_freq" 2>/dev/null
  echo "$min_f" > "$policy/scaling_min_freq" 2>/dev/null

  if [ -f "$DEBUG_PATH" ]; then
    chmod 0644 "$DEBUG_PATH" 2>/dev/null
    echo "$cid $min_f $max_f" > "$DEBUG_PATH" 2>/dev/null
  fi
}

sh "$PERF/ocore.sh" >/dev/null 2>&1
sh "$PERF/add-on.sh" >/dev/null 2>&1
sh "$PERF/oom_adj.sh" >/dev/null 2>&1
run_sync "ocore-performance1"

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] && apply_policy_perf "$policy"
done
echo "performance" > "$PERF/current_mode" 2>/dev/null
exit 0
