#!/system/bin/sh
CPU_GOV="/sys/devices/system/cpu/cpu0/cpufreq"
DEST_DIR="/data/local/tmp/thunder_default"
DEST_FILE="$DEST_DIR/governor_default.txt"

mkdir -p "$DEST_DIR" 2>/dev/null

if [ -f "$CPU_GOV/scaling_governor" ]; then
  gov=$(tr '[:upper:]' '[:lower:]' < "$CPU_GOV/scaling_governor" 2>/dev/null)
else
  gov="schedutil"
fi
echo "${gov:-schedutil}" > "$DEST_FILE" 2>/dev/null

get_cpu_name() {
  _cn=""
  if [ -f /proc/device-tree/model ]; then
    _cn=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
  fi
  if [ -z "$_cn" ] && [ -f /proc/device-tree/compatible ]; then
    _cn=$(tr -d '\0' < /proc/device-tree/compatible 2>/dev/null | cut -d ',' -f1)
  fi
  if [ -z "$_cn" ]; then
    _cn=$(getprop ro.soc.model 2>/dev/null)
    [ -z "$_cn" ] && _cn=$(getprop ro.soc.manufacturer 2>/dev/null)
    [ -z "$_cn" ] && _cn=$(getprop ro.mediatek.platform 2>/dev/null)
    [ -z "$_cn" ] && _cn=$(getprop ro.board.platform 2>/dev/null)
    [ -z "$_cn" ] && _cn=$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | cut -d ':' -f2 | sed 's/^[ \t]*//')
  fi
  echo "${_cn:-unknown}" | tr '[:upper:]' '[:lower:]'
}

chipset=$(get_cpu_name)
soc_id=0
case "$chipset" in
  *mediatek*|*mt[0-9]*|*dimensity*|*helio*) soc_id=1 ;;
  *qualcomm*|*qcom*|*sm[0-9]*|*sdm*|*msm*|*snapdragon*) soc_id=2 ;;
  *samsung*|*exynos*|*erd*|*s5e*|*universal*) soc_id=3 ;;
  *unisoc*|*ums*|*sp[0-9]*|*spreadtrum*) soc_id=4 ;;
  *google*|*tensor*|*gs[0-9]*) soc_id=5 ;;
esac

echo "$soc_id" > "$DEST_DIR/soc" 2>/dev/null
exit 0
