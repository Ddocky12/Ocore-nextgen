#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.2.0-NextGen — Standalone Installer
# Target Priority: DEVICE SAFETY > STABILITY > COMPATIBILITY > FUNCTIONALITY
# Default Profile: BALANCED | Hardware-Aware Safe EEM & Thermal Policy
# ==============================================================================

SKIPUNZIP=0

ui_print "========================================================"
ui_print "        OCORE — UNIFIED ANDROID PERFORMANCE ENGINE      "
ui_print "                  Version v3.2.0-NextGen                "
ui_print "   Core • Gaming • Thermal • Energy • Spoof • Recovery  "
ui_print "========================================================"

# 1. Detect Environment, Root Manager & Architecture
API_LEVEL="$(getprop ro.build.version.sdk)"
ANDROID_REL="$(getprop ro.build.version.release)"
PLATFORM="$(getprop ro.board.platform)"
HARDWARE="$(getprop ro.hardware)"
SOC_MODEL="$(getprop ro.soc.model)"
SOC_MFG="$(getprop ro.soc.manufacturer)"
DEVICE="$(getprop ro.product.device)"
MODEL="$(getprop ro.product.model)"
BRAND="$(getprop ro.product.brand)"
ARCH="$(getprop ro.product.cpu.abi)"
KVER="$(uname -r 2>/dev/null)"

ROOT_ENV="Magisk"
if [ "$KSU" = "true" ] || [ -d "/data/adb/ksu" ]; then
  if [ -n "$KSU_NEXT" ] || grep -qi "next" /data/adb/ksu/bin/ksud 2>/dev/null; then
    ROOT_ENV="KernelSU Next"
  else
    ROOT_ENV="KernelSU"
  fi
elif [ "$APATCH" = "true" ] || [ -d "/data/adb/ap" ]; then
  ROOT_ENV="APatch"
fi

ui_print "- Root Manager : $ROOT_ENV"
ui_print "- Device       : $BRAND $MODEL ($DEVICE)"
ui_print "- Architecture : ${ARCH:-arm64-v8a} | Android $ANDROID_REL (API $API_LEVEL)"
ui_print "- SoC / Kernel : $PLATFORM / $HARDWARE ($SOC_MODEL) | $KVER"
ui_print "- Default Mode : BALANCED (Hardware-Aware Safe Mode)"

case "$ARCH" in
  *arm64*|*aarch64*)
    ui_print "- Architecture Check: 64-bit ARM64 verified."
    ;;
  *armeabi*|*armv7*)
    ui_print "- Architecture Check: 32-bit ARMv7 detected. Installing 32-bit compatible binaries."
    if [ -d "$MODPATH/libs/armeabi-v7a" ]; then
      cp -f "$MODPATH/libs/armeabi-v7a/"* "$MODPATH/system/bin/" 2>/dev/null
    fi
    ;;
  *)
    ui_print "! Warning: Uncommon architecture ($ARCH). Using SAFE GENERIC MODE."
    ;;
esac

# 2. Non-Destructive Conflict Detection (Never auto-delete user modules!)
CONFLICTS_FOUND=""
for old_mod in RaiRin-AI AZenith ThermodMT6877 battmontester laya_kerneltuner mtkvoltoptimizer; do
  if [ -d "/data/adb/modules/$old_mod" ] && [ ! -f "/data/adb/modules/$old_mod/remove" ] && [ ! -f "/data/adb/modules/$old_mod/disable" ]; then
    CONFLICTS_FOUND="$CONFLICTS_FOUND $old_mod"
  fi
done

if [ -n "$CONFLICTS_FOUND" ]; then
  ui_print "--------------------------------------------------------"
  ui_print "! WARNING: Potentially conflicting legacy modules found:"
  for cm in $CONFLICTS_FOUND; do
    ui_print "  * /data/adb/modules/$cm"
  done
  ui_print "! OCORE will NOT delete your existing modules automatically."
  ui_print "! Please disable or remove them in your Root Manager to"
  ui_print "! avoid duplicate daemon or thermal node contention."
  ui_print "--------------------------------------------------------"
fi

