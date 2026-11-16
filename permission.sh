#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Runtime Asset & Permission Stager
# Preserves active renderer status.txt and maintains legacy symlink compatibility.
# ==============================================================================

MODULE_DIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODULE_DIR" ] && MODULE_DIR="${0%/*}"
ENGINE_DIR="$MODULE_DIR/engine"
SOURCE_RENDER="$MODULE_DIR/render"
TARGET_BASE="/data/local/tmp/ocore"
TARGET_RENDER="$TARGET_BASE/render"
TMP_ICON_OCORE="/data/local/tmp/ocore.webp"
TMP_ICON2="/data/local/tmp/spicy.webp"

mkdir -p "$TARGET_BASE" "$TARGET_RENDER" "/data/local/tmp/thunder_default" 2>/dev/null

# Preserve existing status.txt before staging render binaries
SAVED_REN_STATUS=""
[ -f "$TARGET_RENDER/status.txt" ] && SAVED_REN_STATUS=$(cat "$TARGET_RENDER/status.txt" 2>/dev/null)

if [ -d "$SOURCE_RENDER" ]; then
  for rf in "$SOURCE_RENDER"/*; do
    [ -e "$rf" ] || continue
    bname=$(basename "$rf")
    [ "$bname" = "status.txt" ] && [ -n "$SAVED_REN_STATUS" ] && continue
    cp -rf "$rf" "$TARGET_RENDER/$bname" 2>/dev/null
  done
fi

# Maintain symlink compatibility for any binary referencing /data/local/tmp/RaiRin-AI
if [ ! -e "/data/local/tmp/RaiRin-AI" ]; then
  ln -sf "$TARGET_BASE" "/data/local/tmp/RaiRin-AI" 2>/dev/null
fi

if [ -d "$TARGET_RENDER" ]; then
  chmod -R 0755 "$TARGET_RENDER" 2>/dev/null
fi

find "$ENGINE_DIR" -type f ! -name "*.txt" -exec chmod 0755 {} \; 2>/dev/null
find "$MODULE_DIR/system/bin" -type f -exec chmod 0755 {} \; 2>/dev/null
find "$MODULE_DIR/cortex" -type f ! -name "*.txt" ! -name "*.json" -exec chmod 0755 {} \; 2>/dev/null

if [ -f "$MODULE_DIR/webroot/assets/ocore.webp" ]; then
  cp -f "$MODULE_DIR/webroot/assets/ocore.webp" "$TMP_ICON_OCORE" 2>/dev/null
  chmod 0644 "$TMP_ICON_OCORE" 2>/dev/null
fi
if [ -f "$MODULE_DIR/webroot/assets/spicy.webp" ]; then
  cp -f "$MODULE_DIR/webroot/assets/spicy.webp" "$TMP_ICON2" 2>/dev/null
  chmod 0644 "$TMP_ICON2" 2>/dev/null
fi

exit 0
