#!/system/bin/sh
# ==============================================================================
# OCORE NEXTGEN ULTIMATE - Subsystem: Gaming Engine
# Event-Driven Game Session State Machine & Adaptive Detection
# ==============================================================================
MODDIR="/data/adb/modules/ocore"
STATE_DIR="/data/adb/ocore/state"
AZ_CONF_DIR="/data/adb/.config/ocore"
OCORE_CONF="$AZ_CONF_DIR/ocore.conf"

mkdir -p "$STATE_DIR" "$AZ_CONF_DIR/gamelist" 2>/dev/null

# Load Dependencies if available
for _sub_eng in \
  "$MODDIR/engine/core/config_integrity_manager.sh" \
  "$MODDIR/engine/core/adaptive_polling_engine.sh" \
  "$MODDIR/engine/core/smart_resource_manager.sh" \
  "$MODDIR/engine/core/adaptive_gaming_engine.sh" \
  "$MODDIR/engine/core/fps_history_engine.sh" \
  "$MODDIR/engine/core/intelligent_fps_controller.sh"; do
  [ -f "$_sub_eng" ] && . "$_sub_eng"
done

is_non_game_package() {
  _ing_pkg="$1"
  [ -z "$_ing_pkg" ] && return 0
  case "$_ing_pkg" in
    android|system|id.ocore.gamecontrol|com.ocore.booster|flar2.devcheck|com.android.*|com.google.android.*|com.sec.android.app.launcher*|com.samsung.android.honeyboard*|com.miui.home*|com.miui.securitycenter*|com.transsion.*launcher*|com.transsion.XOSLauncher*|com.transsion.hilauncher*|com.transsion.smartpanel*|com.oppo.launcher*|com.bbk.launcher*|com.oneplus.launcher*|com.touchtype.swiftkey*|com.baidu.input*|com.iflytek.inputmethod*|me.weishu.kernelsu*|com.rifsxd.ksunext*|me.bmax.apatch*|com.topjohnwu.magisk*|io.github.a13e300.ksuwebui*|io.github.huskydg.magisk*|com.termux*|com.whatsapp*|org.telegram.messenger*|com.instagram.android*|com.facebook.katana*|com.zhiliaoapp.musically*|com.ss.android.ugc.trill*)
      return 0
      ;;
  esac
  if [ -f "$MODDIR/cortex/thunderclash/game_blacklist.txt" ] && grep -qx "$_ing_pkg" "$MODDIR/cortex/thunderclash/game_blacklist.txt" 2>/dev/null; then
    return 0
  fi
  if [ -f "$MODDIR/cortex/thunderclash/whitelist.txt" ] && grep -qx "$_ing_pkg" "$MODDIR/cortex/thunderclash/whitelist.txt" 2>/dev/null; then
    return 0
  fi
  return 1
}

is_package_in_gamelist() {
  _ipg_pkg="$1"
  [ -z "$_ipg_pkg" ] && return 1
  is_non_game_package "$_ipg_pkg" && return 1
  [ -f "$MODDIR/cortex/thunderclash/gamelist.txt" ] || return 1
  grep -qx "$_ipg_pkg" "$MODDIR/cortex/thunderclash/gamelist.txt" 2>/dev/null
}

