#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Early Boot (post-fs-data.sh)
# Includes:
#  1. Non-Destructive Conflict Audit
#  2. Two-Stage Silicon-Lottery EEM Voltage & Anti-Bootloop Guard
#  3. Early MediaTek /vendor/etc/.tp Thermal Profile Staging (respects ALLOW_TRIP_POINT_MOD)
#  4. Stale Lock & PID Cleanup
# ==============================================================================

MODDIR=${0%/*}
LOCK_FILE="/dev/.ocoreSingleInstance"
OCORE_DIR="/data/adb/ocore"
OCORE_CONF="$OCORE_DIR/config.conf"
LOG_DIR="$OCORE_DIR/logs"
STATE_DIR="$OCORE_DIR/state"
BOOT_LOG="$LOG_DIR/boot_trace.log"

mkdir -p "$OCORE_DIR/config" "$OCORE_DIR/runtime" "$OCORE_DIR/hw" "$LOG_DIR" "$STATE_DIR/locks" "$MODDIR/backup" "$MODDIR/state" 2>/dev/null

if [ -f "$BOOT_LOG" ]; then
  cp -f "$BOOT_LOG" "$LOG_DIR/prev_boot_trace.log" 2>/dev/null
fi

echo "================================================================" > "$BOOT_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [POST-FS-DATA] Ocore Unified Performance Engine v3.2.0-NextGen early boot started" >> "$BOOT_LOG"

# 1. Non-Destructive Conflict Check
CONFLICTS=""
for compat_mod in RaiRin-AI AZenith ThermodMT6877 battmontester laya_kerneltuner mtkvoltoptimizer; do
  if [ -d "/data/adb/modules/$compat_mod" ] && [ ! -f "/data/adb/modules/$compat_mod/remove" ] && [ ! -f "/data/adb/modules/$compat_mod/disable" ]; then
    CONFLICTS="$CONFLICTS $compat_mod"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [CONFLICT] Active legacy module detected: /data/adb/modules/$compat_mod (Not deleted per safety policy)" >> "$BOOT_LOG"
  fi
done
echo "${CONFLICTS# }" > "$STATE_DIR/detected_conflicts.txt" 2>/dev/null

if [ -f "$LOCK_FILE" ]; then
  exit 0
fi
touch "$LOCK_FILE"

# 2. Two-Stage Anti-Bootloop & Silicon-Lottery Voltage Safe Guard
BOOTCOUNT=0
[ -f "$MODDIR/count.sh" ] && . "$MODDIR/count.sh"
BOOTCOUNT=$((BOOTCOUNT + 1))
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [POST-FS-DATA] Current BOOTCOUNT=$BOOTCOUNT" >> "$BOOT_LOG"

if [ "$BOOTCOUNT" -eq 2 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [VOLT_GUARD] Incomplete boot #2 detected! Auto-reverting EEM Voltage to STOCK (0/0/0/0) and activating Safe Recovery." >> "$BOOT_LOG"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [VOLT_GUARD] Incomplete boot #2 detected; auto-reverted EEM Voltage to STOCK (0/0/0/0)" >> "$LOG_DIR/errors.log"
  for cf in "$OCORE_CONF" "$OCORE_DIR/config/config.conf"; do
    if [ -f "$cf" ]; then
      sed -i 's/^VOLT_PROFILE=.*/VOLT_PROFILE=STOCK/' "$cf"
      sed -i 's/^VOLT_OFFSET_B=.*/VOLT_OFFSET_B=0/' "$cf"
      sed -i 's/^VOLT_OFFSET_L=.*/VOLT_OFFSET_L=0/' "$cf"
      sed -i 's/^VOLT_OFFSET_CCI=.*/VOLT_OFFSET_CCI=0/' "$cf"
      sed -i 's/^VOLT_OFFSET_GPU=.*/VOLT_OFFSET_GPU=0/' "$cf"
      sed -i 's/^GLOBAL_PROFILE=.*/GLOBAL_PROFILE=balanced/' "$cf"
    fi
  done
  echo "1" > "$STATE_DIR/volt_rollback_triggered"
  echo "BOOTCOUNT=$BOOTCOUNT" > "$MODDIR/count.sh"
elif [ "$BOOTCOUNT" -ge 3 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRIT] Anti-Bootloop Stage 2 triggered (BOOTCOUNT=$BOOTCOUNT)! Disabling module to protect device." >> "$BOOT_LOG"
  cp -f "$BOOT_LOG" "$LOG_DIR/last_bootloop_failure.log" 2>/dev/null
  dmesg | tail -n 200 >> "$LOG_DIR/last_bootloop_failure.log" 2>/dev/null
  touch "$MODDIR/disable"
  echo "BOOTCOUNT=0" > "$MODDIR/count.sh"
  sed -i "s/^description=.*/description=[SAFE RECOVERY: ANTI-BOOTLOOP TRIGGERED] Check \/data\/adb\/ocore\/logs\/last_bootloop_failure.log/" "$MODDIR/module.prop"
  exit 1
else
  echo "BOOTCOUNT=$BOOTCOUNT" > "$MODDIR/count.sh"
fi

# 3. Stage Active Thermal Profile into /vendor/etc/.tp Overlay
PERSIST_DIR="/data/adb/thermod_mt6877"
PROFILE="balanced"
SYNC_MTC_PROFILES="1"
ALLOW_TRIP_POINT_MOD="0"
if [ -f "$OCORE_CONF" ]; then
  . "$OCORE_CONF"
  PROFILE="${GLOBAL_PROFILE:-balanced}"
elif [ -f "$PERSIST_DIR/config.conf" ]; then
  . "$PERSIST_DIR/config.conf"
fi

if [ "${ALLOW_TRIP_POINT_MOD:-0}" = "1" ] && [ -f "$MODDIR/profiles/${PROFILE}.conf" ]; then
  cp -f "$MODDIR/profiles/${PROFILE}.conf" "$MODDIR/system/vendor/etc/.tp/thermal.conf" 2>>"$BOOT_LOG"
  chcon u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor/etc/.tp/thermal.conf" 2>>"$BOOT_LOG"
  if [ "$SYNC_MTC_PROFILES" = "1" ] && [ -d "/vendor/etc/.tp" ]; then
    for extra_tp in .ht120.mtc .ht60.mtc .thermal.HighTemp.conf thermal.off.conf; do
      if [ -f "/vendor/etc/.tp/$extra_tp" ]; then
        cp -f "$MODDIR/profiles/${PROFILE}.conf" "$MODDIR/system/vendor/etc/.tp/$extra_tp" 2>>"$BOOT_LOG"
        chcon u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor/etc/.tp/$extra_tp" 2>>"$BOOT_LOG"
      fi
    done
  fi
elif [ -f "$PERSIST_DIR/backup/.backed_up" ] && [ -f "$PERSIST_DIR/backup/thermal.conf" ]; then
  cp -af "$PERSIST_DIR/backup/"* "$MODDIR/system/vendor/etc/.tp/" 2>/dev/null
  chcon -R u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor/etc/.tp" 2>/dev/null
fi

# 4. Clean Stale Locks & PID Files on Reboot / Soft-Reboot
for p in $(/system/bin/toybox pidof sys.ocore-service sys.ocore-appmonitoring ocore.battmon-service ocore.ktuner-service ocore-bat ocore-game ocore-bypass ocore-daemon ocore-game-daemon ocore-fps-daemon 2>/dev/null); do
  kill -TERM "$p" 2>/dev/null
done
rm -rf /data/adb/.config/ocore/java.lock /data/adb/.config/ocore/API/.lock \
  "$STATE_DIR/locks"/*.lock "$STATE_DIR"/*.lock "$STATE_DIR"/pid_* "$STATE_DIR"/crash_* "$STATE_DIR"/cooldown_* "$STATE_DIR"/supervisor.pid 2>/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [POST-FS-DATA] Completed cleanly." >> "$BOOT_LOG"
exit 0
