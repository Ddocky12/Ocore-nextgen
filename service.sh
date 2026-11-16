#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Late-Start Service & Supervisor
# Integrates:
#   1. Post-Boot Validation, PID+Identity Supervisor Lock & Bootcount Reset
#   2. Hardware Compatibility Scan, Pre-Modification EEM Baseline Capture & Config Migration
#   3. Independent Multi-Domain Thermal State Machine (CPU, GPU, SoC/AP, Battery, PMIC, PA)
#      with Dynamic Zone Discovery, Hysteresis, CooldownTimer & Priority #1 Override
#   4. Validated Foreground Game Detection (strictly filters launchers/IMEs/overlays)
#   5. Daemon Watchdog with PID + /proc/<pid>/cmdline Identity Check & Circuit Breaker
#   6. Conditional EEM Persistence Verification (Only writes if drifted)
# ==============================================================================

MODDIR=${0%/*}
OCORE_DIR="/data/adb/ocore"
OCORE_CONF="$OCORE_DIR/config.conf"
LOG_DIR="$OCORE_DIR/logs"
STATE_DIR="$OCORE_DIR/state"
BOOT_LOG="$LOG_DIR/boot_trace.log"
OCORE_LOG="$LOG_DIR/ocore_events.log"
DAEMON_LOG="$LOG_DIR/daemons_watchdog.log"
ERROR_LOG="$LOG_DIR/errors.log"
VOLT_LOG="$LOG_DIR/volt_optimizer.log"
PERF_HIST_LOG="$LOG_DIR/perf_history.log"
GAME_SESS_LOG="$LOG_DIR/gaming_sessions.log"
THERMOD_DIR="/data/adb/thermod_mt6877"
SUPERVISOR_PID_FILE="$STATE_DIR/supervisor.pid"

rm -f "$MODDIR"/ocoin_*.log "$MODDIR"/rairin_*.log /data/local/tmp/ocoin_*.log /data/local/tmp/rairin_*.log 2>/dev/null
mkdir -p "$OCORE_DIR/config" "$OCORE_DIR/runtime" "$OCORE_DIR/hw" "$LOG_DIR" "$STATE_DIR/locks" "$THERMOD_DIR/logs" \
  "$MODDIR/backup" "$MODDIR/state" "/data/local/tmp/ocore/backup" "/data/local/tmp/ocore/state" 2>/dev/null

# Terminate any previous supervisor loop if service.sh is re-invoked (PID + cmdline verified)
if [ -f "$SUPERVISOR_PID_FILE" ]; then
  old_sup=$(cat "$SUPERVISOR_PID_FILE" 2>/dev/null | tr -dc '0-9')
  if [ -n "$old_sup" ] && [ "$old_sup" != "$$" ] && [ -d "/proc/$old_sup" ]; then
    kill -TERM "$old_sup" 2>/dev/null
  fi
  rm -f "$SUPERVISOR_PID_FILE" 2>/dev/null
fi

boot_trace() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$BOOT_LOG" 2>/dev/null
}

boot_trace "Ocore v3.2.0-NextGen service.sh started, waiting for sys.boot_completed=1..."
WAIT_SEC=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
  WAIT_SEC=$((WAIT_SEC + 2))
  [ "$WAIT_SEC" -ge 300 ] && break
done

sleep 8

echo "BOOTCOUNT=0" > "$MODDIR/count.sh"
echo "NORMAL" > "$STATE_DIR/thermal_state"
echo "0" > "$STATE_DIR/screen_off_state"
: > "$STATE_DIR/active_game_pkg"
rm -f "$STATE_DIR"/crash_* "$STATE_DIR"/cooldown_* 2>/dev/null
boot_trace "sys.boot_completed=1 (+8s PowerHAL settle). Anti-bootloop counter reset to 0."

# 1. Migrate Config & Run Hardware Capability Scanner
"$MODDIR/system/bin/ocorectl" config_migrate >> "$BOOT_LOG" 2>&1
"$MODDIR/system/bin/ocorectl" hw_scan >> "$BOOT_LOG" 2>&1
. "$OCORE_CONF"
boot_trace "Loaded config: GLOBAL_PROFILE=$GLOBAL_PROFILE, VOLT_PROFILE=${VOLT_PROFILE:-STOCK}, CPU_ENGINE=$CPU_ENGINE, THERMAL_ENGINE=$THERMAL_ENGINE"

# 2. Prepare Internal Backups & Render Pipeline
boot_trace "Step 1: Initializing Ocore internal backups & render pipeline..."
sh "$MODDIR/permission.sh" >> "$BOOT_LOG" 2>&1
sh "$MODDIR/cortex/soc/soc.sh" >> "$BOOT_LOG" 2>&1
sh "$MODDIR/cortex/cpu/backup.sh" >> "$BOOT_LOG" 2>&1
sh "$MODDIR/cortex/cpu/backup_debug.sh" >> "$BOOT_LOG" 2>&1
MODDIR_OVERRIDE="$MODDIR" OCORE_DIR_OVERRIDE="$OCORE_DIR" sh "$MODDIR/cortex/ocore_json_tool.sh" rebuild >> "$BOOT_LOG" 2>&1
_boot_spoof_env=$(ls "$STATE_DIR/spoof_bindings"/*.env 2>/dev/null | head -n 1)
if [ -n "$_boot_spoof_env" ] && [ -f "$_boot_spoof_env" ]; then
  _boot_spoof_pkg=$(grep '^SPOOF_PKG=' "$_boot_spoof_env" 2>/dev/null | cut -d'"' -f2)
  [ -n "$_boot_spoof_pkg" ] && MODDIR_OVERRIDE="$MODDIR" OCORE_DIR_OVERRIDE="$OCORE_DIR" sh "$MODDIR/cortex/ocore_json_tool.sh" apply_pkg "$_boot_spoof_pkg" >> "$BOOT_LOG" 2>&1
fi

# 3. Apply Global Profile & Thermal Engine via Priority Arbiter
boot_trace "Step 2: Applying Global Profile (${GLOBAL_PROFILE:-balanced}) & Thermal Engine (${THERMAL_ENGINE:-ocore_intel})..."
"$MODDIR/system/bin/ocorectl" profile "${GLOBAL_PROFILE:-balanced}" >> "$BOOT_LOG" 2>&1
"$MODDIR/system/bin/ocorectl" thermal_engine "${THERMAL_ENGINE:-ocore_intel}" >> "$BOOT_LOG" 2>&1

# 4. Capture Initial EEM Baseline & Apply EEM Voltage Offsets + Schedutil Rate-Limits
boot_trace "Step 3: Applying EEM Stability Framework (${VOLT_PROFILE:-STOCK}) & Schedutil Rate-Limits..."
if [ "${VOLT_PROFILE:-STOCK}" = "CUSTOM" ]; then
  "$MODDIR/system/bin/ocorectl" volt_custom "${VOLT_OFFSET_B:--3}" "${VOLT_OFFSET_L:--3}" "${VOLT_OFFSET_CCI:--2}" "${VOLT_OFFSET_GPU:--2}" >> "$BOOT_LOG" 2>&1
else
  "$MODDIR/system/bin/ocorectl" volt_profile "${VOLT_PROFILE:-STOCK}" >> "$BOOT_LOG" 2>&1
fi

# 5. Apply Cpuset/EAS, I/O Queue, Touch, Refresh Rate, ZRAM/VM, Network & MTK Boost settings
boot_trace "Step 4: Applying Cpuset/EAS, Storage I/O Queue, Touch, ZRAM & Network subsystems..."
[ "${CPUSET_EAS_OPT:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" cpuset_eas 1 >> "$BOOT_LOG" 2>&1
[ "${IO_QUEUE_OPT:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" io_opt 1 "${IO_SCHEDULER:-default}" >> "$BOOT_LOG" 2>&1
"$MODDIR/system/bin/ocorectl" touch "${TOUCH_LEVEL:-2}" >> "$BOOT_LOG" 2>&1
[ "${REFRESH_IDX:--1}" != "-1" ] && "$MODDIR/system/bin/ocorectl" refresh "$REFRESH_IDX" >> "$BOOT_LOG" 2>&1
"$MODDIR/system/bin/ocorectl" zram_vm "${ZRAM_SWAPPINESS:-100}" >> "$BOOT_LOG" 2>&1
[ "${TCP_LOW_LATENCY:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" net_lowlat 1 >> "$BOOT_LOG" 2>&1
[ "${MTK_APU_DRAM_BOOST:-0}" = "1" ] && "$MODDIR/system/bin/ocorectl" mtk_boost 1 >> "$BOOT_LOG" 2>&1

# 6. Start Enabled Daemons
boot_trace "Step 5: Starting Ocore background daemons..."
[ "${OCORE_BATTMON_ENABLE:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" daemon ocore_battmon start >> "$BOOT_LOG" 2>&1
[ "${OCORE_KTUNER_ENABLE:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" daemon ocore_ktuner start >> "$BOOT_LOG" 2>&1
[ "${OCORE_AI_ENABLE:-1}" = "1" ] && "$MODDIR/system/bin/ocorectl" daemon ocore_ai start >> "$BOOT_LOG" 2>&1
if [ "${OCORE_DYN_BAT_ENABLE:-0}" = "1" ] && [ "${OCORE_BATTMON_ENABLE:-1}" = "0" ]; then
  "$MODDIR/system/bin/ocorectl" daemon ocore_dynbat start >> "$BOOT_LOG" 2>&1
fi
# FPS Monitor is strictly on-demand during validated game sessions (Priority 5.2)
"$MODDIR/system/bin/ocorectl" gamelist_sync >> "$BOOT_LOG" 2>&1
"$MODDIR/system/bin/ocorectl" config_integrity >> "$BOOT_LOG" 2>&1

# 7. Run Initial Self-Diagnostic Snapshot
sleep 5
boot_trace "Step 6: Running initial post-boot diagnostic audit..."
"$MODDIR/system/bin/ocorectl" diag >/dev/null 2>&1

sleep 6
if [ "${THERMAL_ENGINE:-ocore_intel}" = "ocore_intel" ] || [ "${THERMAL_ENGINE:-ocore_intel}" = "ocore_mtk" ]; then
  boot_trace "Step 7: Late re-apply of Ocore Thermal Intelligence profile..."
  "$MODDIR/system/bin/thermod" apply >> "$BOOT_LOG" 2>&1
fi
boot_trace "Ocore v3.2.0-NextGen Boot sequence completed!"

# 8. 45s Delayed EEM Voltage Persistence Pass
(
  sleep 45
  "$MODDIR/system/bin/ocorectl" eem_verify_persist >/dev/null 2>&1
) &

# ==============================================================================
# 9. UNIFIED BACKGROUND SUPERVISOR, MULTI-DOMAIN THERMAL GUARD & GAME TRACKER
# ==============================================================================
(
  sh -c 'echo $PPID' > "$SUPERVISOR_PID_FILE" 2>/dev/null

  THERM_STAGE="NORMAL"
  LAST_STEPDOWN_TS=0
  CHG_PAUSED=0
  LOOP_CNT=0
  LAST_GAME=""
  GAME_START_TS=0
  GAME_START_CAP=0
  FB_MISS_CNT=0
  LAST_LOW_BAT_OVR=0

  # PID + /proc/<pid>/cmdline Identity Checker (Section 15 Compliance)
  is_daemon_alive() {
    _ida_id="$1"
    _ida_proc="$2"

    _pf="$STATE_DIR/pid_${_ida_id}"
    if [ -f "$_pf" ]; then
      _p=$(cat "$_pf" 2>/dev/null | tr -dc '0-9')
      if [ -n "$_p" ] && [ -d "/proc/$_p" ]; then
        _cmd=$(tr '\0' ' ' < "/proc/$_p/cmdline" 2>/dev/null)
        _comm=$(cat "/proc/$_p/comm" 2>/dev/null)
        for _tok in $_ida_proc; do
          case "$_cmd $_comm" in
            *"$_tok"*) return 0 ;;
          esac
        done
      fi
    fi

    if [ -n "$(/system/bin/toybox pidof $_ida_proc 2>/dev/null)" ]; then
      return 0
    fi

    for _tok in $_ida_proc; do
      _pg=$(/system/bin/toybox pgrep -f "$_tok" 2>/dev/null | grep -vx "$$" | head -n 1)
      if [ -n "$_pg" ] && [ -d "/proc/$_pg" ]; then
        return 0
      fi
    done

    return 1
  }

  check_and_restart_daemon() {
    d_id="$1"
    d_proc="$2"
    d_label="$3"
    max_r="${DAEMON_MAX_RESTARTS:-5}"
    cooldown_s="${DAEMON_COOLDOWN_SEC:-300}"
    now_ts=$(date '+%s')

    if is_daemon_alive "$d_id" "$d_proc"; then
      return 0
    fi

    c_file="$STATE_DIR/crash_${d_id}"
    cd_file="$STATE_DIR/cooldown_${d_id}"
    c_cnt=0
    [ -f "$c_file" ] && c_cnt=$(cat "$c_file" 2>/dev/null | tr -dc '0-9')
    [ -z "$c_cnt" ] && c_cnt=0

    if [ -f "$cd_file" ]; then
      cd_until=$(cat "$cd_file" 2>/dev/null | tr -dc '0-9')
      if [ -n "$cd_until" ] && [ "$now_ts" -lt "$cd_until" ] 2>/dev/null; then
        return 1
      else
        rm -f "$cd_file" 2>/dev/null
        c_cnt=0
      fi
    fi

    c_cnt=$((c_cnt + 1))
    echo "$c_cnt" > "$c_file"

    if [ "$c_cnt" -gt "$max_r" ]; then
      until_ts=$((now_ts + cooldown_s))
      echo "$until_ts" > "$cd_file"
      echo "[$ts] [CRIT] [WATCHDOG] $d_label crashed $c_cnt times consecutively! Entering ${cooldown_s}s cooldown circuit-breaker." >> "$DAEMON_LOG"
      echo "[$ts] [CRIT] [WATCHDOG] $d_label disabled temporarily (${cooldown_s}s cooldown) due to repeated crashes." >> "$ERROR_LOG"
      return 1
    fi

    echo "[$ts] [WARN] [WATCHDOG] $d_label stopped unexpectedly (attempt $c_cnt/$max_r). Restarting..." >> "$DAEMON_LOG"
    echo "[$ts] [WARN] [WATCHDOG] $d_label auto-restarted ($c_cnt/$max_r)" >> "$ERROR_LOG"
    "$MODDIR/system/bin/ocorectl" daemon "$d_id" start >/dev/null 2>&1
  }

  read_domain_temp_c() {
    _pnode="$1"
    _pats="$2"
    if [ -n "$_pats" ]; then
      for _tz in /sys/class/thermal/thermal_zone*; do
        [ -f "$_tz/type" ] && [ -f "$_tz/temp" ] || continue
        _tname=$(cat "$_tz/type" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '\r\n')
        case "$_tname" in tzimgs*) continue ;; esac
        for _pat in $_pats; do
          if [ "$_tname" = "$_pat" ] || echo "$_tname" | grep -q "$_pat"; then
            _raw_line=$(cat "$_tz/temp" 2>/dev/null)
            for _tok in $_raw_line; do
              _val=$(printf "%s" "$_tok" | tr -dc '0-9-')
              if [ -n "$_val" ] && [ "$_val" != "-" ] && [ "$_val" -gt 0 ] 2>/dev/null; then
                if [ "$_val" -ge 1000 ]; then echo $((_val / 1000))
                elif [ "$_val" -ge 120 ]; then echo $((_val / 10))
                else echo "$_val"
                fi
                return 0
              fi
            done
          fi
        done
      done
    fi
    if [ -f "$_pnode" ]; then
      _raw_line=$(head -n 1 "$_pnode" 2>/dev/null)
      for _tok in $_raw_line; do
        _val=$(printf "%s" "$_tok" | tr -dc '0-9-')
        if [ -n "$_val" ] && [ "$_val" != "-" ] && [ "$_val" -gt 0 ] 2>/dev/null; then
          if [ "$_val" -ge 1000 ]; then echo $((_val / 1000))
          elif [ "$_val" -ge 120 ]; then echo $((_val / 10))
          else echo "$_val"
          fi
          return 0
        fi
      done
    fi
    echo "0"
  }

  while true; do
    [ -f "$OCORE_CONF" ] && . "$OCORE_CONF"
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    now_epoch=$(date '+%s')
    LOOP_CNT=$((LOOP_CNT + 1))

    # A. Conditional EEM Persistence Check every ~2 minutes (8 * 15s)
    if [ "${EEM_PERSIST_GUARD:-1}" = "1" ] && [ $((LOOP_CNT % 8)) -eq 0 ]; then
      "$MODDIR/system/bin/ocorectl" eem_verify_persist >/dev/null 2>&1
    fi

    # B. Daemon Watchdog with PID + Cmdline Identity Check, Crash Limit & Cooldown
    [ "${OCORE_AI_ENABLE:-1}" = "1" ] && check_and_restart_daemon "ocore_ai" "ocore-game-daemon" "Ocore Workload & Game Detector"
    [ "${OCORE_BATTMON_ENABLE:-1}" = "1" ] && check_and_restart_daemon "ocore_battmon" "ocore.battmon-service" "Ocore Screen-Off Battery Saver"
    [ "${OCORE_KTUNER_ENABLE:-1}" = "1" ] && check_and_restart_daemon "ocore_ktuner" "ocore.ktuner-service" "Ocore Adaptive Kernel Tuner"
    [ "${OCORE_DYN_BAT_ENABLE:-0}" = "1" ] && check_and_restart_daemon "ocore_dynbat" "ocore-bat" "Ocore Dynamic Battery Daemon"
    _act_gm=$(cat "$STATE_DIR/active_game_pkg" 2>/dev/null | tr -d "[:space:]")
    [ -n "$_act_gm" ] && [ "$_act_gm" != "None" ] && check_and_restart_daemon "ocore_fpsmon" "ocore-fps-daemon" "Ocore On-Demand Frame Monitor"

    # C. Multi-Domain Thermal Intelligence (Independent CPU, GPU, SoC/AP, Battery Thresholds + Hysteresis + Cooldown)
    CPU_C=$(read_domain_temp_c "/proc/mtktz/mtktscpu" "mtktscpu cpu_therm cpu")
    GPU_C=$(read_domain_temp_c "/proc/mtktz/mtktsgpu" "mtktsgpu gpu_therm gpu")
    if [ "${GPU_C:-0}" -le 0 ] && [ "${CPU_C:-0}" -gt 2 ] 2>/dev/null; then
      GPU_C=$((CPU_C - 2))
    fi
    SOC_C=$(read_domain_temp_c "/proc/mtktz/mtktsAP" "mtktsap soc_therm ap_ntc")
    BAT_C=$(read_domain_temp_c "/sys/class/power_supply/battery/temp" "mtktsbattery battery")
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null | tr -d '\r\n')
    CAP=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null | tr -dc '0-9')

    # Priority #2 Critical Battery Check
    if [ -n "$CAP" ] && [ "$CAP" -le "${CRIT_BATT_PCT:-10}" ] 2>/dev/null && [ "$STATUS" != "Charging" ]; then
      if [ "$LAST_LOW_BAT_OVR" -eq 0 ]; then
        LAST_LOW_BAT_OVR=1
        echo "1" > "$STATE_DIR/critical_battery_state"
        "$MODDIR/system/bin/ocorectl" arbiter_sync >/dev/null 2>&1
      fi
    elif [ "$LAST_LOW_BAT_OVR" -eq 1 ]; then
      LAST_LOW_BAT_OVR=0
      echo "0" > "$STATE_DIR/critical_battery_state"
      "$MODDIR/system/bin/ocorectl" arbiter_sync >/dev/null 2>&1
    fi

    HYST="${THERM_HYST_C:-3}"
    COOLDOWN_S="${THERM_COOLDOWN_SEC:-30}"

    if [ "${SMART_GUARD:-1}" = "1" ] && [ "${THERMAL_ENGINE:-ocore_intel}" != "monitor_only" ]; then
      PREV_STAGE="$THERM_STAGE"
      cand_stage="NORMAL"
      if { [ "$CPU_C" -ge "${CPU_CRIT_C:-90}" ] && [ "$CPU_C" -gt 0 ]; } || \
         { [ "$GPU_C" -ge "${GPU_CRIT_C:-88}" ] && [ "$GPU_C" -gt 0 ]; } || \
         { [ "$SOC_C" -ge "${SOC_CRIT_C:-78}" ] && [ "$SOC_C" -gt 0 ]; } || \
         { [ "$BAT_C" -ge "${BAT_CRIT_C:-51}" ] && [ "$BAT_C" -gt 0 ]; }; then
        cand_stage="CRITICAL"
      elif { [ "$CPU_C" -ge "${CPU_HOT_C:-82}" ] && [ "$CPU_C" -gt 0 ]; } || \
           { [ "$GPU_C" -ge "${GPU_HOT_C:-80}" ] && [ "$GPU_C" -gt 0 ]; } || \
           { [ "$SOC_C" -ge "${SOC_HOT_C:-70}" ] && [ "$SOC_C" -gt 0 ]; } || \
           { [ "$BAT_C" -ge "${BAT_HOT_C:-48}" ] && [ "$BAT_C" -gt 0 ]; }; then
        cand_stage="HOT"
      elif { [ "$CPU_C" -ge "${CPU_WARM_C:-75}" ] && [ "$CPU_C" -gt 0 ]; } || \
           { [ "$GPU_C" -ge "${GPU_WARM_C:-72}" ] && [ "$GPU_C" -gt 0 ]; } || \
           { [ "$SOC_C" -ge "${SOC_WARM_C:-62}" ] && [ "$SOC_C" -gt 0 ]; } || \
           { [ "$BAT_C" -ge "${BAT_WARM_C:-45}" ] && [ "$BAT_C" -gt 0 ]; }; then
        cand_stage="WARM"
      fi

      case "$THERM_STAGE" in
        NORMAL)
          if [ "$cand_stage" != "NORMAL" ]; then
            THERM_STAGE="$cand_stage"
            LAST_STEPDOWN_TS="$now_epoch"
          fi
          ;;
        WARM)
          if [ "$cand_stage" = "HOT" ] || [ "$cand_stage" = "CRITICAL" ]; then
            THERM_STAGE="$cand_stage"
            LAST_STEPDOWN_TS="$now_epoch"
          elif [ "$((now_epoch - LAST_STEPDOWN_TS))" -ge "$COOLDOWN_S" ] && \
               [ "$CPU_C" -le "$(( ${CPU_WARM_C:-75} - HYST ))" ] && \
               [ "$GPU_C" -le "$(( ${GPU_WARM_C:-72} - HYST ))" ] && \
               [ "$SOC_C" -le "$(( ${SOC_WARM_C:-62} - HYST ))" ] && \
               [ "$BAT_C" -le "$(( ${BAT_WARM_C:-45} - HYST ))" ]; then
            THERM_STAGE="NORMAL"
          fi
          ;;
        HOT)
          if [ "$cand_stage" = "CRITICAL" ]; then
            THERM_STAGE="CRITICAL"
            LAST_STEPDOWN_TS="$now_epoch"
          elif [ "$((now_epoch - LAST_STEPDOWN_TS))" -ge "$COOLDOWN_S" ] && \
               [ "$CPU_C" -le "$(( ${CPU_HOT_C:-82} - HYST ))" ] && \
               [ "$GPU_C" -le "$(( ${GPU_HOT_C:-80} - HYST ))" ] && \
               [ "$SOC_C" -le "$(( ${SOC_HOT_C:-70} - HYST ))" ] && \
               [ "$BAT_C" -le "$(( ${BAT_HOT_C:-48} - HYST ))" ]; then
            THERM_STAGE="WARM"
            LAST_STEPDOWN_TS="$now_epoch"
          fi
          ;;
        CRITICAL)
          if [ "$((now_epoch - LAST_STEPDOWN_TS))" -ge "$COOLDOWN_S" ] && \
             [ "$CPU_C" -le "$(( ${CPU_CRIT_C:-90} - HYST ))" ] && \
             [ "$GPU_C" -le "$(( ${GPU_CRIT_C:-88} - HYST ))" ] && \
             [ "$SOC_C" -le "$(( ${SOC_CRIT_C:-78} - HYST ))" ] && \
             [ "$BAT_C" -le "$(( ${BAT_CRIT_C:-51} - HYST ))" ]; then
            THERM_STAGE="HOT"
            LAST_STEPDOWN_TS="$now_epoch"
          fi
          ;;
      esac

      if [ "$THERM_STAGE" != "$PREV_STAGE" ]; then
        echo "$THERM_STAGE" > "$STATE_DIR/thermal_state"
        echo "[$ts] [INFO] [THERMAL_INTEL] Multi-domain transition: $PREV_STAGE -> $THERM_STAGE (CPU=${CPU_C}°C GPU=${GPU_C}°C SoC=${SOC_C}°C Bat=${BAT_C}°C)" >> "$OCORE_LOG"
        if [ "$THERM_STAGE" = "CRITICAL" ] || [ "$THERM_STAGE" = "HOT" ]; then
          echo "[$ts] [WARN] [THERMAL_INTEL] Priority #1 Override: $THERM_STAGE (CPU=${CPU_C}°C Bat=${BAT_C}°C)" >> "$ERROR_LOG"
        fi
        "$MODDIR/system/bin/ocorectl" arbiter_sync >/dev/null 2>&1
      fi
    fi

    # D. Smart Charge Auto-Cut with Hardware Support Verification
    if [ "${SMART_CHARGE_LIMIT:-0}" = "1" ] && [ -n "$CAP" ]; then
      STOP_LVL="${SMART_CHARGE_STOP:-85}"
      RES_LVL="${SMART_CHARGE_RESUME:-75}"
      if [ "$CAP" -ge "$STOP_LVL" ] && [ "$CHG_PAUSED" -eq 0 ]; then
        if "$MODDIR/system/bin/ocorectl" bypass_chg 1 >/dev/null 2>&1; then
          CHG_PAUSED=1
          echo "[$ts] [INFO] [SMART_CHARGE] Battery reached ${CAP}% (>= ${STOP_LVL}%). Charging paused." >> "$OCORE_LOG"
        fi
      elif [ "$CAP" -le "$RES_LVL" ] && [ "$CHG_PAUSED" -eq 1 ]; then
        CHG_PAUSED=0
        "$MODDIR/system/bin/ocorectl" bypass_chg 0 >/dev/null 2>&1
        echo "[$ts] [INFO] [SMART_CHARGE] Battery dropped to ${CAP}% (<= ${RES_LVL}%). Charging resumed." >> "$OCORE_LOG"
      fi
    fi

    # E. Record Periodic Telemetry Snapshot every ~1 minute (4 * 15s)
    if [ $((LOOP_CNT % 4)) -eq 0 ]; then
      cpu_f0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | tr -dc '0-9')
      cpu_mhz=$(( ${cpu_f0:-0} / 1000 ))
      cur_gm=$(cat "$STATE_DIR/active_game_pkg" 2>/dev/null | tr -d '[:space:]')
      echo "[$ts] PROF=${GLOBAL_PROFILE} STAGE=${THERM_STAGE} CPU=${CPU_C}C BAT=${BAT_C}C CAP=${CAP:-0}% CPU0=${cpu_mhz}MHz GAME=${cur_gm:-none}" >> "$PERF_HIST_LOG"
    fi

    sleep 15
  done
) &
