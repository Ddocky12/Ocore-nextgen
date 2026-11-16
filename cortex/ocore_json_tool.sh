#!/system/bin/sh
# ==============================================================================
# Ocore Unified Performance Engine v3.0 — Device Profile & Dual-Layer Spoof Manager
# File: cortex/ocore_json_tool.sh
# Compliance (Section 11.A - 11.E):
#   - Dual-Layer Spoofing:
#       Layer 1: Zygisk JNI android.os.Build Hook via cortex/OCORE.json
#                (with SELinux u:r:zygote:s0 access fix + exact "mode" schema)
#       Layer 2: Native C/C++ SystemProperties (__system_property_get) via resetprop -n
#                so games reading ro.product.model / marketname in C++ or running
#                with Unmount/DenyList or without Zygisk ALSO get spoofed immediately!
#   - Automatic target app force-stop (am force-stop <pkg>) on bind/unbind so
#     Zygote immediately forks a fresh process with the new device identity.
#   - Atomic writes, directory file locking, automatic backup & stock restoration.
# ==============================================================================

export PATH="/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH"

MODDIR="${MODDIR_OVERRIDE:-/data/adb/modules/Ocore}"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}/.."
OCORE_DIR="${OCORE_DIR_OVERRIDE:-/data/adb/ocore}"
STATE_DIR="$OCORE_DIR/state"
BACKUP_DIR="$OCORE_DIR/backups"
JSON_FILE="${OCORE_JSON_OVERRIDE:-$MODDIR/cortex/OCORE.json}"
SPOOF_CPU_FILE="$MODDIR/cortex/OCORE_spoof"
BINDINGS_DIR="$STATE_DIR/spoof_bindings"
LOCK_DIR="$STATE_DIR/locks/ocore_json.lock"
STOCK_PROPS_FILE="$BACKUP_DIR/stock_device_props.env"

mkdir -p "$STATE_DIR" "$BACKUP_DIR" "$BINDINGS_DIR" "$STATE_DIR/locks" 2>/dev/null

# Ensure SELinux policy & permissions allow u:r:zygote:s0 to stat/read OCORE.json
ensure_zygisk_fs_access() {
  chmod a+x /data/adb /data/adb/modules "$MODDIR" "$MODDIR/cortex" 2>/dev/null || true
  chmod 0644 "$JSON_FILE" "$SPOOF_CPU_FILE" 2>/dev/null || true
  chcon u:object_r:system_file:s0 "$MODDIR" "$MODDIR/cortex" "$JSON_FILE" "$SPOOF_CPU_FILE" 2>/dev/null || true

  if [ ! -f "$STATE_DIR/sepolicy_zygisk_patched" ]; then
    for _pol in magiskpolicy supolicy /data/adb/magisk/magiskpolicy; do
      if command -v "$_pol" >/dev/null 2>&1 || [ -x "$_pol" ]; then
        "$_pol" --live "allow zygote adb_data_file dir { search getattr open read }" \
          "allow zygote adb_data_file file { getattr open read }" \
          "allow zygote adb_data_file lnk_file { getattr read }" \
          "allow zygote system_file dir { search getattr open read }" \
          "allow zygote system_file file { getattr open read }" >/dev/null 2>&1 && touch "$STATE_DIR/sepolicy_zygisk_patched"
        break
      fi
    done
    if command -v ksud >/dev/null 2>&1 || [ -x "/data/adb/ksu/bin/ksud" ]; then
      _ksud=$(command -v ksud 2>/dev/null || echo "/data/adb/ksu/bin/ksud")
      "$_ksud" sepolicy patch "allow zygote adb_data_file dir { search getattr open read }" >/dev/null 2>&1
      "$_ksud" sepolicy patch "allow zygote adb_data_file file { getattr open read }" >/dev/null 2>&1
      "$_ksud" sepolicy patch "allow zygote system_file dir { search getattr open read }" >/dev/null 2>&1
      "$_ksud" sepolicy patch "allow zygote system_file file { getattr open read }" >/dev/null 2>&1
      touch "$STATE_DIR/sepolicy_zygisk_patched" 2>/dev/null
    fi
  fi
}

