#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #11: Renderer Engine
# File: engine/core/renderer_engine.sh
# Synchronizes renderer status across WebUI, gate.sh, break.sh, and backend.
# ==============================================================================

apply_renderer_pipeline() {
  _arp_mode=$(sanitize_token "${1:-default}")
  _arp_vk_cap=$(check_vulkan_driver_support)

  case "$_arp_mode" in
    skiavk|vulkan|vk)
      if [ "$_arp_vk_cap" = "UNSUPPORTED" ]; then
        log_event "WARN" "RENDERER" "Vulkan driver unsupported; falling back to default pipeline"
        record_structured_error "ERR_REN_001" "WARN" "RENDERER" "Vulkan renderer requested on unsupported hardware" "Missing Vulkan HAL driver" "Fallback to default renderer"
        _arp_mode="default"
      else
        _arp_mode="skiavk"
      fi
      ;;
    skiagl|skia)
      _arp_mode="skiagl"
      ;;
    hybrid)
      if [ "$_arp_vk_cap" = "UNSUPPORTED" ]; then
        _arp_mode="skiagl"
      fi
      ;;
    default|*)
      _arp_mode="default"
      ;;
  esac

  save_ocore_key "RENDER_MODE" "$_arp_mode"
  setprop persist.sys.ocore__conf.renderer "$_arp_mode" 2>/dev/null
  mkdir -p "$RR_TMP_DIR/render" "$STATE_DIR" 2>/dev/null
  echo "$_arp_mode" > "$RR_TMP_DIR/render/status.txt" 2>/dev/null
  echo "$_arp_mode" > "$MODDIR/render/status.txt" 2>/dev/null
  echo "$_arp_mode" > "$STATE_DIR/renderer_state.txt" 2>/dev/null

  if [ -x "$MODDIR/system/bin/sys.ocore-utilityconf" ]; then
    "$MODDIR/system/bin/sys.ocore-utilityconf" setrender "$_arp_mode" >>"$DAEMON_LOG" 2>&1 &
  fi
  sh "$MODDIR/break.sh" >>"$DAEMON_LOG" 2>&1 &
  log_tx "APPLIED" "renderer" "Renderer=$_arp_mode (VulkanCap=$_arp_vk_cap)"
  echo "[OK] Graphics Renderer set to: $_arp_mode (Vulkan Support: $_arp_vk_cap)"
}