# 3. Stop Any Running Previous-Instance Ocore Daemons on Hot-Upgrade (PID + cmdline verified)
for proc in ocore-daemon ocore-game ocore-bypass ocore-bat ocore-game-daemon ocore-fps-daemon ocore.battmon-service ocore.ktuner-service sys.ocore-thermalcore; do
  for p in $(/system/bin/toybox pidof "$proc" 2>/dev/null) $(/system/bin/toybox pgrep -f "$proc" 2>/dev/null); do
    [ "$p" != "$$" ] && [ -d "/proc/$p" ] && kill -TERM "$p" 2>/dev/null
  done
done

# 4. Setup Internal State, Config, Runtime & Compatibility Directories
if [ -e "/data/adb/modules/Ocore" ] && [ ! -d "/data/adb/modules/Ocore" ]; then
  ui_print "- Removing stray file at /data/adb/modules/Ocore..."
  rm -f "/data/adb/modules/Ocore" 2>/dev/null
fi
mkdir -p "/data/adb/modules/Ocore" 2>/dev/null

OCORE_DIR="/data/adb/ocore"
THERMOD_DIR="/data/adb/thermod_mt6877"
AZ_CONF="/data/adb/.config/ocore"
RR_TMP="/data/local/tmp/ocore"

mkdir -p "$OCORE_DIR/config" "$OCORE_DIR/runtime" "$OCORE_DIR/hw" "$OCORE_DIR/logs" "$OCORE_DIR/backups" "$OCORE_DIR/state/locks" "$OCORE_DIR/state/per_game" "$OCORE_DIR/state/spoof_bindings" "$OCORE_DIR/API" 2>/dev/null
mkdir -p "$MODPATH/backup" "$MODPATH/state" "/data/local/tmp/ocore/backup" "/data/local/tmp/ocore/state" 2>/dev/null
mkdir -p "/data/data/zx.ocore/API" 2>/dev/null
mkdir -p "$THERMOD_DIR/backup" "$THERMOD_DIR/logs" 2>/dev/null
mkdir -p "$AZ_CONF/debug" "$AZ_CONF/API" "$AZ_CONF/preload" "$AZ_CONF/bypasschgconfig" "$AZ_CONF/gamelist" 2>/dev/null
mkdir -p "$RR_TMP/render" "/data/local/tmp/thunder_default" 2>/dev/null

rm -f "$OCORE_DIR/state/crash_"* "$OCORE_DIR/state/cooldown_"* "$MODPATH"/ocoin_*.log "$MODPATH"/rairin_*.log 2>/dev/null
echo "${CONFLICTS_FOUND# }" > "$OCORE_DIR/state/detected_conflicts.txt" 2>/dev/null