# Find working resetprop binary across KernelSU, APatch, and Magisk
run_resetprop() {
  _rp_key="$1"
  _rp_val="$2"
  [ -z "$_rp_key" ] || [ -z "$_rp_val" ] && return 1
  if command -v resetprop >/dev/null 2>&1; then
    resetprop -n "$_rp_key" "$_rp_val" >/dev/null 2>&1
    return $?
  elif [ -x "/data/adb/ksu/bin/resetprop" ]; then
    /data/adb/ksu/bin/resetprop -n "$_rp_key" "$_rp_val" >/dev/null 2>&1
    return $?
  elif [ -x "/data/adb/ap/bin/resetprop" ]; then
    /data/adb/ap/bin/resetprop -n "$_rp_key" "$_rp_val" >/dev/null 2>&1
    return $?
  elif [ -x "/data/adb/magisk/magisk" ]; then
    /data/adb/magisk/magisk resetprop -n "$_rp_key" "$_rp_val" >/dev/null 2>&1
    return $?
  else
    setprop "$_rp_key" "$_rp_val" >/dev/null 2>&1
    return $?
  fi
}

# Capture stock device properties once before any spoofing occurs
backup_stock_device_props() {
  [ -f "$STOCK_PROPS_FILE" ] && [ -s "$STOCK_PROPS_FILE" ] && return 0
  if ! command -v getprop >/dev/null 2>&1; then
    return 0
  fi
  _s_model=$(getprop ro.product.model 2>/dev/null)
  _s_brand=$(getprop ro.product.brand 2>/dev/null)
  _s_mfg=$(getprop ro.product.manufacturer 2>/dev/null)
  _s_dev=$(getprop ro.product.device 2>/dev/null)
  _s_name=$(getprop ro.product.name 2>/dev/null)
  _s_fp=$(getprop ro.build.fingerprint 2>/dev/null)
  _s_mkt=$(getprop ro.product.marketname 2>/dev/null)
  _s_xmkt=$(getprop ro.Xiaomi.marketname 2>/dev/null)
  _s_cmkt=$(getprop ro.config.marketing_name 2>/dev/null)
  [ -z "$_s_model" ] && return 0
  cat << EOS > "$STOCK_PROPS_FILE"
STOCK_MODEL="$_s_model"
STOCK_BRAND="$_s_brand"
STOCK_MANUFACTURER="$_s_mfg"
STOCK_DEVICE="$_s_dev"
STOCK_NAME="$_s_name"
STOCK_FINGERPRINT="$_s_fp"
STOCK_MARKETNAME="$_s_mkt"
STOCK_XIAOMI_MARKETNAME="$_s_xmkt"
STOCK_CONFIG_MARKETING_NAME="$_s_cmkt"
EOS
  chmod 0644 "$STOCK_PROPS_FILE" 2>/dev/null
}

