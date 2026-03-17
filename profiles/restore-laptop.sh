#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"

hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
hyprctl dispatch dpms on
