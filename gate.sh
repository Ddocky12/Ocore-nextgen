#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Renderer Gate Dispatcher
# Invoked on game entry to apply per-package or global graphics renderer safely
# without force-stopping the user's running game!
# ==============================================================================

MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}"
OCORE_DIR="/data/adb/ocore"
OCORE_CONF="$OCORE_DIR/config.conf"
STATE_DIR="$OCORE_DIR/state"
RENDER_DIR="/data/local/tmp/ocore/render"
FILE_ACTIVE="$MODDIR/cortex/thunderclash/game-active.txt"
RENDER_STATE="$MODDIR/cortex/thunderclash/renderstate.txt"

FILE_SKIA="$RENDER_DIR/skia.txt"
FILE_VULKAN="$RENDER_DIR/vulkan.txt"
FILE_HYBRID="$RENDER_DIR/hybrid.txt"

log_msg() {
  log -t "Ocore-RenderGate" "$1" 2>/dev/null
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [RENDER_GATE] $1" >> "$OCORE_DIR/logs/ocore_events.log" 2>/dev/null
}

echo "1" > "$RENDER_STATE" 2>/dev/null

PKG=""
[ -f "$STATE_DIR/active_game_pkg" ] && PKG=$(tr -d '[:space:]' < "$STATE_DIR/active_game_pkg" 2>/dev/null)
[ -z "$PKG" ] && [ -f "$FILE_ACTIVE" ] && PKG=$(tr -d '[:space:]' < "$FILE_ACTIVE" 2>/dev/null)

if [ -z "$PKG" ]; then
  echo "0" > "$RENDER_STATE" 2>/dev/null
  exit 0
fi

TARGET_REN=""
# 1. Check persistent per-game configuration first ($STATE_DIR/per_game/<pkg>.conf)
if [ -f "$STATE_DIR/per_game/${PKG}.conf" ]; then
  TARGET_REN=$(grep "^GAME_RENDERER=" "$STATE_DIR/per_game/${PKG}.conf" 2>/dev/null | tail -n 1 | cut -d= -f2)
fi

# 2. Check per-renderer list files if TARGET_REN is still empty or default
if [ -z "$TARGET_REN" ] || [ "$TARGET_REN" = "default" ]; then
  if [ -f "$FILE_SKIA" ] && grep -qx "$PKG" "$FILE_SKIA" 2>/dev/null; then
    TARGET_REN="skiagl"
  elif [ -f "$FILE_VULKAN" ] && grep -qx "$PKG" "$FILE_VULKAN" 2>/dev/null; then
    TARGET_REN="skiavk"
  elif [ -f "$FILE_HYBRID" ] && grep -qx "$PKG" "$FILE_HYBRID" 2>/dev/null; then
    TARGET_REN="hybrid"
  fi
fi

# 3. Fallback to Global RENDER_MODE
if [ -z "$TARGET_REN" ] || [ "$TARGET_REN" = "default" ]; then
  [ -f "$OCORE_CONF" ] && TARGET_REN=$(grep "^RENDER_MODE=" "$OCORE_CONF" 2>/dev/null | tail -n 1 | cut -d= -f2)
fi
[ -z "$TARGET_REN" ] && TARGET_REN="default"

log_msg "Applying renderer '$TARGET_REN' for active game: $PKG"
mkdir -p "$RENDER_DIR" "$STATE_DIR" 2>/dev/null
echo "$TARGET_REN" > "$RENDER_DIR/status.txt" 2>/dev/null
echo "$TARGET_REN" > "$STATE_DIR/renderer_state.txt" 2>/dev/null
echo "$TARGET_REN" > "$MODDIR/render/status.txt" 2>/dev/null

sh "$MODDIR/break.sh" >/dev/null 2>&1
echo "0" > "$RENDER_STATE" 2>/dev/null
exit 0