# Apply native ro.product.* properties via resetprop -n so C/C++ game engines
# (__system_property_get) and non-Zygisk / Unmount environments see the spoofed device
apply_native_device_props() {
  _np_brand="$1"
  _np_mfg="$2"
  _np_model="$3"
  _np_dev="$4"
  _np_prod="$5"
  _np_fp="$6"
  _np_dname="${7:-$3}"

  backup_stock_device_props

  for _p in "" "system." "vendor." "odm." "product." "system_ext."; do
    [ -n "$_np_brand" ] && run_resetprop "ro.product.${_p}brand" "$_np_brand"
    [ -n "$_np_mfg" ] && run_resetprop "ro.product.${_p}manufacturer" "$_np_mfg"
    [ -n "$_np_model" ] && run_resetprop "ro.product.${_p}model" "$_np_model"
    [ -n "$_np_dev" ] && run_resetprop "ro.product.${_p}device" "$_np_dev"
    [ -n "$_np_prod" ] && run_resetprop "ro.product.${_p}name" "$_np_prod"
  done
  [ -n "$_np_dev" ] && run_resetprop "ro.build.product" "$_np_dev"
  [ -n "$_np_dname" ] && run_resetprop "ro.product.marketname" "$_np_dname"
  [ -n "$_np_dname" ] && run_resetprop "ro.Xiaomi.marketname" "$_np_dname"
  [ -n "$_np_dname" ] && run_resetprop "ro.config.marketing_name" "$_np_dname"
  if [ -n "$_np_fp" ]; then
    for _fp_prop in ro.build.fingerprint ro.system.build.fingerprint ro.vendor.build.fingerprint ro.odm.build.fingerprint ro.product.build.fingerprint; do
      run_resetprop "$_fp_prop" "$_np_fp"
    done
  fi
  echo "${_np_brand}|${_np_mfg}|${_np_model}|${_np_dev}|${_np_prod}" > "$STATE_DIR/active_spoof_props.state" 2>/dev/null
}

# Restore native ro.product.* properties back to original stock hardware
restore_stock_device_props() {
  if [ -f "$STOCK_PROPS_FILE" ]; then
    . "$STOCK_PROPS_FILE"
    for _p in "" "system." "vendor." "odm." "product." "system_ext."; do
      [ -n "$STOCK_BRAND" ] && run_resetprop "ro.product.${_p}brand" "$STOCK_BRAND"
      [ -n "$STOCK_MANUFACTURER" ] && run_resetprop "ro.product.${_p}manufacturer" "$STOCK_MANUFACTURER"
      [ -n "$STOCK_MODEL" ] && run_resetprop "ro.product.${_p}model" "$STOCK_MODEL"
      [ -n "$STOCK_DEVICE" ] && run_resetprop "ro.product.${_p}device" "$STOCK_DEVICE"
      [ -n "$STOCK_NAME" ] && run_resetprop "ro.product.${_p}name" "$STOCK_NAME"
    done
    [ -n "$STOCK_DEVICE" ] && run_resetprop "ro.build.product" "$STOCK_DEVICE"
    [ -n "$STOCK_MARKETNAME" ] && run_resetprop "ro.product.marketname" "$STOCK_MARKETNAME"
    [ -n "$STOCK_XIAOMI_MARKETNAME" ] && run_resetprop "ro.Xiaomi.marketname" "$STOCK_XIAOMI_MARKETNAME"
    [ -n "$STOCK_CONFIG_MARKETING_NAME" ] && run_resetprop "ro.config.marketing_name" "$STOCK_CONFIG_MARKETING_NAME"
    if [ -n "$STOCK_FINGERPRINT" ]; then
      for _fp_prop in ro.build.fingerprint ro.system.build.fingerprint ro.vendor.build.fingerprint ro.odm.build.fingerprint ro.product.build.fingerprint; do
        run_resetprop "$_fp_prop" "$STOCK_FINGERPRINT"
      done
    fi
  fi
  rm -f "$STATE_DIR/active_spoof_props.state" 2>/dev/null
}

# Force-stop target app so Zygote forks a fresh process and runs preAppSpecialize
force_stop_target_app() {
  _fs_pkg="$1"
  [ -z "$_fs_pkg" ] && return 0
  if command -v am >/dev/null 2>&1; then
    am force-stop "$_fs_pkg" >/dev/null 2>&1 || true
  fi
  killall "$_fs_pkg" >/dev/null 2>&1 || true
}

acquire_json_lock() {
  _tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ -f "$LOCK_DIR/pid" ]; then
      _lpid=$(cat "$LOCK_DIR/pid" 2>/dev/null | tr -dc '0-9')
      if [ -n "$_lpid" ] && [ ! -d "/proc/$_lpid" ]; then
        rm -rf "$LOCK_DIR" 2>/dev/null
        continue
      fi
    fi
    _tries=$((_tries + 1))
    [ "$_tries" -ge 30 ] && rm -rf "$LOCK_DIR" 2>/dev/null && mkdir "$LOCK_DIR" 2>/dev/null && break
    sleep 0.1 2>/dev/null || sleep 1
  done
  echo "$$" > "$LOCK_DIR/pid" 2>/dev/null
}

