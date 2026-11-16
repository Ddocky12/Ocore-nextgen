#!/system/bin/sh
# ==============================================================================
# Ocore v3.2.0-NextGen Subsystem F: FPS History Engine
# Records bounded ring-buffer FPS and frame-time telemetry during active game
# sessions and computes session summary statistics (Min, Avg, Max FPS, P95, Jank).
# ==============================================================================

record_fps_history_sample() {
  _fhe_pkg="$1"
  _fhe_fps="$2"
  _fhe_p50="$3"
  _fhe_p95="$4"
  _fhe_jank="$5"
  _fhe_src="$6"
  [ -z "$_fhe_pkg" ] || [ -z "$_fhe_fps" ] || [ "$_fhe_fps" = "UNAVAILABLE" ] || [ "$_fhe_fps" = "--" ] && return 0

  _fhe_log="$LOG_DIR/fps_history.log"
  _fhe_sum="$STATE_DIR/fps_session_summary.env"
  _fhe_ts="$(date '+%Y-%m-%d %H:%M:%S')"
  _fhe_num=$(printf "%s" "$_fhe_fps" | awk '{gsub(/[^0-9.]/, "", $0); print $0}')
  [ -z "$_fhe_num" ] && return 0

  echo "${_fhe_ts}|${_fhe_pkg}|${_fhe_num}|${_fhe_p50:-0}|${_fhe_p95:-0}|${_fhe_jank:-0.0%}|${_fhe_src:-gfxinfo}" >> "$_fhe_log" 2>/dev/null

  # Keep ring buffer bounded to last 200 samples
  _fhe_lines=$(wc -l < "$_fhe_log" 2>/dev/null | tr -dc '0-9')
  if [ "${_fhe_lines:-0}" -gt 240 ] 2>/dev/null; then
    tail -n 180 "$_fhe_log" > "${_fhe_log}.tmp.$$" 2>/dev/null && mv -f "${_fhe_log}.tmp.$$" "$_fhe_log" 2>/dev/null
  fi

  # Update session summary atomically for current game
  awk -F'|' -v pkg="$_fhe_pkg" '
    $2 == pkg && $3 + 0 > 0 {
      v = $3 + 0
      n++
      sum += v
      if (min == 0 || v < min) min = v
      if (v > max) max = v
      p95 = $5
      gsub(/[^0-9.]/, "", p95)
      if (p95 + 0 > 0) { p95_sum += (p95 + 0); p95_n++ }
    }
    END {
      if (n > 0) {
        printf "FPS_HIST_PKG=%s\nFPS_HIST_SAMPLES=%d\nFPS_HIST_MIN=%.1f\nFPS_HIST_AVG=%.1f\nFPS_HIST_MAX=%.1f\nFPS_HIST_P95_AVG=%.2f\n",
          pkg, n, min, (sum / n), max, (p95_n > 0 ? p95_sum / p95_n : 0.0)
      }
    }
  ' "$_fhe_log" > "${_fhe_sum}.tmp.$$" 2>/dev/null && mv -f "${_fhe_sum}.tmp.$$" "$_fhe_sum" 2>/dev/null
}
