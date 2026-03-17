#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"
set_internal_enabled 1
EXT_MON="$(get_current_external)"
[ -z "$EXT_MON" ] && exit 1

hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
sleep 0.2
hyprctl keyword monitor "$EXT_MON,$DUPLICATE_MODE,0x0,$EXTERNAL_SCALE,mirror,$INTERNAL_MONITOR"
hyprctl dispatch dpms on
