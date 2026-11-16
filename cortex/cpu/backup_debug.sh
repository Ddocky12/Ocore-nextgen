#!/system/bin/sh
DEBUG_PATH="/proc/cpudvfs/cpufreq_debug"
BACKUP_FILE="/data/adb/modules/Ocore/cortex/thunderclash/cpu_debug_backup.txt"

if [ -f "$DEBUG_PATH" ]; then
    cat "$DEBUG_PATH" > "$BACKUP_FILE"
fi
