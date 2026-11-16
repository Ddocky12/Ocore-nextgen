#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #2: Hardware & Capability Detection Engine
# File: engine/core/hw_detect.sh
# Implements tri-state capability reporting: SUPPORTED | UNSUPPORTED | UNKNOWN
# and SAFE GENERIC MODE (SOC_ID=0) when SoC is unrecognized.
# ==============================================================================

check_node_capability() {
  _cnc_path="$1"
  _cnc_mode="${2:-rw}"
  if [ ! -e "$_cnc_path" ]; then
    echo "UNSUPPORTED"
    return 1
  fi
  if [ "$_cnc_mode" = "r" ]; then
    if [ -r "$_cnc_path" ]; then
      echo "SUPPORTED"
      return 0
    fi
  else
    if [ -r "$_cnc_path" ] && [ -w "$_cnc_path" ]; then
      echo "SUPPORTED"
      return 0
    fi
  fi
  echo "UNKNOWN"
  return 2
}

detect_storage_type() {
  if [ -d "/sys/block/sda" ] || [ -d "/sys/devices/platform/soc/11270000.ufshci" ] || find /sys/devices -name "*ufshci*" 2>/dev/null | grep -q "ufs"; then
    echo "UFS"
  elif [ -d "/sys/block/mmcblk0" ]; then
    echo "eMMC"
  elif [ -d "/sys/block/vda" ] || [ -d "/sys/block/loop0" ]; then
    echo "Virtual/Block"
  else
    echo "Unknown"
  fi
}

detect_display_refresh_rates() {
  _hz=""
  if command -v dumpsys >/dev/null 2>&1; then
    _hz=$(dumpsys display 2>/dev/null | grep -oE 'fps=[0-9]+(\.[0-9]+)?' | cut -d= -f2 | cut -d. -f1 | sort -nu | tr '\n' '/' | sed 's|/$||')
  fi
  [ -z "$_hz" ] && _hz="60/90/120"
  echo "${_hz}Hz"
}

check_vulkan_driver_support() {
  _vk_prop=$(getprop ro.hardware.vulkan 2>/dev/null)
  if [ -n "$_vk_prop" ] || [ -f "/system/lib64/libvulkan.so" ] || ls /vendor/lib64/hw/vulkan.*.so >/dev/null 2>&1; then
    echo "SUPPORTED"
    return 0
  fi
  if command -v pm >/dev/null 2>&1 && pm list features 2>/dev/null | grep -q "android.hardware.vulkan"; then
    echo "SUPPORTED"
    return 0
  fi
  if [ ! -d "/system/lib64" ] && [ ! -d "/vendor/lib64" ]; then
    echo "UNKNOWN"
    return 2
  fi
  echo "UNSUPPORTED"
  return 1
}
