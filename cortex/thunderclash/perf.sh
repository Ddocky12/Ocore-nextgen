#!/system/bin/sh
MODDIR="${0%/*}"
exec /system/bin/sh "$MODDIR/perf1.sh" "$@"
