#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #9: Per-Application Device Profile Engine
# Delegates JSON & binding operations to cortex/ocore_json_tool.sh
# ==============================================================================
device_profile_subsys_info() {
  echo "SUBSYSTEM=DEVICE_PROFILE|VERSION=3.0.0|PARSER=ocore_json_tool"
}

apply_package_spoof_runtime() {
  MODDIR_OVERRIDE="$MODDIR" OCORE_DIR_OVERRIDE="$OCORE_DIR" sh "$MODDIR/cortex/ocore_json_tool.sh" apply_pkg "$1"
}
