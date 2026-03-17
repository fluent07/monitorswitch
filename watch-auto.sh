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
    set_last_mode "primary-only"
    set_layout_flag
    bash "$PROFILE_DIR/restore-laptop.sh" >/dev/null 2>>"$LOGFILE"
    clear_layout_flag_later 5
}

handle_config_reload() {
    # If a layout change is already in progress (including one triggered by
    # a previous configreloaded), ignore this event to prevent a reload loop.
    if layout_change_active; then
        log_msg "ignored configreloaded during layout change"
        return
    fi

    local last_mode ext_mon
    last_mode="$(cat "$STATE_FILE" 2>/dev/null)"
    ext_mon="$(get_current_external)"

    [ -z "$last_mode" ] && return

    log_msg "config reloaded, last mode: $last_mode, external: ${ext_mon:-none}"
    set_layout_flag

    case "$last_mode" in
        monitor-only)
            # External is connected and last mode was external-only:
            # hyprland.conf just re-enabled the internal — disable it again.
            if [ -n "$ext_mon" ] && external_monitor_present "$ext_mon"; then
                log_msg "re-applying monitor-only after reload"
                bash "$PROFILE_DIR/monitor-only.sh" >/dev/null 2>>"$LOGFILE"
            else
                log_msg "external gone, falling back to primary-only after reload"
                bash "$PROFILE_DIR/primary-only.sh" >/dev/null 2>>"$LOGFILE"
                set_last_mode "primary-only"
            fi
            ;;
        duplicate)
            if [ -n "$ext_mon" ] && external_monitor_present "$ext_mon"; then
                log_msg "re-applying duplicate after reload"
                bash "$PROFILE_DIR/duplicate.sh" >/dev/null 2>>"$LOGFILE"
            else
                bash "$PROFILE_DIR/primary-only.sh" >/dev/null 2>>"$LOGFILE"
                set_last_mode "primary-only"
            fi
            ;;
        extend)
            if [ -n "$ext_mon" ] && external_monitor_present "$ext_mon"; then
                log_msg "re-applying extend after reload"
                bash "$PROFILE_DIR/extend.sh" >/dev/null 2>>"$LOGFILE"
            else
                bash "$PROFILE_DIR/primary-only.sh" >/dev/null 2>>"$LOGFILE"
                set_last_mode "primary-only"
            fi
            ;;
        primary-only)
            # hyprland.conf already enabled internal — nothing to fix
            log_msg "primary-only after reload, no action needed"
            ;;
    esac

    clear_layout_flag_later 5
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

        'configreloaded>>'*)
            (
                sleep 0.5
                handle_config_reload
            ) >/dev/null 2>>"$LOGFILE" &
            ;;
    esac
done