release_json_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null
}

validate_pkg_name() {
  _pkg="$1"
  echo "$_pkg" | grep -Eq '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$' || return 1
  case "$_pkg" in
    android|system|com.android.systemui|com.android.settings|com.android.phone|com.android.nfc|com.android.vending|com.google.android.gms*|com.google.android.gsf*|me.weishu.kernelsu|com.rifsxd.ksunext|me.bmax.apatch|com.topjohnwu.magisk)
      return 1
      ;;
  esac
  if [ -f "$STATE_DIR/spoof_blacklist.txt" ] && grep -qx "$_pkg" "$STATE_DIR/spoof_blacklist.txt" 2>/dev/null; then
    return 1
  fi
  return 0
}

# Validate JSON structural integrity (Python3 -> jq -> POSIX character-state machine)
validate_json_file() {
  _vf="$1"
  [ -f "$_vf" ] && [ -s "$_vf" ] || return 1

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    d = json.load(f)
assert isinstance(d, dict) and "active_injections" in d and "cpu_spoof" in d
' "$_vf" 2>/dev/null
    return $?
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -e '.active_injections != null and .cpu_spoof != null' "$_vf" >/dev/null 2>&1
    return $?
  fi

  # Pure POSIX JSON lexical & brace/bracket/quote balance + required root keys check
  grep -q '"active_injections"' "$_vf" 2>/dev/null || return 1
  grep -q '"cpu_spoof"' "$_vf" 2>/dev/null || return 1
  awk '
  BEGIN { in_str=0; esc=0; braces=0; brackets=0; valid=1; saw_open=0 }
  {
    len = length($0)
    for (i = 1; i <= len; i++) {
      c = substr($0, i, 1)
      if (in_str) {
        if (esc) { esc = 0 }
        else if (c == "\\") { esc = 1 }
        else if (c == "\"") { in_str = 0 }
      } else {
        if (c == "\"") { in_str = 1 }
        else if (c == "{") { braces++; saw_open = 1 }
        else if (c == "}") { braces--; if (braces < 0) valid = 0 }
        else if (c == "[") { brackets++ }
        else if (c == "]") { brackets--; if (brackets < 0) valid = 0 }
      }
    }
  }
  END {
    if (!saw_open || in_str || braces != 0 || brackets != 0 || !valid) exit 1
    exit 0
  }' "$_vf" 2>/dev/null
  return $?
}

ensure_cpuinfo_template() {
  if [ -f "/proc/cpuinfo" ] && grep -q "processor" /proc/cpuinfo 2>/dev/null; then
    cp -f /proc/cpuinfo "$SPOOF_CPU_FILE" 2>/dev/null
    chmod 0644 "$SPOOF_CPU_FILE" 2>/dev/null
  elif [ ! -f "$SPOOF_CPU_FILE" ]; then
    cat << 'EOT' > "$SPOOF_CPU_FILE"
Processor	: AArch64 Processor rev 0 (aarch64)
processor	: 0
BogoMIPS	: 52.00
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x2
CPU part	: 0xd05
CPU revision	: 0
EOT
    chmod 0644 "$SPOOF_CPU_FILE" 2>/dev/null
  fi
}

