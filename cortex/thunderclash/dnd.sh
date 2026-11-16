#!/system/bin/sh
case "$1" in
  "--enable")
    settings put global zen_mode 1 >/dev/null 2>&1
    cmd notification set_dnd priority >/dev/null 2>&1 || cmd notification set_dnd on >/dev/null 2>&1
    settings put global heads_up_notifications_enabled 0 >/dev/null 2>&1
    ;;
  "--disable")
    settings put global zen_mode 0 >/dev/null 2>&1
    cmd notification set_dnd off >/dev/null 2>&1
    settings put global heads_up_notifications_enabled 1 >/dev/null 2>&1
    ;;
esac
exit 0
