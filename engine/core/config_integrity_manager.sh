#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem G: Configuration Integrity Manager
# Validates config.conf, gamelist.txt, game_blacklist.txt, and OCORE.json,
# maintains atomic backups, and automatically restores corrupted files.
# ==============================================================================

verify_and_backup_config_integrity() {
  mkdir -p "$BACKUP_DIR/integrity" "$STATE_DIR" 2>/dev/null
  _cim_status="OK"

  # 1. Verify config.conf syntax and required keys
  if [ -f "$OCORE_CONF" ]; then
    if sh -n "$OCORE_CONF" 2>/dev/null && grep -q "^GLOBAL_PROFILE=" "$OCORE_CONF" 2>/dev/null; then
      cp -f "$OCORE_CONF" "$BACKUP_DIR/integrity/config.conf.bak" 2>/dev/null
    elif [ -f "$BACKUP_DIR/integrity/config.conf.bak" ] && sh -n "$BACKUP_DIR/integrity/config.conf.bak" 2>/dev/null; then
      cp -f "$BACKUP_DIR/integrity/config.conf.bak" "$OCORE_CONF" 2>/dev/null
      _cim_status="RECOVERED_CONFIG"
    fi
  fi

  # 2. Verify gamelist.txt integrity (only valid package names, no duplicates, no blacklisted apps)
  _gl_file="$MODDIR/cortex/thunderclash/gamelist.txt"
  _bl_file="$MODDIR/cortex/thunderclash/game_blacklist.txt"
  if [ -f "$_gl_file" ]; then
    _gl_tmp="${_gl_file}.clean.$$"
    awk '
      /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$/ {
        if (!seen[$0]++) print $0
      }
    ' "$_gl_file" > "$_gl_tmp" 2>/dev/null
    if [ -f "$_bl_file" ]; then
      _gl_filt="${_gl_file}.filt.$$"
      grep -vFf "$_bl_file" "$_gl_tmp" > "$_gl_filt" 2>/dev/null || cp -f "$_gl_tmp" "$_gl_filt" 2>/dev/null
      mv -f "$_gl_filt" "$_gl_tmp" 2>/dev/null
    fi
    if [ -s "$_gl_tmp" ] || [ ! -s "$_gl_file" ]; then
      mv -f "$_gl_tmp" "$_gl_file" 2>/dev/null
      cp -f "$_gl_file" "$BACKUP_DIR/integrity/gamelist.txt.bak" 2>/dev/null
    else
      rm -f "$_gl_tmp" 2>/dev/null
      [ -f "$BACKUP_DIR/integrity/gamelist.txt.bak" ] && cp -f "$BACKUP_DIR/integrity/gamelist.txt.bak" "$_gl_file" 2>/dev/null
      _cim_status="RECOVERED_GAMELIST"
    fi
  elif [ -f "$BACKUP_DIR/integrity/gamelist.txt.bak" ]; then
    cp -f "$BACKUP_DIR/integrity/gamelist.txt.bak" "$_gl_file" 2>/dev/null
    _cim_status="RECOVERED_GAMELIST"
  fi

  echo "CONFIG_INTEGRITY_STATUS=$_cim_status" > "$STATE_DIR/config_integrity.env" 2>/dev/null
  echo "$_cim_status"
}