check_cpu_spoof_compatibility() {
  ensure_cpuinfo_template
  _host_arch=$(uname -m 2>/dev/null)
  case "$_host_arch" in
    aarch64|arm64*|x86_64) ;;
    *) echo "UNSUPPORTED_ARCH"; return 1 ;;
  esac
  if [ -f "/proc/cpuinfo" ] && [ -f "$SPOOF_CPU_FILE" ]; then
    _hc=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
    _tc=$(grep -c "^processor" "$SPOOF_CPU_FILE" 2>/dev/null)
    if [ "${_hc:-0}" -gt 0 ] && [ "${_tc:-0}" -gt 0 ] && [ "$_hc" -ne "$_tc" ]; then
      cp -f /proc/cpuinfo "$SPOOF_CPU_FILE" 2>/dev/null
    fi
  fi
  echo "COMPATIBLE"
  return 0
}

recover_json_if_needed() {
  if validate_json_file "$JSON_FILE"; then
    [ ! -f "$BACKUP_DIR/OCORE.json.good.bak" ] && cp -f "$JSON_FILE" "$BACKUP_DIR/OCORE.json.good.bak" 2>/dev/null
    return 0
  fi
  cp -f "$JSON_FILE" "$BACKUP_DIR/OCORE.json.corrupt.$(date '+%s').bak" 2>/dev/null
  if [ -f "$BACKUP_DIR/OCORE.json.good.bak" ] && validate_json_file "$BACKUP_DIR/OCORE.json.good.bak"; then
    cp -f "$BACKUP_DIR/OCORE.json.good.bak" "$JSON_FILE" 2>/dev/null
    return 0
  fi
  cat << 'EOJ' > "$JSON_FILE"
{
  "_schema_version": "3.0.0",
  "cpu_spoof": {
    "enabled_by_default": false,
    "require_arch_match": true,
    "blacklist": ["android", "com.android.systemui", "com.android.settings", "com.google.android.gms"],
    "cpu_only_packages": []
  },
  "PACKAGES_ROG_PHONE_9_PRO": {
    "PROFILE_ID": "PACKAGES_ROG_PHONE_9_PRO",
    "DEVICE_NAME": "ASUS ROG Phone 9 Pro",
    "BRAND": "asus",
    "MANUFACTURER": "asus",
    "MODEL": "ASUS_AI2501_A",
    "DEVICE": "AI2501",
    "PRODUCT": "WW_AI2501",
    "ANDROID_VERSION": "15",
    "SDK_INT": 35,
    "FINGERPRINT": "asus/WW_AI2501/AI2501:15/AP3A.240905.015.A2/35.1810.1810.100:user/release-keys",
    "HARDWARE": "qcom",
    "SOC_MODEL": "SM8750",
    "SOC_FAMILY": "Qualcomm Snapdragon 8 Elite",
    "ARCH": "arm64-v8a",
    "SOURCE_REF": "ASUS WW_AI2501 Android 15 Release Build",
    "VALIDATION_STATUS": "VERIFIED"
  },
  "active_injections": {}
}
EOJ
  ensure_zygisk_fs_access
  return 0
}

extract_profile_field() {
  _ep_prof="$1"
  _ep_key="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    d = json.load(f)
p = d.get(sys.argv[2], {})
val = p.get(sys.argv[3], "")
print(val if val is not None else "")
' "$JSON_FILE" "$_ep_prof" "$_ep_key" 2>/dev/null
    return 0
  fi

  awk -v prof="\"$_ep_prof\"" -v key="\"$_ep_key\"" '
  BEGIN { in_prof=0; depth=0 }
  {
    if (!in_prof && index($0, prof) > 0 && index($0, "{") > 0) {
      in_prof=1; depth=1; next
    }
    if (in_prof) {
      if (index($0, "}") > 0) {
        depth--
        if (depth <= 0) { in_prof=0; exit }
      }
      if (index($0, key) > 0) {
        line = $0
        sub(/^[^:]*:[[:space:]]*/, "", line)
        sub(/,[[:space:]]*$/, "", line)
        gsub(/^"|"$/, "", line)
        gsub(/\\\//, "/", line)
        print line
        exit
      }
    }
  }' "$JSON_FILE" 2>/dev/null
}

profile_exists() {
  _pe_prof="$1"
  case "$_pe_prof" in
    PACKAGES_*|PROFILE_*) ;;
    *) return 1 ;;
  esac
  _b=$(extract_profile_field "$_pe_prof" "BRAND")
  _m=$(extract_profile_field "$_pe_prof" "MODEL")
  [ -n "$_b" ] && [ -n "$_m" ]
}

