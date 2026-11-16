#!/system/bin/sh
CPU_PATH="/sys/devices/system/cpu"

toggle_cpu() {
  _tc_cpu="$1"
  _tc_online="$CPU_PATH/cpu${_tc_cpu}/online"
  if [ ! -f "$_tc_online" ]; then
    echo "CPU${_tc_cpu} not found"
    return 1
  fi
  chmod 0644 "$_tc_online" 2>/dev/null
  read -r _tc_val < "$_tc_online" 2>/dev/null || _tc_val="1"
  if [ "$_tc_val" = "1" ]; then
    echo 0 > "$_tc_online" 2>/dev/null
  else
    echo 1 > "$_tc_online" 2>/dev/null
  fi
  cat "$_tc_online" 2>/dev/null
}

if [ $# -eq 1 ]; then
  toggle_cpu "$1"
else
  echo "Usage: $0 <cpu_index>"
  exit 1
fi
exit 0
