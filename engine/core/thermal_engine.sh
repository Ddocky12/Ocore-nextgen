#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #6: Adaptive Multi-Domain Thermal Intelligence
# Modes supported (Section 8 Compliance):
#   - oem_stock     : OEM Thermal (Stock vendor thermal config & services)
#   - ocore_intel   : Ocore Thermal Intelligence (Multi-domain hysteresis/stepdown)
#   - monitor_only  : Thermal Monitoring Only (Zero kernel/cooler writes)
#   - restore_stock : Restore Stock Thermal immediately
# ==============================================================================
thermal_subsys_info() {
  echo "SUBSYSTEM=THERMAL|VERSION=3.0.0|STAGES=NORMAL,WARM,HOT,CRITICAL|OEM_SAFE=1"
}
