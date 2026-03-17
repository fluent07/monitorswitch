#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"
set_internal_enabled 1
hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
hyprctl dispatch dpms on
