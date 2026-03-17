#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"
set_internal_enabled 1
ensure_runtime_files
: > "$IGNORE_FILE"

mapfile -t externals < <(get_connected_external_monitors)

if [ "${#externals[@]}" -gt 0 ]; then
    remember_external "${externals[0]}"
fi

for mon in "${externals[@]}"; do
    [ -z "$mon" ] && continue
    add_ignored_remove "$mon"
    hyprctl keyword monitor "$mon,disable"
done

sleep 0.2
hyprctl keyword monitor "$INTERNAL_MONITOR,$INTERNAL_MODE,$INTERNAL_POS,$INTERNAL_SCALE"
hyprctl dispatch dpms on
