#!/system/bin/sh
# Ocore CPU/DVFSRC Normalizer (POSIX-compliant)
write_node() {
  if [ -e "$2" ]; then
    chmod 0644 "$2" 2>/dev/null
    echo "$1" > "$2" 2>/dev/null
  fi
}

DVFSRC_HELPER_PATH=$(find /sys/devices/platform -name "dvfsrc_req_ddr_opp" 2>/dev/null | head -n 1 | xargs dirname 2>/dev/null)
DEVFREQ_DVFSRC_PATH=""
for d in /sys/class/devfreq/*dvfsrc*; do
  if [ -d "$d" ]; then DEVFREQ_DVFSRC_PATH="$d"; break; fi
done

cluster=0
for path in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$path" ] || continue
  hw_max=$(cat "$path/cpuinfo_max_freq" 2>/dev/null)
  hw_min=$(cat "$path/cpuinfo_min_freq" 2>/dev/null)

  [ -n "$hw_max" ] && write_node "$cluster $hw_max" /proc/ppm/policy/hard_userlimit_max_cpu_freq
  [ -n "$hw_min" ] && write_node "$cluster $hw_min" /proc/ppm/policy/hard_userlimit_min_cpu_freq
  [ -n "$hw_max" ] && write_node "$hw_max" "$path/scaling_max_freq"
  [ -n "$hw_min" ] && write_node "$hw_min" "$path/scaling_min_freq"

  if [ -f "$path/scaling_boost_freq" ]; then
    write_node "0" "$path/scaling_boost_freq"
  elif [ -f "$path/scaling_boost_frequencies" ]; then
    write_node "0" "$path/scaling_boost_frequencies"
  fi
  cluster=$((cluster + 1))
done

# Always keep hardware thermal protection enabled
if [ -f "/proc/gpufreq/gpufreq_power_limited" ]; then
  for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
    write_node "$setting 0" /proc/gpufreq/gpufreq_power_limited
  done
fi
write_node "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop

if [ -n "$DVFSRC_HELPER_PATH" ]; then
  write_node "-1" "$DVFSRC_HELPER_PATH/dvfsrc_req_ddr_opp"
  [ -f "$DVFSRC_HELPER_PATH/dvfsrc_force_vcore_dvfs_opp" ] && write_node "-1" "$DVFSRC_HELPER_PATH/dvfsrc_force_vcore_dvfs_opp"
fi
write_node "-1" /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

if [ -n "$DEVFREQ_DVFSRC_PATH" ] && [ -f "$DEVFREQ_DVFSRC_PATH/available_frequencies" ]; then
  if grep -q "simple_ondemand" "$DEVFREQ_DVFSRC_PATH/available_governors" 2>/dev/null; then
    write_node "simple_ondemand" "$DEVFREQ_DVFSRC_PATH/governor"
  fi
  max_freq=$(tr ' ' '\n' < "$DEVFREQ_DVFSRC_PATH/available_frequencies" | sort -rn | head -n 1)
  min_freq=$(tr ' ' '\n' < "$DEVFREQ_DVFSRC_PATH/available_frequencies" | sort -n | head -n 1)
  [ -n "$min_freq" ] && write_node "$min_freq" "$DEVFREQ_DVFSRC_PATH/min_freq"
  [ -n "$max_freq" ] && write_node "$max_freq" "$DEVFREQ_DVFSRC_PATH/max_freq"
fi

exit 0
