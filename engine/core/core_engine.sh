#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #1: Core Engine & Atomic State/Config Manager
# File: engine/core/core_engine.sh
# ==============================================================================

OCORE_ENGINE_VERSION="v3.2.0-NextGen"
OCORE_VERSION_CODE="3200"

acquire_core_lock() {
  _acl_name="${1:-config}"
  _acl_dir="$STATE_DIR/locks/${_acl_name}.lock"
  mkdir -p "$STATE_DIR/locks" 2>/dev/null
  _acl_try=0
  while ! mkdir "$_acl_dir" 2>/dev/null; do
    if [ -f "$_acl_dir/pid" ]; then
      _holder=$(cat "$_acl_dir/pid" 2>/dev/null | tr -dc '0-9')
      if [ -n "$_holder" ] && [ ! -d "/proc/$_holder" ]; then
        rm -rf "$_acl_dir" 2>/dev/null
        continue
      fi
    fi
    _acl_try=$((_acl_try + 1))
    [ "$_acl_try" -ge 25 ] && rm -rf "$_acl_dir" 2>/dev/null && mkdir "$_acl_dir" 2>/dev/null && break
    sleep 0.1 2>/dev/null || sleep 1
  done
  echo "$$" > "$_acl_dir/pid" 2>/dev/null
}

release_core_lock() {
  _rcl_name="${1:-config}"
  rm -rf "$STATE_DIR/locks/${_rcl_name}.lock" 2>/dev/null
}

record_structured_error() {
  _rse_id="$1"
  _rse_sev="$2"
  _rse_comp="$3"
  _rse_desc="$4"
  _rse_cause="$5"
  _rse_rec="$6"
  _rse_ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$LOG_DIR" "$STATE_DIR" 2>/dev/null
  echo "${_rse_ts}|${_rse_id}|${_rse_sev}|${_rse_comp}|${_rse_desc}|${_rse_cause}|${_rse_rec}" >> "$LOG_DIR/structured_errors.log" 2>/dev/null
}
