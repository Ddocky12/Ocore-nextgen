#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #4: Dynamic Per-Policy CPU Controller
# Supports per-policy min/max kHz, governor validation, custom profile scaling,
# schedutil rate-limits, and EAS/Cpuset partitioning without permanent max lock.
# ==============================================================================
set_cpu_policy_limits() {
  _scp_pol_id=$(sanitize_int "$1" "0")
  _scp_min=$(sanitize_int "$2" "0")
  _scp_max=$(sanitize_int "$3" "0")
  _scp_gov=$(sanitize_token "$4")
  _pol_dir="/sys/devices/system/cpu/cpufreq/policy${_scp_pol_id}"

  if [ ! -d "$_pol_dir" ]; then
    log_tx "UNSUPPORTED" "cpu_policy_set" "CPU policy${_scp_pol_id} not present on this device"
    echo "[UNSUPPORTED] CPU policy${_scp_pol_id} not found"
    return 2
  fi

  unlock_cpu_nodes
  _rc=0
  if [ -n "$_scp_gov" ] && [ -f "$_pol_dir/scaling_available_governors" ]; then
    if grep -qw "$_scp_gov" "$_pol_dir/scaling_available_governors" 2>/dev/null; then
      safe_write_node "CPU_POL" "$_pol_dir/scaling_governor" "$_scp_gov" "0644" "1" || _rc=1
    else
      log_tx "FAILED" "cpu_policy_set" "Governor $_scp_gov not supported by policy${_scp_pol_id}"
      echo "[ERROR] Governor '$_scp_gov' is not in scaling_available_governors for policy${_scp_pol_id}"
      return 1
    fi
  fi
  if [ "$_scp_max" -gt 0 ] 2>/dev/null && [ -f "$_pol_dir/scaling_max_freq" ]; then
    safe_write_node "CPU_POL" "$_pol_dir/scaling_max_freq" "$_scp_max" "0644" "1" || _rc=1
  fi
  if [ "$_scp_min" -gt 0 ] 2>/dev/null && [ -f "$_pol_dir/scaling_min_freq" ]; then
    safe_write_node "CPU_POL" "$_pol_dir/scaling_min_freq" "$_scp_min" "0644" "1" || _rc=1
  fi

  if [ "$_rc" -eq 0 ]; then
    log_tx "APPLIED" "cpu_policy_set" "policy${_scp_pol_id}: min=$_scp_min max=$_scp_max gov=${_scp_gov:-keep}"
    echo "[OK] Updated policy${_scp_pol_id} (min=${_scp_min}kHz max=${_scp_max}kHz gov=${_scp_gov:-unchanged})"
    return 0
  else
    log_tx "ROLLED_BACK" "cpu_policy_set" "Failed readback on policy${_scp_pol_id}"
    echo "[ROLLED_BACK] Readback verification failed on policy${_scp_pol_id}"
    return 3
  fi
}

apply_custom_cpu_profile() {
  validate_and_load_config
  _min_pct=$(sanitize_int "${CUSTOM_CPU_MIN_PCT:-20}" "20")
  _max_pct=$(sanitize_int "${CUSTOM_CPU_MAX_PCT:-90}" "90")
  _c_gov=$(sanitize_token "${CUSTOM_CPU_GOV:-schedutil}")
  [ "$_min_pct" -lt 10 ] && _min_pct=10
  [ "$_max_pct" -gt 100 ] && _max_pct=100
  [ "$_min_pct" -gt "$_max_pct" ] && _min_pct="$_max_pct"

  for _pol in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$_pol" ] || continue
    _hw_min=$(cat "$_pol/cpuinfo_min_freq" 2>/dev/null | tr -dc '0-9')
    _hw_max=$(cat "$_pol/cpuinfo_max_freq" 2>/dev/null | tr -dc '0-9')
    if [ -n "$_hw_min" ] && [ -n "$_hw_max" ] && [ "$_hw_max" -gt "$_hw_min" ] 2>/dev/null; then
      _t_min=$(( _hw_min + ((_hw_max - _hw_min) * _min_pct / 100) ))
      _t_max=$(( _hw_min + ((_hw_max - _hw_min) * _max_pct / 100) ))
      safe_write_node "CPU_CUSTOM" "$_pol/scaling_max_freq" "$_t_max" "0644" "0"
      safe_write_node "CPU_CUSTOM" "$_pol/scaling_min_freq" "$_t_min" "0644" "0"
    fi
    if [ -f "$_pol/scaling_available_governors" ] && grep -qw "$_c_gov" "$_pol/scaling_available_governors" 2>/dev/null; then
      safe_write_node "CPU_CUSTOM" "$_pol/scaling_governor" "$_c_gov" "0644" "0"
    fi
  done
}
