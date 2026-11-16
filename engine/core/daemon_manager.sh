#!/system/bin/sh
# ==============================================================================
# Ocore Next-Gen Modular Subsystem #13: Background Daemon Manager
# Enforces PID + /proc/<pid>/cmdline identity verification (Section 15).
# ==============================================================================
verify_pid_identity() {
  _vpi_pid="$1"
  _vpi_patterns="$2"
  [ -z "$_vpi_pid" ] || [ ! -d "/proc/$_vpi_pid" ] && return 1
  _cmdline=$(tr '\0' ' ' < "/proc/$_vpi_pid/cmdline" 2>/dev/null)
  _comm=$(cat "/proc/$_vpi_pid/comm" 2>/dev/null)
  for _pat in $_vpi_patterns; do
    case "$_cmdline $_comm" in
      *"$_pat"*) return 0 ;;
    esac
  done
  return 1
}
