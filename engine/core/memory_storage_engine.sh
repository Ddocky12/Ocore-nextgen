#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #12: Memory, ZRAM & Storage I/O Engine
# Zero-fork pure POSIX shell /proc/meminfo & ZRAM reader.
# ==============================================================================
read_memory_storage_telemetry() {
  _mt_kb=0; _ma_kb=0; _mf_kb=0; _mc_kb=0; _mb_kb=0; _st_kb=0; _sf_kb=0
  if [ -f "/proc/meminfo" ]; then
    while IFS=": " read -r _mk _mv _mu; do
      case "$_mk" in
        MemTotal)     _mt_kb="$_mv" ;;
        MemFree)      _mf_kb="$_mv" ;;
        MemAvailable) _ma_kb="$_mv" ;;
        Buffers)      _mb_kb="$_mv" ;;
        Cached)       _mc_kb="$_mv" ;;
        SwapTotal)    _st_kb="$_mv" ;;
        SwapFree)     _sf_kb="$_mv"; break ;;
      esac
    done < /proc/meminfo
  fi

  RAM_TOTAL_MB=$(( ${_mt_kb:-0} / 1024 ))
  RAM_AVAIL_MB=$(( ${_ma_kb:-0} / 1024 ))
  RAM_USED_MB=$(( (${_mt_kb:-0} - ${_ma_kb:-0}) / 1024 ))
  RAM_CACHE_MB=$(( (${_mc_kb:-0} + ${_mb_kb:-0}) / 1024 ))
  RAM_PCT=0
  [ "${_mt_kb:-0}" -gt 0 ] && RAM_PCT=$(( ( (${_mt_kb:-0} - ${_ma_kb:-0}) * 100 ) / _mt_kb ))
  ZRAM_TOTAL_MB=$(( ${_st_kb:-0} / 1024 ))
  ZRAM_USED_MB=$(( (${_st_kb:-0} - ${_sf_kb:-0}) / 1024 ))
  ZRAM_ALGO="lzo-rle"
  if [ -f "/sys/block/zram0/comp_algorithm" ]; then
    read -r _zline < /sys/block/zram0/comp_algorithm 2>/dev/null || _zline=""
    case "$_zline" in
      *\[*\]*)
        _alg="${_zline#*\[}"
        ZRAM_ALGO="${_alg%%\]*}"
        ;;
    esac
  fi
}
