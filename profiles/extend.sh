#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"

EXT_MON="$(get_current_external)"
[ -z "$EXT_MON" ] && exit 1

hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
sleep 0.2
hyprctl keyword monitor "$EXT_MON,preferred,$EXTEND_POS,$EXTERNAL_SCALE"
hyprctl dispatch dpms on
