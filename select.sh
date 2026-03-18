#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"

hyprctl dispatch focusmonitor "$INTERNAL_MONITOR" >/dev/null 2>&1
sleep 0.1

choice=$(printf "Primary only\nMonitor only\nDuplicate\nExtend" | rofi -dmenu -p "Monitor layout")

case "$choice" in
    "Primary only")
        set_last_mode "primary-only"
        set_layout_flag
        bash "$PROFILE_DIR/primary-only.sh"
        clear_layout_flag_later 3
        ;;
    "Monitor only")
        set_layout_flag
        bash "$PROFILE_DIR/monitor-only.sh"
        if [ $? -eq 0 ]; then
            set_last_mode "monitor-only"
        fi
        clear_layout_flag_later 3
        ;;
    "Duplicate")
        set_last_mode "duplicate"
        set_layout_flag
        bash "$PROFILE_DIR/duplicate.sh"
        clear_layout_flag_later 3
        ;;
    "Extend")
        set_last_mode "extend"
        set_layout_flag
        bash "$PROFILE_DIR/extend.sh"
        clear_layout_flag_later 3
        ;;
    *)
        exit 0
        ;;
esac
