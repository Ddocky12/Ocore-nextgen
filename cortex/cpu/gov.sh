#!/system/bin/sh
DIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}/cortex/cpu"
BIN="$DIR/mini-backup"
OCORE_CONF="/data/adb/ocore/config.conf"
LOCK_FREQ="0"
[ -f "$OCORE_CONF" ] && LOCK_FREQ=$(grep "^THUNDER_LOCK_FREQ=" "$OCORE_CONF" 2>/dev/null | cut -d= -f2)

GOV="$1"
if [ -z "$GOV" ]; then
  echo "Usage: $0 <governor>"
  exit 1
fi

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$policy" ] || continue
  avail="$policy/scaling_available_governors"
  if [ -f "$avail" ] && ! grep -qw "$GOV" "$avail" 2>/dev/null; then
    continue
  fi
  chmod 0644 "$policy/scaling_governor" 2>/dev/null
  echo "$GOV" > "$policy/scaling_governor" 2>/dev/null
  [ "$LOCK_FREQ" = "1" ] && chmod 0444 "$policy/scaling_governor" 2>/dev/null
done

DEFAULT_FILE="$DIR/default-gov.txt"
chmod 0644 "$DEFAULT_FILE" 2>/dev/null
echo "$GOV" > "$DEFAULT_FILE" 2>/dev/null
[ -x "$BIN" ] && "$BIN" >/dev/null 2>&1
echo "[OK] CPU Governor set to $GOV"
exit 0
