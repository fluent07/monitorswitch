#!/bin/bash

# ===== User-specific monitor settings =====
INTERNAL_MONITOR="eDP-1"
INTERNAL_MODE="1920x1080@144"
INTERNAL_POS="0x0"
INTERNAL_SCALE="1"

# Duplicate mode uses a safe common resolution
DUPLICATE_MODE="1920x1080@144"

# Extend places the external to the right of the laptop panel
EXTEND_POS="1920x0"
EXTERNAL_SCALE="1"

# ===== Shared state =====
MONITOR_DIR="$HOME/.config/hypr/monitors"
PROFILE_DIR="$MONITOR_DIR/profiles"

STATE_FILE="$MONITOR_DIR/.last-mode"
CURRENT_EXTERNAL="$MONITOR_DIR/.current-external"

IGNORE_FILE="/tmp/hypr-ignore-monitor-removes"
LOCKFILE="/tmp/hypr-monitor-menu.lock"
LOGFILE="/tmp/hypr-watch-auto.log"
LAYOUT_FLAG="/tmp/hypr-monitor-layout-changing"

# ===== Helpers =====
log_msg() {
    printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOGFILE"
}

ensure_runtime_files() {
    touch "$IGNORE_FILE"
}

is_internal_monitor() {
    [[ "$1" =~ ^(eDP|LVDS) ]]
}

is_fake_monitor() {
    [[ "$1" = "FALLBACK" ]]
}

set_layout_flag() {
    touch "$LAYOUT_FLAG"
}

clear_layout_flag_later() {
    (
        sleep "${1:-3}"
        rm -f "$LAYOUT_FLAG"
    ) >/dev/null 2>&1 &
}

layout_change_active() {
    [ -f "$LAYOUT_FLAG" ]
}

remember_external() {
    local mon="$1"
    [ -n "$mon" ] && printf '%s\n' "$mon" > "$CURRENT_EXTERNAL"
}

get_current_external() {
    cat "$CURRENT_EXTERNAL" 2>/dev/null
}

set_last_mode() {
    local mode="$1"
    [ -n "$mode" ] && printf '%s\n' "$mode" > "$STATE_FILE"
}

add_ignored_remove() {
    local mon="$1"
    grep -qx "$mon" "$IGNORE_FILE" 2>/dev/null || printf '%s\n' "$mon" >> "$IGNORE_FILE"
}

is_ignored_remove() {
    local mon="$1"
    grep -qx "$mon" "$IGNORE_FILE" 2>/dev/null
}

consume_ignored_remove() {
    local mon="$1"
    grep -vx "$mon" "$IGNORE_FILE" > "${IGNORE_FILE}.tmp" 2>/dev/null || true
    mv -f "${IGNORE_FILE}.tmp" "$IGNORE_FILE"
}

get_connected_external_monitors() {
    hyprctl monitors | awk '/^Monitor /{print $2}' | grep -Ev '^(eDP|LVDS)' || true
}

external_monitor_present() {
    local mon="$1"
    [ -n "$mon" ] && hyprctl monitors | awk '/^Monitor /{print $2}' | grep -qx "$mon"
}

first_connected_external() {
    get_connected_external_monitors | head -n1
}
