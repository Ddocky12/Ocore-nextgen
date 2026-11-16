#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem B: Intelligent FPS Controller
# Computes refresh-rate-adaptive FPS thresholds (60/90/120/144 Hz) and color
# classification (GREEN / YELLOW / RED / GRAY), validates sample freshness,
# and coordinates multi-source FPS telemetry (FrameTimeline, SurfaceFlinger,
# FPS Daemon Cache, and dumpsys gfxinfo fallback).
# ==============================================================================

get_active_display_hz_int() {
  _adh_val=""
  if command -v dumpsys >/dev/null 2>&1; then
    _adh_val=$(dumpsys display 2>/dev/null | awk '
      /mActiveMode=/ || /activeMode=/ || /RefreshRate/ {
        if (match($0, /fps=[0-9]+(\.[0-9]+)?/)) {
          s = substr($0, RSTART+4, RLENGTH-4)
          printf "%d\n", s + 0.5
          exit
        }
      }
    ')
  fi
  if [ -z "$_adh_val" ] || [ "$_adh_val" -le 0 ] 2>/dev/null; then
    _peak=$(settings get system peak_refresh_rate 2>/dev/null | awk '{printf "%d", $0 + 0.5}')
    [ -n "$_peak" ] && [ "$_peak" -ge 60 ] 2>/dev/null && _adh_val="$_peak"
  fi
  case "$_adh_val" in
    60|90|120|144|165) echo "$_adh_val" ;;
    *)
      if [ "${_adh_val:-0}" -ge 135 ] 2>/dev/null; then echo "144"
      elif [ "${_adh_val:-0}" -ge 105 ] 2>/dev/null; then echo "120"
      elif [ "${_adh_val:-0}" -ge 75 ] 2>/dev/null; then echo "90"
      else echo "60"
      fi
      ;;
  esac
}

classify_fps_status_color() {
  _cfs_fps="$1"
  _cfs_target="${2:-60}"
  _cfs_prov="${3:-ACTUAL}"

  case "$_cfs_prov" in
    ACTUAL|CACHED_ACTUAL) ;;
    *) echo "GRAY"; return 0 ;;
  esac

  _fps_int=$(printf "%s" "$_cfs_fps" | awk '{gsub(/[^0-9.]/, "", $0); if ($0 == "") print -1; else printf "%d", $0 + 0.5}')
  if [ -z "$_fps_int" ] || [ "$_fps_int" -le 0 ] 2>/dev/null; then
    echo "GRAY"
    return 0
  fi

  [ -z "$_cfs_target" ] || [ "$_cfs_target" -le 0 ] 2>/dev/null && _cfs_target=60
  _green_thr=$(( (_cfs_target * "${FPS_GREEN_PCT:-85}") / 100 ))
  _yellow_thr=$(( (_cfs_target * "${FPS_YELLOW_PCT:-60}") / 100 ))

  if [ "$_fps_int" -ge "$_green_thr" ]; then
    echo "GREEN"
  elif [ "$_fps_int" -ge "$_yellow_thr" ]; then
    echo "YELLOW"
  else
    echo "RED"
  fi
}

sample_surfaceflinger_fps() {
  _ssf_pkg="$1"
  [ -z "$_ssf_pkg" ] && return 1
  command -v dumpsys >/dev/null 2>&1 || return 1

  # Find the active SurfaceView / BLAST layer for the target package
  _ssf_layer=$(dumpsys SurfaceFlinger --list 2>/dev/null | grep "$_ssf_pkg" | grep -E "SurfaceView|BLAST|\$_ssf_pkg" | tail -n 1 | tr -d '\r\n')
  [ -z "$_ssf_layer" ] && return 1

  _ssf_lat=$(dumpsys SurfaceFlinger --latency "$_ssf_layer" 2>/dev/null)
  [ -z "$_ssf_lat" ] && return 1

  echo "$_ssf_lat" | awk '
    NR == 1 { refresh_period = $1; next }
    NF == 3 && $2 > 0 && $2 < 9223372036854775807 {
      n++
      present[n] = $2
      if ($3 > $1 && ($3 - $1) < 500000000) {
        dur[n] = ($3 - $1) / 1000000.0
      } else {
        dur[n] = 16.67
      }
    }
    END {
      if (n >= 8) {
        span_ns = present[n] - present[1]
        if (span_ns > 100000000) {
          fps = ((n - 1) * 1000000000.0) / span_ns
          sum_d = 0
          jank = 0
          for (i = 2; i <= n; i++) {
            dt_ms = (present[i] - present[i-1]) / 1000000.0
            sum_d += dt_ms
            if (dt_ms > 25.0) jank++
          }
          avg_ms = sum_d / (n - 1)
          jank_pct = (jank * 100.0) / (n - 1)
          if (fps > 1.0 && fps <= 240.0) {
            printf "SF_OK|%.1f|%.2f|%.1f%%|%d\n", fps, avg_ms, jank_pct, n
            exit 0
          }
        }
      }
      exit 1
    }
  '
}