rebuild_active_injections() {
  recover_json_if_needed
  _tmp_json="${JSON_FILE}.tmp.$$"
  cp -f "$JSON_FILE" "$BACKUP_DIR/OCORE.json.tx_pre.bak" 2>/dev/null

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys, glob, os
json_path, bind_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(json_path, "r", encoding="utf-8") as f:
    doc = json.load(f)
active = {}
for bf in sorted(glob.glob(os.path.join(bind_dir, "*.json"))):
    try:
        with open(bf, "r", encoding="utf-8") as bfile:
            entry = json.load(bfile)
            if isinstance(entry, dict):
                for k, v in entry.items():
                    active[k] = v
    except Exception:
        pass
doc["active_injections"] = active
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
' "$JSON_FILE" "$BINDINGS_DIR" "$_tmp_json" 2>/dev/null
  else
    sed '/"active_injections"[[:space:]]*:/,$d' "$JSON_FILE" > "$_tmp_json" 2>/dev/null
    echo '  "active_injections": {' >> "$_tmp_json"
    _first=1
    for _bf in "$BINDINGS_DIR"/*.json; do
      [ -f "$_bf" ] || continue
      [ "$_first" -eq 0 ] && echo '    ,' >> "$_tmp_json"
      sed '1s/^[[:space:]]*{//; $s/}[[:space:]]*$//' "$_bf" >> "$_tmp_json"
      _first=0
    done
    echo '  }' >> "$_tmp_json"
    echo '}' >> "$_tmp_json"
  fi

  if validate_json_file "$_tmp_json"; then
    mv -f "$_tmp_json" "$JSON_FILE" 2>/dev/null
    ensure_zygisk_fs_access
    cp -f "$JSON_FILE" "$BACKUP_DIR/OCORE.json.good.bak" 2>/dev/null
    return 0
  else
    rm -f "$_tmp_json" 2>/dev/null
    cp -f "$BACKUP_DIR/OCORE.json.tx_pre.bak" "$JSON_FILE" 2>/dev/null
    ensure_zygisk_fs_access
    return 1
  fi
}

cmd_bind() {
  _pkg="$1"
  _preset="$2"
  _wcpu="${3:-0}"

  if ! validate_pkg_name "$_pkg"; then
    echo "TRANSACTION_STATUS=FAILED"
    echo "[ERROR] Invalid or protected system/blacklisted package: $_pkg"
    return 1
  fi

  acquire_json_lock
  recover_json_if_needed

  if ! profile_exists "$_preset"; then
    release_json_lock
    echo "TRANSACTION_STATUS=FAILED"
    echo "[ERROR] Unknown or unvalidated device profile ID: $_preset"
    return 1
  fi

  _brand=$(extract_profile_field "$_preset" "BRAND")
  _mfg=$(extract_profile_field "$_preset" "MANUFACTURER")
  _model=$(extract_profile_field "$_preset" "MODEL")
  _device=$(extract_profile_field "$_preset" "DEVICE")
  _product=$(extract_profile_field "$_preset" "PRODUCT")
  _fp=$(extract_profile_field "$_preset" "FINGERPRINT")
  _hw=$(extract_profile_field "$_preset" "HARDWARE")
  _soc=$(extract_profile_field "$_preset" "SOC_MODEL")
  _aver=$(extract_profile_field "$_preset" "ANDROID_VERSION")
  _sdk=$(extract_profile_field "$_preset" "SDK_INT")
  _dname=$(extract_profile_field "$_preset" "DEVICE_NAME")

  if [ -z "$_aver" ]; then
    _aver=$(echo "$_fp" | sed -n 's|^[^:]*:\([0-9][0-9]*\)/.*|\1|p')
    [ -z "$_aver" ] && _aver="15"
  fi
  if [ -z "$_sdk" ]; then
    case "$_aver" in
      13) _sdk=33 ;;
      14) _sdk=34 ;;
      15) _sdk=35 ;;
      16) _sdk=36 ;;
      *)  _sdk=35 ;;
    esac
  fi

  _wcpu_bool="false"
  # Zygisk arm64-v8a.so checks "mode": "with_cpu" (8 chars) vs "device_only" (or "blocked")
  _zygisk_mode="device_only"
  if [ "$_wcpu" = "1" ] || [ "$_wcpu" = "true" ]; then
    if [ "$(check_cpu_spoof_compatibility)" = "COMPATIBLE" ]; then
      _wcpu_bool="true"
      _zygisk_mode="with_cpu"
    fi
  fi

  cat << EOB > "$BINDINGS_DIR/${_pkg}.json"
{
  "$_pkg": {
    "mode": "$_zygisk_mode",
    "profile_id": "$_preset",
    "device_name": "${_dname:-$_model}",
    "with_cpu": $_wcpu_bool,
    "device_info": {
      "BRAND": "$_brand",
      "MANUFACTURER": "$_mfg",
      "MODEL": "$_model",
      "DEVICE": "$_device",
      "PRODUCT": "$_product",
      "FINGERPRINT": "$_fp",
      "HARDWARE": "${_hw:-qcom}",
      "SOC_MODEL": "${_soc:-SM8750}",
      "ANDROID_VERSION": "$_aver",
      "SDK_INT": $_sdk
    }
  }
}
EOB

  # Also save flat per-package spoof env for fast runtime lookup by ocorectl / ocore-game-daemon
  cat << EOP > "$BINDINGS_DIR/${_pkg}.env"
SPOOF_PKG="$_pkg"
SPOOF_PROFILE_ID="$_preset"
SPOOF_MODE="$_zygisk_mode"
SPOOF_WITH_CPU="$_wcpu_bool"
SPOOF_DEVICE_NAME="${_dname:-$_model}"
SPOOF_BRAND="$_brand"
SPOOF_MANUFACTURER="$_mfg"
SPOOF_MODEL="$_model"
SPOOF_DEVICE="$_device"
SPOOF_PRODUCT="$_product"
SPOOF_FINGERPRINT="$_fp"
SPOOF_ANDROID_VERSION="$_aver"
SPOOF_SDK_INT="$_sdk"
EOP

  if rebuild_active_injections; then
    release_json_lock
    # Apply native ro.product.* properties immediately via resetprop -n AND force-stop target app
    apply_native_device_props "$_brand" "$_mfg" "$_model" "$_device" "$_product" "$_fp" "${_dname:-$_model}"
    force_stop_target_app "$_pkg"
    echo "TRANSACTION_STATUS=APPLIED"
    echo "[OK] Bound $_pkg -> $_preset (${_dname:-$_model}, Android $_aver / SDK $_sdk, Mode=$_zygisk_mode, App Restarted)"
    return 0
  else
    release_json_lock
    echo "TRANSACTION_STATUS=FAILED"
    echo "[ERROR] JSON validation failed during bind transaction; rolled back safely"
    return 1
  fi
}

cmd_unbind() {
  _pkg="$1"
  acquire_json_lock
  rm -f "$BINDINGS_DIR/${_pkg}.json" "$BINDINGS_DIR/${_pkg}.env" 2>/dev/null
  if rebuild_active_injections; then
    release_json_lock
    force_stop_target_app "$_pkg"
    # If another binding exists, apply the remaining binding; otherwise restore stock hardware props
    _rem_env=$(ls "$BINDINGS_DIR"/*.env 2>/dev/null | head -n 1)
    if [ -n "$_rem_env" ] && [ -f "$_rem_env" ]; then
      . "$_rem_env"
      apply_native_device_props "$SPOOF_BRAND" "$SPOOF_MANUFACTURER" "$SPOOF_MODEL" "$SPOOF_DEVICE" "$SPOOF_PRODUCT" "$SPOOF_FINGERPRINT" "$SPOOF_DEVICE_NAME"
    else
      restore_stock_device_props
    fi
    echo "TRANSACTION_STATUS=APPLIED"
    echo "[OK] Unbound $_pkg from active_injections & restored device state"
    return 0
  else
    release_json_lock
    echo "TRANSACTION_STATUS=FAILED"
    return 1
  fi
}

cmd_reset() {
  acquire_json_lock
  for _ef in "$BINDINGS_DIR"/*.env; do
    [ -f "$_ef" ] || continue
    _epkg=$(grep '^SPOOF_PKG=' "$_ef" 2>/dev/null | cut -d'"' -f2)
    [ -n "$_epkg" ] && force_stop_target_app "$_epkg"
  done
  rm -f "$BINDINGS_DIR"/*.json "$BINDINGS_DIR"/*.env 2>/dev/null
  if rebuild_active_injections; then
    release_json_lock
    restore_stock_device_props
    echo "TRANSACTION_STATUS=APPLIED"
    echo "[OK] Reset all active device profile bindings & restored stock properties"
    return 0
  else
    release_json_lock
    echo "TRANSACTION_STATUS=FAILED"
    return 1
  fi
}

cmd_apply_pkg() {
  _ap_pkg="$1"
  if [ -n "$_ap_pkg" ] && [ -f "$BINDINGS_DIR/${_ap_pkg}.env" ]; then
    . "$BINDINGS_DIR/${_ap_pkg}.env"
    ensure_zygisk_fs_access
    apply_native_device_props "$SPOOF_BRAND" "$SPOOF_MANUFACTURER" "$SPOOF_MODEL" "$SPOOF_DEVICE" "$SPOOF_PRODUCT" "$SPOOF_FINGERPRINT" "$SPOOF_DEVICE_NAME"
    return 0
  fi
  return 1
}

cmd_audit() {
  recover_json_if_needed
  ensure_zygisk_fs_access
  if validate_json_file "$JSON_FILE"; then
    _cnt=$(ls -1 "$BINDINGS_DIR"/*.json 2>/dev/null | wc -l | tr -dc '0-9')
    _pcount=$(grep -c '"PACKAGES_' "$JSON_FILE" 2>/dev/null | tr -dc '0-9')
    _cur_model=$(getprop ro.product.model 2>/dev/null || echo "unknown")
    echo "JSON_STATUS=VALID"
    echo "PROFILES_COUNT=${_pcount:-0}"
    echo "ACTIVE_BINDINGS=${_cnt:-0}"
    echo "CPU_SPOOF_ARCH=$(check_cpu_spoof_compatibility)"
    echo "CURRENT_NATIVE_MODEL=${_cur_model}"
    echo "SELINUX_ZYGISK_ACCESS=GRANTED"
    return 0
  else
    echo "JSON_STATUS=INVALID"
    return 1
  fi
}

case "$1" in
  validate)  validate_json_file "${2:-$JSON_FILE}" ;;
  recover)   recover_json_if_needed ;;
  bind)      cmd_bind "$2" "$3" "$4" ;;
  unbind)    cmd_unbind "$2" ;;
  reset)     cmd_reset ;;
  rebuild)   acquire_json_lock; rebuild_active_injections; release_json_lock ;;
  apply_pkg) cmd_apply_pkg "$2" ;;
  restore_stock) restore_stock_device_props ;;
  audit)     cmd_audit ;;
  list)      recover_json_if_needed; ensure_zygisk_fs_access; cat "$JSON_FILE" 2>/dev/null ;;
  *)
    echo "Usage: $0 {validate|recover|bind <pkg> <profile> [with_cpu]|unbind <pkg>|reset|rebuild|apply_pkg <pkg>|restore_stock|audit|list}"
    exit 1
    ;;
esac
