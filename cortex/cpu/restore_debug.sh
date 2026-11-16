#!/system/bin/sh
DEBUG_PATH="/proc/cpudvfs/cpufreq_debug"
BACKUP_FILE="/data/adb/modules/Ocore/cortex/thunderclash/cpu_debug_backup.txt"

if [ -f "$DEBUG_PATH" ] && [ -f "$BACKUP_FILE" ]; then
  chmod 0644 "$DEBUG_PATH" 2>/dev/null
  while read -r line; do
    cid=$(echo "$line" | sed -n 's/^cpu\([0-9]*\).*/\1/p')
    min_f=$(echo "$line" | sed -n 's/.*policy min\[\([0-9]*\)\].*/\1/p')
    max_f=$(echo "$line" | sed -n 's/.*policy max\[\([0-9]*\)\].*/\1/p')
    if [ -n "$cid" ] && [ -n "$min_f" ] && [ -n "$max_f" ]; then
      echo "$cid $min_f $max_f" > "$DEBUG_PATH" 2>/dev/null
    fi
  done < "$BACKUP_FILE"
fi
exit 0
