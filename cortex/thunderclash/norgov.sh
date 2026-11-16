#!/system/bin/sh
# Ocore Normal / Stock CPU & GPU Restoration Script
MOD="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
DIR="$MOD/cortex/cpu"
BIN="$DIR/restore"
TMP_ICON="/data/local/tmp/ocore.webp"
[ ! -f "$TMP_ICON" ] && TMP_ICON="/data/local/tmp/ocore.webp"
DEBUG_PATH="/proc/cpudvfs/cpufreq_debug"
GPU="$MOD/cortex/thunderclash"

if [ -f "$BIN" ]; then
  chmod 0755 "$BIN" 2>/dev/null
  "$BIN" >/dev/null 2>&1
fi

[ -f "$MOD/break.sh" ] && sh "$MOD/break.sh" >/dev/null 2>&1
[ -f "$DIR/add-on.sh" ] && sh "$DIR/add-on.sh" >/dev/null 2>&1
[ -f "$GPU/gpu_reset" ] && "$GPU/gpu_reset" >/dev/null 2>&1
[ -f "$DIR/restore_debug.sh" ] && sh "$DIR/restore_debug.sh" >/dev/null 2>&1

if [ -f "$DEBUG_PATH" ]; then
  chmod 0644 "$DEBUG_PATH" 2>/dev/null
  for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    cid=$(basename "$policy" | sed 's/policy//')
    avail_file="$policy/scaling_available_frequencies"
    if [ -f "$avail_file" ]; then
      freqs=$(tr ' ' '\n' < "$avail_file" | sort -n | grep -v '^$')
      cmin=$(echo "$freqs" | head -n 1)
      cmax=$(echo "$freqs" | tail -n 1)
    else
      cmin=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
      cmax=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
    fi
    [ -n "$cmin" ] && [ -n "$cmax" ] && echo "$cid $cmin $cmax" > "$DEBUG_PATH" 2>/dev/null
  done
fi

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] || continue
  avail_file="$policy/scaling_available_frequencies"
  if [ -f "$avail_file" ]; then
    freqs=$(tr ' ' '\n' < "$avail_file" | sort -n | grep -v '^$')
    cmin=$(echo "$freqs" | head -n 1)
    cmax=$(echo "$freqs" | tail -n 1)
  else
    cmin=$(cat "$policy/cpuinfo_min_freq" 2>/dev/null)
    cmax=$(cat "$policy/cpuinfo_max_freq" 2>/dev/null)
  fi
  chmod 0644 "$policy/scaling_max_freq" "$policy/scaling_min_freq" "$policy/scaling_governor" 2>/dev/null
  [ -n "$cmin" ] && echo "$cmin" > "$policy/scaling_min_freq" 2>/dev/null
  [ -n "$cmax" ] && echo "$cmax" > "$policy/scaling_max_freq" 2>/dev/null
done

if [ -f "/proc/ppm/enabled" ]; then
  chmod 0644 "/proc/ppm/enabled" 2>/dev/null
  echo "1" > "/proc/ppm/enabled" 2>/dev/null
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [OCORE_CORE] Normal CPU/GPU scaling limits restored" >> "/data/adb/ocore/logs/ocore_events.log" 2>/dev/null
exit 0
