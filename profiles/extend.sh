#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"
set_internal_enabled 1
EXT_MON="$(get_current_external)"
[ -z "$EXT_MON" ] && exit 1

if ! external_monitor_present "$EXT_MON"; then
    exit 1
fi

hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
sleep 0.2
hyprctl keyword monitor "$EXT_MON,preferred,$EXTEND_POS,$EXTERNAL_SCALE"
hyprctl dispatch dpms on