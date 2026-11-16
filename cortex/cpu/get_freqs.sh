#!/system/bin/sh
# Ocore Dynamic CPU Telemetry Reader (Zero-fork pure POSIX shell built-in reader)
for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
  [ -d "$cpu_dir" ] || continue
  cid="${cpu_dir##*/cpu}"
  cpufreq="$cpu_dir/cpufreq"
  on="1"
  if [ -f "$cpu_dir/online" ]; then
    read -r on < "$cpu_dir/online" 2>/dev/null || on="1"
  fi
  if [ -f "$cpufreq/scaling_cur_freq" ]; then
    cur=0; min=0; max=0; gov="schedutil"
    read -r cur < "$cpufreq/scaling_cur_freq" 2>/dev/null || cur=0
    read -r min < "$cpufreq/scaling_min_freq" 2>/dev/null || min=0
    read -r max < "$cpufreq/scaling_max_freq" 2>/dev/null || max=0
    read -r gov < "$cpufreq/scaling_governor" 2>/dev/null || gov="schedutil"
    echo "${cid}:${cur:-0},${min:-0},${max:-0},${on:-1},${gov:-schedutil}"
  else
    echo "${cid}:0,0,0,${on:-1},offline"
  fi
done
exit 0
