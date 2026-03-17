#!/bin/bash
source "$HOME/.config/hypr/monitors/common.sh"

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

[ -S "$SOCKET" ] || exit 1
ensure_runtime_files
# Clean up any stale lockfile from a previous crashed session
rm -f "$LOCKFILE"
echo "started $(date)" > "$LOGFILE"

launch_menu() {
    local mon="$1"

    [ -f "$LOCKFILE" ] && return

    remember_external "$mon"
    touch "$LOCKFILE"

    (
        sleep 0.5
        hyprctl dispatch focusmonitor "$INTERNAL_MONITOR" >/dev/null 2>&1
        bash "$HOME/.config/hypr/monitors/select.sh"
        sleep 2
        rm -f "$LOCKFILE"
    ) >/dev/null 2>>"$LOGFILE" &
}

restore_laptop() {
    log_msg "restoring laptop"
    set_layout_flag
    bash "$PROFILE_DIR/restore-laptop.sh" >/dev/null 2>>"$LOGFILE"
    set_last_mode "primary-only"
    clear_layout_flag_later 3
}

handle_verified_add() {
    local mon="$1"

    if is_internal_monitor "$mon" || is_fake_monitor "$mon"; then
        return
    fi

    if layout_change_active; then
        log_msg "ignored add during layout change: $mon"
        return
    fi
    # Immediately park the monitor off-screen to suppress Hyprland's
    # "monitor not configured / overlapping" warning. The profile scripts
    # will place it correctly once the user picks a layout.
    hyprctl keyword monitor "$mon,preferred,99999x0,1" >/dev/null 2>&1
    
    sleep 2

    if ! external_monitor_present "$mon"; then
        log_msg "ignored transient add: $mon"
        return
    fi

    log_msg "verified add: $mon"
    launch_menu "$mon"
}

handle_verified_remove() {
    local mon="$1"

    if is_internal_monitor "$mon" || is_fake_monitor "$mon"; then
        return
    fi

    if is_ignored_remove "$mon"; then
        log_msg "ignored scripted remove: $mon"
        consume_ignored_remove "$mon"
        return
    fi

    if layout_change_active; then
        log_msg "ignored remove during layout change: $mon"
        return
    fi

    sleep 0.5

    if external_monitor_present "$mon"; then
        log_msg "ignored unconfirmed remove: $mon"
        return
    fi

    log_msg "verified remove: $mon"
    restore_laptop
}

startup_scan() {
    local mon
    mon="$(first_connected_external)"
    [ -z "$mon" ] && return

    if layout_change_active; then
        log_msg "startup scan skipped during layout change"
        return
    fi

    log_msg "startup scan found external: $mon"
    launch_menu "$mon"
}

# Startup scan handles the case where a monitor is already connected before login.
(
    sleep 1
    startup_scan
) >/dev/null 2>>"$LOGFILE" &

socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r line; do
    case "$line" in
        'monitoradded>>'*)
            mon="${line#monitoradded>>}"
            (
                handle_verified_add "$mon"
            ) >/dev/null 2>>"$LOGFILE" &
            ;;

        'monitorremoved>>'*)
            mon="${line#monitorremoved>>}"
            (
                handle_verified_remove "$mon"
            ) >/dev/null 2>>"$LOGFILE" &
            ;;
    esac
done
