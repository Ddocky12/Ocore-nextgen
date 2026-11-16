#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen — Powersave CPU & GPU Profile Script
# ==============================================================================
MOD="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MOD" ] && MOD="${0%/*}/../.."
export PATH=/sbin:/system/bin:/system/xbin:$PATH
ECO="$MOD/cortex/thunderclash"
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
  bin="$ECO/$1"
  if [ -f "$bin" ]; then
    chmod 0755 "$bin" 2>/dev/null
    rm -f "$MOD/ocoin_"*.log "$MOD/rairin_"*.log /data/local/tmp/ocoin_*.log /data/local/tmp/rairin_*.log 2>/dev/null
    "$bin" --log="$MOD/ocore_eco.log" >/dev/null 2>&1
  fi
}

apply_policy_eco() {
  policy="$1"
  cid="${policy##*policy}"
  avail_file="$policy/scaling_available_frequencies"

  if [ -f "$avail_file" ]; then
    freqs=$(tr ' ' '\n' < "$avail_file" | grep -v '^[[:space:]]*$' | sort -n)
    min_f=$(printf '%s\n' "$freqs" | head -n 1)
    total_opp=$(printf '%s\n' "$freqs" | wc -l | tr -dc '0-9')
    idx=$(( (total_opp * 7) / 10 ))
    [ "$idx" -lt 1 ] && idx=1
    target_f=$(printf '%s\n' "$freqs" | sed -n "${idx}p")
    [ -z "$target_f" ] && target_f="$min_f"
  else
    max_f=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
    min_f=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
    [ -z "$max_f" ] && return 1
    [ -z "$min_f" ] && min_f=0
    target_f=$(( min_f + ((max_f - min_f) * 7 / 10) ))
  fi
  [ -z "$target_f" ] && return 1

  chmod 0644 "$policy/scaling_max_freq" "$policy/scaling_min_freq" 2>/dev/null
  echo "$target_f" > "$policy/scaling_max_freq" 2>/dev/null
  echo "$min_f" > "$policy/scaling_min_freq" 2>/dev/null

  if [ "$LOCK_FREQ" = "1" ]; then
    chmod 0444 "$policy/scaling_max_freq" "$policy/scaling_min_freq" 2>/dev/null
  fi

  if [ -f "$DEBUG_PATH" ]; then
    chmod 0644 "$DEBUG_PATH" 2>/dev/null
    echo "$cid $min_f $target_f" > "$DEBUG_PATH" 2>/dev/null
  fi
}

run_sync "eco1"
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] && apply_policy_eco "$policy"
done
echo "powersave" > "$ECO/current_mode" 2>/dev/null
exit 0
