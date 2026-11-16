#!/system/bin/sh
# ==============================================================================
# Ocore Safe Cache Cleaner (cortex/cache/clear.sh)
# Cleans non-essential app cache directories while respecting Ocore whitelist
# ==============================================================================

MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="/data/adb/modules/Ocore"
WHITELIST="$MODDIR/cortex/thunderclash/whitelist.txt"

# Trim package manager caches safely via Android framework if available
pm trim-caches 4G >/dev/null 2>&1

# Safe cache directory sweep (respects whitelist.txt)
for base in /data/data /data/media/0/Android/data; do
  [ -d "$base" ] || continue
  for pkg_dir in "$base"/*; do
    [ -d "$pkg_dir" ] || continue
    pkg="${pkg_dir##*/}"
    if [ -f "$WHITELIST" ] && grep -qx "$pkg" "$WHITELIST" 2>/dev/null; then
      continue
    fi
    rm -rf "$pkg_dir/cache/"* "$pkg_dir/code_cache/"* 2>/dev/null
  done
done

exit 0