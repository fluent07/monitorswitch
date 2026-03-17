#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"
set_internal_enabled 0
EXT_MON="$(get_current_external)"
[ -z "$EXT_MON" ] && exit 1

hyprctl keyword monitor "$INTERNAL_MONITOR,disable"
sleep 0.2
hyprctl keyword monitor "$EXT_MON,preferred,0x0,$EXTERNAL_SCALE"
hyprctl dispatch dpms on
