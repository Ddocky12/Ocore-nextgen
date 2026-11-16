#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Renderer State Recorder
# Synchronizes renderer properties without killing active foreground applications.
# ==============================================================================

MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}"
OCORE_DIR="/data/adb/ocore"
STATE_DIR="$OCORE_DIR/state"
RENDER_DIR="/data/local/tmp/ocore/render"
STATUS_FILE="$RENDER_DIR/status.txt"

log_msg() {
  log -t "Ocore-RenderRec" "$1" 2>/dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [RENDER_REC] $1" >> "$OCORE_DIR/logs/ocore_events.log" 2>/dev/null
}

MODE=""
[ -f "$STATE_DIR/renderer_state.txt" ] && MODE=$(tr -d '[:space:]' < "$STATE_DIR/renderer_state.txt" 2>/dev/null)
[ -z "$MODE" ] && [ -f "$STATUS_FILE" ] && MODE=$(tr -d '[:space:]' < "$STATUS_FILE" 2>/dev/null)
[ -z "$MODE" ] && MODE="default"

mkdir -p "$RENDER_DIR" "$STATE_DIR" 2>/dev/null
echo "$MODE" > "$STATUS_FILE" 2>/dev/null
echo "$MODE" > "$STATE_DIR/renderer_state.txt" 2>/dev/null
echo "$MODE" > "$MODDIR/render/status.txt" 2>/dev/null

set_rprop() {
  resetprop -n "$1" "$2" 2>/dev/null || setprop "$1" "$2" 2>/dev/null
}

case "$MODE" in
  skia|skiagl)
    log_msg "Applying SkiaGL renderer pipeline ($MODE)..."
    set_rprop debug.hwui.renderer skiagl
    set_rprop debug.renderengine.backend skiaglthreaded
    set_rprop vendor.debug.renderengine.backend skiaglthreaded
    set_rprop persist.sys.gpu_rendering skiagl
    set_rprop renderthread.skia.reduceopstasksplitting true
    ;;
  vk|vulkan|skiavk)
    log_msg "Applying SkiaVK/Vulkan renderer pipeline ($MODE)..."
    set_rprop debug.hwui.renderer skiavk
    set_rprop debug.renderengine.backend skiavk
    set_rprop vendor.debug.renderengine.backend skiavk
    set_rprop persist.sys.gpu_rendering skiavk
    set_rprop ro.hwui.use_vulkan true
    set_rprop renderthread.skia.reduceopstasksplitting true
    set_rprop debug.hwui.use_buffer_age true
    ;;
  hybrid)
    log_msg "Applying Hybrid renderer pipeline (App: SkiaVK / SurfaceFlinger: SkiaGLThreaded)..."
    set_rprop debug.hwui.renderer skiavk
    set_rprop persist.sys.gpu_rendering skiavk
    set_rprop debug.renderengine.backend skiaglthreaded
    set_rprop vendor.debug.renderengine.backend skiaglthreaded
    set_rprop ro.hwui.use_vulkan true
    set_rprop renderthread.skia.reduceopstasksplitting true
    ;;
  default|*)
    log_msg "Renderer set to default system pipeline (skiaglthreaded)."
    set_rprop debug.hwui.renderer skiagl
    set_rprop debug.renderengine.backend skiaglthreaded
    set_rprop vendor.debug.renderengine.backend skiaglthreaded
    ;;
esac

exit 0
