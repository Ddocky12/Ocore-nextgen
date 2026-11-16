#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #5: Vendor-Aware GPU Controller
# ==============================================================================
apply_gpu_mode_verified() {
  _agm_mode=$(sanitize_token "${1:-balance}")
  [ ! -f "$STATE_DIR/hw_capabilities.env" ] && scan_hardware_capabilities
  [ -f "$STATE_DIR/hw_capabilities.env" ] && . "$STATE_DIR/hw_capabilities.env"

  # Always enforce hardware GPU thermal & battery over-current protection
  if [ -f "/proc/gpufreq/gpufreq_power_limited" ]; then
    echo "ignore_thermal_protect 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
    echo "ignore_batt_oc 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
    echo "ignore_low_batt 0" > /proc/gpufreq/gpufreq_power_limited 2>/dev/null
  fi

  if [ "${HW_GPU_NODE:-UNSUPPORTED}" = "UNSUPPORTED" ] && [ ! -d "/proc/gpufreq" ] && [ ! -d "/proc/gpufreqv2" ] && [ ! -d "/sys/class/kgsl/kgsl-3d0/devfreq" ]; then
    save_ocore_key "GPU_MODE" "$_agm_mode"
    log_tx "UNSUPPORTED" "gpu_mode" "No writable GPU DVFS node detected on this device (saved preference=$_agm_mode)"
    echo "[UNSUPPORTED] No writable GPU DVFS interface detected on this hardware"
    return 2
  fi

  save_ocore_key "GPU_MODE" "$_agm_mode"
  case "$_agm_mode" in
    max|performance)
      [ -x "$MODDIR/cortex/thunderclash/gpu_max" ] && "$MODDIR/cortex/thunderclash/gpu_max" >/dev/null 2>&1
      ;;
    balance|balanced)
      [ -x "$MODDIR/cortex/thunderclash/gpu_balance" ] && "$MODDIR/cortex/thunderclash/gpu_balance" >/dev/null 2>&1
      ;;
    eco|powersave)
      [ -x "$MODDIR/cortex/thunderclash/gpu_eco" ] && "$MODDIR/cortex/thunderclash/gpu_eco" >/dev/null 2>&1
      ;;
    reset|stock|*)
      [ -x "$MODDIR/cortex/thunderclash/gpu_reset" ] && "$MODDIR/cortex/thunderclash/gpu_reset" >/dev/null 2>&1
      ;;
  esac
  log_tx "APPLIED" "gpu_mode" "GPU Mode=$_agm_mode (Arch=${HW_GPU_ARCH:-Generic})"
  echo "[OK] GPU Mode applied: $_agm_mode (${HW_GPU_ARCH:-Generic})"
  return 0
}
