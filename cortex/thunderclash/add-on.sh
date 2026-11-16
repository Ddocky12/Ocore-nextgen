#!/system/bin/sh
# Ocore Gaming & Performance Boost Helper
MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
LOG_FILE="/data/adb/ocore/logs/ocore_events.log"
OCORE_CONF="/data/adb/ocore/config.conf"
LOCK_FREQ="0"
[ -f "$OCORE_CONF" ] && LOCK_FREQ=$(grep "^THUNDER_LOCK_FREQ=" "$OCORE_CONF" 2>/dev/null | cut -d= -f2)

log_ocore() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [OCORE_BOOST] $1" >> "$LOG_FILE" 2>/dev/null
}

which_maxfreq() {
  tr ' ' '\n' <"$1" | grep -E '^[0-9]+$' | sort -nr | head -n 1
}

write_boost_node() {
  [ ! -f "$2" ] && return 1
  chmod 0644 "$2" 2>/dev/null
  echo "$1" > "$2" 2>/dev/null
  [ "$LOCK_FREQ" = "1" ] && chmod 0444 "$2" 2>/dev/null
}

override_oem_cpu_limits() {
  thermal_msg="/sys/devices/virtual/thermal/thermal_message/cpu_limits"
  [ ! -f "$thermal_msg" ] && return 1
  chmod 0644 "$thermal_msg" 2>/dev/null
  for path in /sys/devices/system/cpu/cpufreq/policy*; do
    [ ! -d "$path" ] && continue
    maxfreq=""
    if [ -f "$path/scaling_available_frequencies" ]; then
      maxfreq=$(which_maxfreq "$path/scaling_available_frequencies")
    elif [ -f "$path/cpuinfo_max_freq" ]; then
      maxfreq=$(cat "$path/cpuinfo_max_freq" 2>/dev/null)
    fi
    if [ -n "$maxfreq" ] && [ "$maxfreq" -gt 0 ] 2>/dev/null; then
      cpu_num="cpu${path##*policy}"
      echo "$cpu_num $maxfreq" > "$thermal_msg" 2>/dev/null
    fi
  done
}

set_cpu_boost() {
  for path in /sys/devices/system/cpu/cpufreq/policy*; do
    [ ! -d "$path" ] && continue
    target_max=""
    if [ -f "$path/scaling_available_frequencies" ]; then
      target_max=$(which_maxfreq "$path/scaling_available_frequencies")
    else
      target_max=$(cat "$path/cpuinfo_max_freq" 2>/dev/null)
    fi
    if [ -n "$target_max" ]; then
      if [ -f "$path/scaling_boost_freq" ]; then
        write_boost_node "$target_max" "$path/scaling_boost_freq"
      elif [ -f "$path/scaling_boost_frequencies" ]; then
        write_boost_node "$target_max" "$path/scaling_boost_frequencies"
      fi
    fi
  done
}

trigger_game_mode() {
  gm_dir="$MODDIR/cortex/gamemode"
  status_file="$gm_dir/status.txt"
  binary_exec="$gm_dir/gameon"
  if [ -f "$status_file" ]; then
    status=$(tr -d '[:space:]' < "$status_file")
    if [ "$status" = "on" ] && [ -f "$binary_exec" ]; then
      chmod 0755 "$binary_exec" 2>/dev/null
      "$binary_exec" >/dev/null 2>&1 &
    fi
  fi
}

override_oem_cpu_limits
set_cpu_boost
trigger_game_mode
log_ocore "Applied Ocore CPU boost parameters"
exit 0
