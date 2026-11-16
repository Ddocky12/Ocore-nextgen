#!/system/bin/sh

# File penyimpan index (0, 1, 2, 3, atau -1)
STATUS_FILE="/data/adb/modules/Ocore/cortex/thunderclash/refresh_index.txt"

if [ ! -f "$STATUS_FILE" ]; then echo "-1" > "$STATUS_FILE"; fi

CURRENT=$(cat "$STATUS_FILE")
NEXT_VAL=""
MSG=""

if [ "$CURRENT" = "-1" ]; then
    NEXT_VAL="0"
    MSG="Force: Level 0 (Max)"
elif [ "$CURRENT" = "0" ]; then
    NEXT_VAL="1"
    MSG="Force: Level 1"
elif [ "$CURRENT" = "1" ]; then
    NEXT_VAL="2"
    MSG="Force: Level 2"
elif [ "$CURRENT" = "2" ]; then
    NEXT_VAL="3"
    MSG="Force: Level 3 (60Hz)"
else
    # Balik ke Auto (-1)
    NEXT_VAL="-1"
    MSG="Mode: Auto / Reset"
fi

service call SurfaceFlinger 1035 i32 $NEXT_VAL

if [ "$NEXT_VAL" = "-1" ]; then
    settings put system min_refresh_rate 60
    settings put system peak_refresh_rate 0
    settings put system user_refresh_rate 0
fi

echo "$NEXT_VAL" > "$STATUS_FILE"

echo "$MSG"
