#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem C: Smart Resource Manager
# Reduces non-essential background CPU/IO contention during verified gaming
# sessions without killing critical system services or user communication apps,
# and restores all parameters when the game session ends.
# ==============================================================================

apply_smart_gaming_resources() {
  mkdir -p "$STATE_DIR" 2>/dev/null
  _srm_snap="$STATE_DIR/smart_resource_baseline.env"
  if [ ! -f "$_srm_snap" ]; then
    _orig_vfs=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null | tr -dc '0-9')
    _orig_bg_cpus=$(cat /dev/cpuset/background/cpus 2>/dev/null | tr -d '\r\n ')
    _orig_sbg_cpus=$(cat /dev/cpuset/system-background/cpus 2>/dev/null | tr -d '\r\n ')
    cat << EOS > "$_srm_snap"
SRM_ORIG_VFS=${_orig_vfs:-100}
SRM_ORIG_BG_CPUS=${_orig_bg_cpus:-0-3}
SRM_ORIG_SBG_CPUS=${_orig_sbg_cpus:-0-3}
EOS
  fi

  # Restrict background cpuset to little cluster (0-5 or policy0 related_cpus)
  _little_mask="0-3"
  if [ -f "/sys/devices/system/cpu/cpufreq/policy0/related_cpus" ]; then
    _c_first=$(awk '{print $1}' /sys/devices/system/cpu/cpufreq/policy0/related_cpus 2>/dev/null)
    _c_last=$(awk '{print $NF}' /sys/devices/system/cpu/cpufreq/policy0/related_cpus 2>/dev/null)
    [ -n "$_c_first" ] && [ -n "$_c_last" ] && _little_mask="${_c_first}-${_c_last}"
  fi
  [ -w "/dev/cpuset/background/cpus" ] && echo "$_little_mask" > /dev/cpuset/background/cpus 2>/dev/null
  [ -w "/proc/sys/vm/vfs_cache_pressure" ] && echo "80" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
  echo "ACTIVE" > "$STATE_DIR/smart_resource_state" 2>/dev/null
}

restore_smart_gaming_resources() {
  _srm_snap="$STATE_DIR/smart_resource_baseline.env"
  if [ -f "$_srm_snap" ]; then
    . "$_srm_snap" 2>/dev/null
    [ -n "$SRM_ORIG_VFS" ] && [ -w "/proc/sys/vm/vfs_cache_pressure" ] && echo "$SRM_ORIG_VFS" > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    [ -n "$SRM_ORIG_BG_CPUS" ] && [ -w "/dev/cpuset/background/cpus" ] && echo "$SRM_ORIG_BG_CPUS" > /dev/cpuset/background/cpus 2>/dev/null
    [ -n "$SRM_ORIG_SBG_CPUS" ] && [ -w "/dev/cpuset/system-background/cpus" ] && echo "$SRM_ORIG_SBG_CPUS" > /dev/cpuset/system-background/cpus 2>/dev/null
    rm -f "$_srm_snap" 2>/dev/null
  fi
  echo "IDLE" > "$STATE_DIR/smart_resource_state" 2>/dev/null
}