sync_gamelist_artifacts() {
  _sga_gl="$MODDIR/cortex/thunderclash/gamelist.txt"
  _sga_bl="$MODDIR/cortex/thunderclash/game_blacklist.txt"
  mkdir -p "$MODDIR/cortex/thunderclash" "$AZ_CONF_DIR/gamelist" "$STATE_DIR" 2>/dev/null
  [ ! -f "$_sga_gl" ] && : > "$_sga_gl"

  _sga_tmp="${_sga_gl}.sync.$$"
  awk '/^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$/ { if (!seen[$0]++) print $0 }' "$_sga_gl" > "$_sga_tmp" 2>/dev/null

  if [ -f "$_sga_bl" ]; then
    _sga_tmp2="${_sga_gl}.sync2.$$"
    while IFS= read -r _g_item || [ -n "$_g_item" ]; do
      [ -z "$_g_item" ] && continue
      if ! is_non_game_package "$_g_item"; then
        echo "$_g_item"
      fi
    done < "$_sga_tmp" > "$_sga_tmp2" 2>/dev/null
    mv -f "$_sga_tmp2" "$_sga_tmp" 2>/dev/null
  fi
  mv -f "$_sga_tmp" "$_sga_gl" 2>/dev/null
  chmod 0644 "$_sga_gl" 2>/dev/null

  _json_tmp="$STATE_DIR/ocoreApplist.json.tmp.$$"
  {
    echo "{"
    echo '  "schema_version": 3200,'
    echo '  "canonical_source": "cortex/thunderclash/gamelist.txt",'
    echo '  "games": ['
    awk 'NF > 0 { lines[++n] = $0 } END { for (i = 1; i <= n; i++) { comma = (i < n) ? "," : ""; printf "    \"%s\"%s\n", lines[i], comma } }' "$_sga_gl"
    echo "  ]"
    echo "}"
  } > "$_json_tmp" 2>/dev/null

  cp -f "$_json_tmp" "$MODDIR/ocoreApplist.json" 2>/dev/null
  cp -f "$_json_tmp" "$AZ_CONF_DIR/gamelist/ocoreApplist.json" 2>/dev/null
  rm -f "$_json_tmp" 2>/dev/null
}

add_game_to_gamelist() {
  _agg_pkg=$(printf "%s" "$1" | tr -dc 'a-zA-Z0-9_.\-')
  if ! echo "$_agg_pkg" | grep -Eq '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$'; then
    return 1
  fi
  if is_non_game_package "$_agg_pkg"; then
    return 1
  fi
  _agg_gl="$MODDIR/cortex/thunderclash/gamelist.txt"
  if grep -qx "$_agg_pkg" "$_agg_gl" 2>/dev/null; then
    sync_gamelist_artifacts
    return 0
  fi
  echo "$_agg_pkg" >> "$_agg_gl"
  sync_gamelist_artifacts
  return 0
}

write_game_session_state() {
  _wgs_state="$1"
  _wgs_pkg="${2:-None}"
  _wgs_pid="${3:-0}"
  _wgs_ovl="${4:-0}"
  _wgs_reason="${5:-StateTransition}"
  _wgs_ts=$(date '+%s')
  _wgs_sf="$STATE_DIR/game_session_state.env"
  _wgs_tmp="${_wgs_sf}.tmp.$$"

  _auto_hud="1"
  [ -f "$OCORE_CONF" ] && {
    _ah=$(grep "^AUTO_FLOATING_HUD=" "$OCORE_CONF" 2>/dev/null | tail -n 1 | cut -d= -f2)
    [ -n "$_ah" ] && _auto_hud="$_ah"
  }
  if [ "$_auto_hud" = "0" ]; then
    _wgs_ovl="0"
  fi

  cat << EOS > "$_wgs_tmp"
SESSION_STATE=$_wgs_state
ACTIVE_GAME_PKG=$_wgs_pkg
ACTIVE_GAME_PID=$_wgs_pid
OVERLAY_ALLOWED=$_wgs_ovl
AUTO_FLOATING_HUD=$_auto_hud
STATE_REASON=$_wgs_reason
STATE_TIMESTAMP_SEC=$_wgs_ts
EOS
  mv -f "$_wgs_tmp" "$_wgs_sf" 2>/dev/null
}

# --- OCORE NEXTGEN ULTIMATE: EFFICIENT DETECTORS ---

get_foreground_package() {
  local focus
  # Fastest retrieval via Window Manager Focus (Android 10-16 compatible)
  focus=$(dumpsys window 2>/dev/null | grep -Eo 'mCurrentFocus=Window\{[0-9a-fA-F]+ u[0-9]+ [^/]+/' | head -n 1 | awk '{print $3}' | tr -d '/')
  
  if [ -z "$focus" ]; then
    # Fallback ActivityTaskManager check for rigorous OEMs
    focus=$(dumpsys activity activities 2>/dev/null | grep -E 'ResumedActivity' | grep -Eo '[a-zA-Z0-9_.]+/[a-zA-Z0-9_.]+' | head -n 1 | cut -d/ -f1)
  fi
  echo "$focus"
}

