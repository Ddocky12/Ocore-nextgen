#!/system/bin/sh
# ==============================================================================
# Ocore Touch & SurfaceFlinger Input Responsiveness Optimizer (touch.sh v2.1)
# Fixes bug where Level 5 forced debug.hwui.renderer=opengl and overwrote
# user's selected RENDER_MODE (skiavk/skiagl/hybrid).
# ==============================================================================

LEVEL="${1:-2}"

set_prop() {
  resetprop -n "$1" "$2" 2>/dev/null || setprop "$1" "$2" 2>/dev/null
}

case "$LEVEL" in
  0)
    # --- LEVEL 0: DEFAULT / STOCK ---
    set_prop ro.surface_flinger.set_idle_timer_ms 1000
    set_prop ro.surface_flinger.set_touch_timer_ms 200
    set_prop ro.surface_flinger.set_display_power_timer_ms 1000
    set_prop ro.surface_flinger.use_content_detection_for_refresh_rate true
    set_prop ro.surface_flinger.force_hwc_copy_for_virtual_displays false
    set_prop ro.surface_flinger.enable_present_time_offset false
    set_prop touch.pressure.scale 0.001
    set_prop touch.size.scale 1
    ;;
  1)
    # --- LEVEL 1: LOW INTENSITY ---
    set_prop ro.surface_flinger.set_idle_timer_ms 800
    set_prop ro.surface_flinger.set_touch_timer_ms 500
    set_prop ro.surface_flinger.enable_present_time_offset true
    ;;
  2)
    # --- LEVEL 2: MEDIUM INTENSITY (BALANCED DEFAULT) ---
    set_prop ro.surface_flinger.set_idle_timer_ms 500
    set_prop ro.surface_flinger.set_touch_timer_ms 1000
    set_prop ro.surface_flinger.set_display_power_timer_ms 500
    ;;
  3)
    # --- LEVEL 3: HIGH INTENSITY ---
    set_prop ro.surface_flinger.set_idle_timer_ms 250
    set_prop ro.surface_flinger.set_touch_timer_ms 3000
    set_prop ro.surface_flinger.use_content_detection_for_refresh_rate false
    ;;
  4)
    # --- LEVEL 4: VERY HIGH ---
    set_prop ro.surface_flinger.set_idle_timer_ms 100
    set_prop ro.surface_flinger.set_touch_timer_ms 8000
    set_prop ro.surface_flinger.force_hwc_copy_for_virtual_displays true
    ;;
  5)
    # --- LEVEL 5: ESPORT / MAX RESPONSIVENESS ---
    # Preserves active RENDER_MODE (does NOT override debug.hwui.renderer!)
    set_prop ro.surface_flinger.set_idle_timer_ms 0
    set_prop ro.surface_flinger.set_touch_timer_ms 999999
    set_prop ro.surface_flinger.set_display_power_timer_ms 0
    set_prop ro.surface_flinger.use_content_detection_for_refresh_rate false
    set_prop ro.surface_flinger.force_hwc_copy_for_virtual_displays true
    set_prop ro.surface_flinger.enable_present_time_offset true
    ;;
esac

if [ "$LEVEL" -ge 3 ] 2>/dev/null; then
  set_prop debug.hwui.profile false
  set_prop debug.performance.tuning 1
fi

exit 0
