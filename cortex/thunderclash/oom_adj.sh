#!/system/bin/sh
# ==============================================================================
# Ocore OOM Protection Helper (oom_adj.sh v2.1)
# Safely protects active Ocore & Root WebUI processes from low-memory kills.
# ==============================================================================

TARGET_OOM_SCORE_ADJ=-100
TARGET_OOM_ADJ=-10

for PKG in com.ocore.booster io.github.a13e300.ksuwebui me.bmax.apatch me.weishu.kernelsu com.rifsxd.ksunext; do
  for PID in $(/system/bin/toybox pidof "$PKG" 2>/dev/null); do
    [ -d "/proc/$PID" ] || continue
    [ -w "/proc/$PID/oom_score_adj" ] && echo "$TARGET_OOM_SCORE_ADJ" > "/proc/$PID/oom_score_adj" 2>/dev/null
    [ -w "/proc/$PID/oom_adj" ] && echo "$TARGET_OOM_ADJ" > "/proc/$PID/oom_adj" 2>/dev/null
  done
done

exit 0