get_package_pid() {
  local pkg="$1"
  # Obtain main PID for package validation
  pidof "$pkg" 2>/dev/null | awk '{print $1}'
}

# --- STATE MACHINE LOOP ---

game_session_daemon() {
  local current_state="IDLE"
  local active_pkg="None"
  local active_pid=0
  local poll_interval=3
  
  write_game_session_state "IDLE" "None" 0 0 "DaemonStartup"
  
  while true; do
    local fg_pkg
    fg_pkg=$(get_foreground_package)
    
    case "$current_state" in
      IDLE|OVERLAY_HIDDEN|GAME_EXITED|RECOVERY)
        if [ -n "$fg_pkg" ] && is_package_in_gamelist "$fg_pkg"; then
          current_state="GAME_DETECTED"
          active_pkg="$fg_pkg"
          write_game_session_state "$current_state" "$active_pkg" 0 0 "AppGainedFocus"
          
          active_pid=$(get_package_pid "$active_pkg")
          if [ -n "$active_pid" ] && [ "$active_pid" -gt 0 ]; then
             current_state="GAME_VALIDATED"
             write_game_session_state "$current_state" "$active_pkg" "$active_pid" 1 "PidValidated"
             
             current_state="GAME_ACTIVE"
             write_game_session_state "$current_state" "$active_pkg" "$active_pid" 1 "GamingModeStarted"
             
             # ARBITER TRIGGER: Enter Gaming Mode
             [ -f "$MODDIR/engine/core/arbiter.sh" ] && sh "$MODDIR/engine/core/arbiter.sh" trigger_game_start "$active_pkg" &
             
             current_state="OVERLAY_ACTIVE"
             write_game_session_state "$current_state" "$active_pkg" "$active_pid" 1 "OverlayShown"
             
             poll_interval=2
          else
             current_state="IDLE"
             active_pkg="None"
             active_pid=0
             write_game_session_state "$current_state" "None" 0 0 "ValidationFailed"
          fi
        else
          poll_interval=3
        fi
        ;;
        
      GAME_ACTIVE|OVERLAY_ACTIVE)
        if [ "$fg_pkg" != "$active_pkg" ]; then
          current_state="GAME_BACKGROUND"
          write_game_session_state "$current_state" "$active_pkg" "$active_pid" 0 "AppLostFocus"
          
          current_state="GAME_EXITED"
          write_game_session_state "$current_state" "None" 0 0 "SessionEnded"
          
          # ARBITER TRIGGER: Exit Gaming Mode & Restore Resources
          [ -f "$MODDIR/engine/core/arbiter.sh" ] && sh "$MODDIR/engine/core/arbiter.sh" trigger_game_stop &
          
          current_state="IDLE"
          active_pkg="None"
          active_pid=0
          poll_interval=3
        else
          if ! kill -0 "$active_pid" 2>/dev/null; then
             current_state="GAME_EXITED"
             write_game_session_state "$current_state" "None" 0 0 "ProcessDiedOrCrashed"
             
             # ARBITER TRIGGER: Exit Gaming Mode & Restore Resources
             [ -f "$MODDIR/engine/core/arbiter.sh" ] && sh "$MODDIR/engine/core/arbiter.sh" trigger_game_stop &
             
             current_state="IDLE"
             active_pkg="None"
             active_pid=0
             poll_interval=3
          fi
        fi
        ;;
    esac
    sleep "$poll_interval"
  done
}

start_gaming_engine() {
  sync_gamelist_artifacts
  game_session_daemon &
  echo $! > "$STATE_DIR/gaming_engine.pid"
}

if [ "$(basename "$0")" = "gaming_engine.sh" ]; then
  start_gaming_engine
fi
