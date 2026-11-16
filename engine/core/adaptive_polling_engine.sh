#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem D: Adaptive Polling Engine
# Dynamically adjusts polling intervals based on screen state, game session
# state, and frame pacing stability to guarantee near-zero idle overhead.
# ==============================================================================

compute_adaptive_polling_interval() {
  _ape_screen_off="0"
  [ -f "$STATE_DIR/screen_off_state" ] && read -r _ape_screen_off < "$STATE_DIR/screen_off_state" 2>/dev/null
  if [ "$_ape_screen_off" = "1" ]; then
    echo "POLL_MODE=SCREEN_OFF|GAME_POLL_SEC=6|FPS_POLL_SEC=0|HUD_POLL_MS=0"
    return 0
  fi

  _ape_game=""
  [ -f "$STATE_DIR/active_game_pkg" ] && read -r _ape_game < "$STATE_DIR/active_game_pkg" 2>/dev/null
  if [ -z "$_ape_game" ] || [ "$_ape_game" = "None" ]; then
    echo "POLL_MODE=IDLE|GAME_POLL_SEC=4|FPS_POLL_SEC=0|HUD_POLL_MS=0"
    return 0
  fi

  _ape_hud_ms="${HUD_POLL_INTERVAL_MS:-2000}"
  echo "POLL_MODE=GAMING_ACTIVE|GAME_POLL_SEC=2|FPS_POLL_SEC=2|HUD_POLL_MS=${_ape_hud_ms}"
  return 0
}