# 5. Backup Stock MediaTek /vendor/etc/.tp Thermal Configs (Only once, never overwrite stock backup)
if [ -d "/vendor/etc/.tp" ] && [ ! -f "$THERMOD_DIR/backup/.backed_up" ]; then
  ui_print "- Backing up stock /vendor/etc/.tp thermal configs..."
  cp -af /vendor/etc/.tp/* "$THERMOD_DIR/backup/" 2>/dev/null
  cp -af /vendor/etc/.tp/.* "$THERMOD_DIR/backup/" 2>/dev/null
  if [ -f "$THERMOD_DIR/backup/thermal.conf" ] && [ -s "$THERMOD_DIR/backup/thermal.conf" ]; then
    touch "$THERMOD_DIR/backup/.backed_up"
    cp -af "$THERMOD_DIR/backup" "$OCORE_DIR/backups/vendor_tp_stock" 2>/dev/null
  fi
fi

# 6. Stage Thermal Profile into Module Overlay (Uses stock backup by default when ALLOW_TRIP_POINT_MOD=0)
if [ ! -f "$THERMOD_DIR/config.conf" ]; then
  cat << 'EOF' > "$THERMOD_DIR/config.conf"
# Ocore Thermal Configuration v3.0
PROFILE=balanced
THERMAL_MODE=ocore_intel
SMART_GUARD=1
FPSGO_UNLOCK=1
GED_BOOST=1
SYNC_MTC_PROFILES=1
ALLOW_TRIP_POINT_MOD=0
EOF
fi

if [ -f "$THERMOD_DIR/backup/.backed_up" ] && [ -f "$THERMOD_DIR/backup/thermal.conf" ]; then
  cp -af "$THERMOD_DIR/backup/"* "$MODPATH/system/vendor/etc/.tp/" 2>/dev/null
else
  cp -f "$MODPATH/profiles/balanced.conf" "$MODPATH/system/vendor/etc/.tp/thermal.conf" 2>/dev/null
fi

# 7. Initialize / Migrate Unified Configuration
if [ ! -f "$AZ_CONF/gamelist/ocoreApplist.json" ] && [ -f "$MODPATH/ocoreApplist.json" ]; then
  cp -f "$MODPATH/ocoreApplist.json" "$AZ_CONF/gamelist/ocoreApplist.json"
fi
[ ! -f "$AZ_CONF/API/current_modes" ] && echo 1 > "$AZ_CONF/API/current_modes"
[ ! -f "$AZ_CONF/API/current_profile" ] && echo 2 > "$AZ_CONF/API/current_profile"
[ ! -f "/data/data/zx.ocore/API/current_profile" ] && echo 2 > "/data/data/zx.ocore/API/current_profile" 2>/dev/null
[ ! -f "/data/data/zx.ocore/API/gameinfo" ] && : > "/data/data/zx.ocore/API/gameinfo" 2>/dev/null
[ ! -f "$AZ_CONF/freqoffset" ] && echo "Disabled" > "$AZ_CONF/freqoffset"
[ ! -f "$AZ_CONF/bypasschgconfig/bypasspath" ] && echo "NEED_SETUP" > "$AZ_CONF/bypasschgconfig/bypasspath"
[ ! -f "$AZ_CONF/bypasschgconfig/bypasschgthreshold" ] && echo "20" > "$AZ_CONF/bypasschgconfig/bypasschgthreshold"
[ ! -f "$AZ_CONF/bypasschgconfig/bypasschg" ] && echo "0" > "$AZ_CONF/bypasschgconfig/bypasschg"

# Detect SoC Family (Section 4 Compliance: Default to 0 = SAFE GENERIC MODE if unrecognized!)
case "$(echo "$PLATFORM $HARDWARE $SOC_MODEL $SOC_MFG" | tr '[:upper:]' '[:lower:]')" in
  *mt*|*dimensity*|*helio*|*mediatek*) SOC_ID=1 ;;
  *sm*|*qcom*|*snapdragon*|*sdm*|*qualcomm*) SOC_ID=2 ;;
  *exynos*|*s5e*|*universal*|*samsung*) SOC_ID=3 ;;
  *unisoc*|*ums*|*spreadtrum*) SOC_ID=4 ;;
  *gs*|*tensor*|*google*) SOC_ID=5 ;;
  *) SOC_ID=0 ;;
esac
setprop persist.sys.ocore__.soctype "$SOC_ID" 2>/dev/null
echo "$SOC_ID" > "/data/local/tmp/thunder_default/soc" 2>/dev/null

# Generate accurate /proc/cpuinfo simulation template from actual host /proc/cpuinfo
if [ -f "/proc/cpuinfo" ] && grep -q "processor" /proc/cpuinfo 2>/dev/null; then
  cp -f /proc/cpuinfo "$MODPATH/cortex/OCORE_spoof" 2>/dev/null
fi

# 8. Stage Render Binaries & Icons (Preserve source copy in $MODPATH/render!)
cp -rf "$MODPATH/render/." "$RR_TMP/render/" 2>/dev/null
echo "default" > "$RR_TMP/render/status.txt" 2>/dev/null
echo "default" > "$MODPATH/render/status.txt" 2>/dev/null
chmod -R 0755 "$RR_TMP/render" 2>/dev/null
[ ! -e "/data/local/tmp/RaiRin-AI" ] && ln -sf "$RR_TMP" "/data/local/tmp/RaiRin-AI" 2>/dev/null

if [ -f "$MODPATH/webroot/assets/ocore.webp" ]; then
  cp -f "$MODPATH/webroot/assets/ocore.webp" /data/local/tmp/ocore.webp 2>/dev/null
  chmod 0644 /data/local/tmp/ocore.webp 2>/dev/null
fi
[ -f "$MODPATH/webroot/assets/spicy.webp" ] && cp -f "$MODPATH/webroot/assets/spicy.webp" /data/local/tmp/spicy.webp 2>/dev/null

# 9. Set Strict File Permissions & SELinux Contexts
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/engine" 0 0 0755 0755
set_perm_recursive "$MODPATH/cortex" 0 0 0755 0755
chmod 0644 "$MODPATH/cortex/OCORE.json" "$MODPATH/cortex/OCORE_spoof" 2>/dev/null
set_perm_recursive "$MODPATH/render" 0 0 0755 0755
[ -d "$MODPATH/libs" ] && set_perm_recursive "$MODPATH/libs" 0 0 0755 0755
set_perm_recursive "$MODPATH/system/vendor/etc/.tp" 0 0 0755 0644 u:object_r:vendor_configs_file:s0
for sh_file in "$MODPATH"/*.sh; do
  [ -f "$sh_file" ] && set_perm "$sh_file" 0 0 0755
done

# 10. Symlink CLI Tools & Daemons in KernelSU / APatch PATH if available (Dynamic Target Path)
FINAL_MOD_DIR="/data/adb/modules/$(grep '^id=' "$MODPATH/module.prop" 2>/dev/null | cut -d= -f2 || echo Ocore)"
for dir in /data/adb/ap/bin /data/adb/ksu/bin; do
  if [ -d "$dir" ]; then
    ln -sf "$FINAL_MOD_DIR/system/bin/ocorectl" "$dir/ocorectl"
    ln -sf "$FINAL_MOD_DIR/system/bin/thermod" "$dir/thermod"
    ln -sf "$FINAL_MOD_DIR/system/bin/ocore-game-daemon" "$dir/ocore-game-daemon"
    ln -sf "$FINAL_MOD_DIR/system/bin/ocore-fps-daemon" "$dir/ocore-fps-daemon"
    for azb in sys.ocore-service sys.ocore-profilesettings sys.ocore-utilityconf sys.ocore-preferencedtweaks sys.ocore-preloadbin sys.ocore-thermalcore; do
      ln -sf "$FINAL_MOD_DIR/system/bin/$azb" "$dir/$azb"
    done
  fi
done

# 11. Sync Active Module Directory for Immediate CLI Access & Initialize Config
if [ ! -d "/data/adb/modules/Ocore" ]; then
  rm -rf "/data/adb/modules/Ocore" 2>/dev/null
  mkdir -p "/data/adb/modules/Ocore" 2>/dev/null
fi
if [ "$MODPATH" != "/data/adb/modules/Ocore" ]; then
  cp -rf "$MODPATH/." "/data/adb/modules/Ocore/" 2>/dev/null
  chmod -R 0755 "/data/adb/modules/Ocore/system/bin" "/data/adb/modules/Ocore/engine" "/data/adb/modules/Ocore/cortex" 2>/dev/null
  chmod 0755 "/data/adb/modules/Ocore/"*.sh 2>/dev/null
fi

if [ -f "/data/adb/modules/Ocore/system/bin/ocorectl" ]; then
  ui_print "- Initializing & validating /data/adb/ocore/config.conf (v3.0.0)..."
  MODDIR_OVERRIDE="/data/adb/modules/Ocore" sh "/data/adb/modules/Ocore/system/bin/ocorectl" config_migrate >/dev/null 2>&1
  if [ "$BOOTMODE" = "true" ]; then
    ui_print "- Running hardware capability scanner..."
    MODDIR_OVERRIDE="/data/adb/modules/Ocore" sh "/data/adb/modules/Ocore/system/bin/ocorectl" hw_scan >/dev/null 2>&1
  fi
fi

ui_print ""
ui_print "- Ocore Unified Performance Engine v3.2.0-NextGen Installed!"
ui_print "- Config Path : /data/adb/ocore/config.conf"
ui_print "========================================================"
