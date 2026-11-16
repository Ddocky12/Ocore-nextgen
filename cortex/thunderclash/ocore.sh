#!/system/bin/sh
# ==============================================================================
# Ocore Safe Foreground Game Task & Cgroup Optimizer (ocore.sh v3.2.0-NextGen)
# Rules enforced (Priority 5.3 & Priority 9):
#   - Validates package name strictly against regex & system blocklist
#   - Captures per-PID snapshot BEFORE optimization:
#       * PID starttime (field 22 of /proc/<pid>/stat) & cmdline/comm identity
#       * nice value (field 19 of /proc/<pid>/stat)
#       * oom_score_adj (/proc/<pid>/oom_score_adj)
#       * ionice class & level
#       * cpuset path (/proc/<pid>/cpuset)
#       * schedtune/stune path (/proc/<pid>/cgroup)
#   - Restores values ONLY if /proc/<pid> still exists AND matches both
#     original starttime and package/process identity (prevents PID reuse bug).
# ==============================================================================

MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}/../.."
OCORE_DIR="${OCORE_DIR_OVERRIDE:-/data/adb/ocore}"
STATE_DIR="$OCORE_DIR/state"
GAME_FILE="$MODDIR/cortex/thunderclash/game-active.txt"
SNAP_FILE="$STATE_DIR/game_proc_baseline.env"

mkdir -p "$STATE_DIR" 2>/dev/null

get_pid_starttime() {
  _gps_pid="$1"
  [ -f "/proc/$_gps_pid/stat" ] || return 1
  # Field 22 after closing ')' of comm field in /proc/<pid>/stat
  awk '{
    s = $0
    sub(/^.*\) /, "", s)
    split(s, a, " ")
    print a[20]
  }' "/proc/$_gps_pid/stat" 2>/dev/null
}

get_pid_nice() {
  _gpn_pid="$1"
  [ -f "/proc/$_gpn_pid/stat" ] || { echo "0"; return 1; }
  awk '{
    s = $0
    sub(/^.*\) /, "", s)
    split(s, a, " ")
    print a[17]
  }' "/proc/$_gpn_pid/stat" 2>/dev/null
}

get_pid_comm_tag() {
  _gpc_pid="$1"
  _cmd=$(tr '\0' ' ' < "/proc/$_gpc_pid/cmdline" 2>/dev/null | awk '{print $1}' | tr -dc 'a-zA-Z0-9_.:-')
  [ -z "$_cmd" ] && _cmd=$(cat "/proc/$_gpc_pid/comm" 2>/dev/null | tr -dc 'a-zA-Z0-9_.:-')
  echo "${_cmd:-unknown}"
}

validate_target() {
  PKG=""
  [ -f "$STATE_DIR/active_game_pkg" ] && PKG=$(tr -d '[:space:]' < "$STATE_DIR/active_game_pkg" 2>/dev/null)
  [ -z "$PKG" ] && [ -f "$GAME_FILE" ] && PKG=$(tr -d '[:space:]' < "$GAME_FILE" 2>/dev/null)
  [ -z "$PKG" ] && return 1

  echo "$PKG" | grep -Eq '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$' || return 1

  case "$PKG" in
    android|system|com.android.systemui|com.android.settings|com.android.phone|com.android.nfc|com.google.android.gms*|me.weishu.kernelsu|com.rifsxd.ksunext|me.bmax.apatch|com.topjohnwu.magisk)
      return 1
      ;;
  esac
  if [ -f "$MODDIR/cortex/thunderclash/game_blacklist.txt" ] && grep -qx "$PKG" "$MODDIR/cortex/thunderclash/game_blacklist.txt" 2>/dev/null; then
    return 1
  fi
  if [ -f "$MODDIR/cortex/thunderclash/gamelist.txt" ] && ! grep -qx "$PKG" "$MODDIR/cortex/thunderclash/gamelist.txt" 2>/dev/null; then
    return 1
  fi
  return 0
}

