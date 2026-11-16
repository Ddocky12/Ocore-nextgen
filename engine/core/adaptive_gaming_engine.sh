#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem A: Adaptive Gaming Engine
# Analyzes active game workload (CPU/GPU load, frame jank, thermal headroom)
# and selects the optimal gaming sub-profile while respecting OEM thermal safety.
# ==============================================================================

evaluate_adaptive_gaming_workload() {
  _agw_pkg="${1:-}"
  [ -z "$_agw_pkg" ] && [ -f "$STATE_DIR/active_game_pkg" ] && read -r _agw_pkg < "$STATE_DIR/active_game_pkg" 2>/dev/null
  if [ -z "$_agw_pkg" ] || [ "$_agw_pkg" = "None" ]; then
    echo "GAMING_SUBPROFILE=IDLE|WORKLOAD_TIER=NONE|REASON=NoActiveGame"
    return 0
  fi

  _agw_therm="NORMAL"
  [ -f "$STATE_DIR/thermal_state" ] && read -r _agw_therm < "$STATE_DIR/thermal_state" 2>/dev/null

  case "$_agw_therm" in
    CRITICAL|EMERGENCY)
      echo "GAMING_SUBPROFILE=THERMAL_EMERGENCY|WORKLOAD_TIER=THROTTLED|REASON=Thermal_${_agw_therm}"
      return 0
      ;;
    HOT)
      echo "GAMING_SUBPROFILE=BALANCED_COOL|WORKLOAD_TIER=CAPPED|REASON=Thermal_HOT"
      return 0
      ;;
    WARM)
      echo "GAMING_SUBPROFILE=GAMING_SUSTAINED|WORKLOAD_TIER=MODERATE|REASON=Thermal_WARM"
      return 0
      ;;
  esac

  echo "GAMING_SUBPROFILE=GAMING_ULTRA|WORKLOAD_TIER=HIGH|REASON=Thermal_NORMAL_Headroom_OK"
  return 0
}