optimize_process_safe() {
  target_pkg="$1"
  pids=$(/system/bin/toybox pidof "$target_pkg" 2>/dev/null)
  [ -z "$pids" ] && return 1

  tmp_snap="${SNAP_FILE}.tmp.$$"
  : > "$tmp_snap" 2>/dev/null

  for pid in $pids; do
    [ -d "/proc/$pid" ] || continue
    st_time=$(get_pid_starttime "$pid")
    [ -z "$st_time" ] && continue
    comm_tag=$(get_pid_comm_tag "$pid")
    orig_nice=$(get_pid_nice "$pid")
    [ -z "$orig_nice" ] && orig_nice="0"
    orig_oom=$(cat "/proc/$pid/oom_score_adj" 2>/dev/null | tr -dc '0-9-')
    [ -z "$orig_oom" ] && orig_oom="0"
    orig_cpuset=$(cat "/proc/$pid/cpuset" 2>/dev/null | tr -d '\r\n ')
    [ -z "$orig_cpuset" ] && orig_cpuset="/top-app"
    orig_stune=$(awk -F: '$2 ~ /schedtune|stune/ {print $3; exit}' "/proc/$pid/cgroup" 2>/dev/null | tr -d '\r\n ')
    [ -z "$orig_stune" ] && orig_stune="/top-app"
    orig_ioclass="2"
    orig_ioprio="4"
    if command -v ionice >/dev/null 2>&1; then
      io_out=$(ionice -p "$pid" 2>/dev/null)
      case "$io_out" in
        *realtime*) orig_ioclass="1" ;;
        *best-effort*) orig_ioclass="2" ;;
        *idle*) orig_ioclass="3" ;;
      esac
      io_p=$(echo "$io_out" | grep -oE 'prio [0-9]+' | awk '{print $2}')
      [ -n "$io_p" ] && orig_ioprio="$io_p"
    fi

    # If a snapshot already exists for this exact PID + starttime, preserve original baseline
    if [ -f "$SNAP_FILE" ] && grep -q "^SNAP|${pid}|${st_time}|" "$SNAP_FILE" 2>/dev/null; then
      grep "^SNAP|${pid}|${st_time}|" "$SNAP_FILE" | head -n 1 >> "$tmp_snap"
    else
      echo "SNAP|${pid}|${st_time}|${comm_tag}|${orig_oom}|${orig_nice}|${orig_ioclass}|${orig_ioprio}|${orig_cpuset}|${orig_stune}" >> "$tmp_snap"
    fi

    # Apply conservative scheduling priority (-5) & best-effort I/O priority (class 2, prio 2)
    renice -n -5 -p "$pid" >/dev/null 2>&1
    if command -v ionice >/dev/null 2>&1; then
      ionice -c 2 -n 2 -p "$pid" >/dev/null 2>&1
    fi

    # Place main process and render/unity threads into top-app cgroups
    [ -w "/dev/stune/top-app/tasks" ] && echo "$pid" > "/dev/stune/top-app/tasks" 2>/dev/null
    [ -w "/dev/cpuset/top-app/tasks" ] && echo "$pid" > "/dev/cpuset/top-app/tasks" 2>/dev/null
    [ -w "/sys/fs/cgroup/top-app/cgroup.procs" ] && echo "$pid" > "/sys/fs/cgroup/top-app/cgroup.procs" 2>/dev/null

    # Conservative OOM protection (-100 max, never -500/-1000)
    if [ -w "/proc/$pid/oom_score_adj" ]; then
      echo "-100" > "/proc/$pid/oom_score_adj" 2>/dev/null
    fi
  done

  mv -f "$tmp_snap" "$SNAP_FILE" 2>/dev/null
  return 0
}

restore_process_safe() {
  [ ! -f "$SNAP_FILE" ] && return 0
  while IFS='|' read -r tag pid saved_st saved_comm orig_oom orig_nice orig_ioclass orig_ioprio orig_cpuset orig_stune; do
    [ "$tag" = "SNAP" ] || continue
    [ -n "$pid" ] && [ -d "/proc/$pid" ] || continue

    # Verify PID identity (starttime + comm/cmdline) to prevent restoring onto a reused PID!
    cur_st=$(get_pid_starttime "$pid")
    cur_comm=$(get_pid_comm_tag "$pid")
    if [ "$cur_st" != "$saved_st" ] || [ "$cur_comm" != "$saved_comm" ]; then
      continue
    fi

    renice -n "${orig_nice:-0}" -p "$pid" >/dev/null 2>&1
    if command -v ionice >/dev/null 2>&1 && [ -n "$orig_ioclass" ]; then
      ionice -c "${orig_ioclass:-2}" -n "${orig_ioprio:-4}" -p "$pid" >/dev/null 2>&1
    fi
    if [ -w "/proc/$pid/oom_score_adj" ]; then
      echo "${orig_oom:-0}" > "/proc/$pid/oom_score_adj" 2>/dev/null
    fi
    if [ -n "$orig_cpuset" ] && [ -w "/dev/cpuset${orig_cpuset}/tasks" ]; then
      echo "$pid" > "/dev/cpuset${orig_cpuset}/tasks" 2>/dev/null
    fi
    if [ -n "$orig_stune" ] && [ -w "/dev/stune${orig_stune}/tasks" ]; then
      echo "$pid" > "/dev/stune${orig_stune}/tasks" 2>/dev/null
    fi
  done < "$SNAP_FILE"
  rm -f "$SNAP_FILE" 2>/dev/null
  return 0
}

case "$1" in
  --restore)
    restore_process_safe
    ;;
  *)
    if validate_target; then
      optimize_process_safe "$PKG"
    fi
    ;;
esac
exit 0
