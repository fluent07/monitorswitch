#!/bin/bash

# ===== Shared state =====
# (defined early so detect_internal_monitor can use MONITOR_DIR and LOGFILE)
MONITOR_DIR="$HOME/.config/hypr/monitors"
PROFILE_DIR="$MONITOR_DIR/profiles"

STATE_FILE="$MONITOR_DIR/.last-mode"
CURRENT_EXTERNAL="$MONITOR_DIR/.current-external"
DETECTED_FILE="$MONITOR_DIR/.detected-internal"

IGNORE_FILE="/tmp/hypr-ignore-monitor-removes"
LOCKFILE="/tmp/hypr-monitor-menu.lock"
LOGFILE="/tmp/hypr-watch-auto.log"
LAYOUT_FLAG="/tmp/hypr-monitor-layout-changing"

# ===== Helpers (needed before detection) =====
log_msg() {
    printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOGFILE"
}

# ===== Internal monitor detection =====
detect_internal_monitor() {
    local json name width height refresh x y scale mode pos

    json="$(hyprctl -j monitors 2>/dev/null)"
    [ -z "$json" ] && return 1

    name=$(printf '%s' "$json" | python3 -c "
import json,sys
for m in json.load(sys.stdin):
    if m['name'].startswith(('eDP','LVDS')):
        print(m['name']); break
")
    [ -z "$name" ] && return 1

    read -r width height refresh x y scale < <(printf '%s' "$json" | python3 -c "
import json,sys
for m in json.load(sys.stdin):
    if m['name'] == '$name':
        print(m['width'], m['height'], int(round(m['refreshRate'])), m['x'], m['y'], int(m['scale']))
        break
")

    mode="${width}x${height}@${refresh}"
    pos="${x}x${y}"

    cat > "$DETECTED_FILE" << EOF
INTERNAL_MONITOR="$name"
INTERNAL_MODE="$mode"
INTERNAL_POS="$pos"
INTERNAL_SCALE="$scale"
EOF

    log_msg "detected internal monitor: $name $mode pos=$pos scale=$scale"
    return 0
}

# Load from cache if available, otherwise detect and cache
if [ -f "$DETECTED_FILE" ]; then
    source "$DETECTED_FILE"
else
    detect_internal_monitor
    [ -f "$DETECTED_FILE" ] && source "$DETECTED_FILE"
fi

# Final fallback if detection failed (internal monitor was disabled at source time)
INTERNAL_MONITOR="${INTERNAL_MONITOR:-eDP-1}"
INTERNAL_MODE="${INTERNAL_MODE:-1920x1080@144}"
INTERNAL_POS="${INTERNAL_POS:-0x0}"
INTERNAL_SCALE="${INTERNAL_SCALE:-1}"

# Duplicate mode uses a safe common resolution
DUPLICATE_MODE="$INTERNAL_MODE"
# Extend places the external to the right of the laptop panel
EXTEND_POS="${INTERNAL_MODE%%x*}x0"
EXTERNAL_SCALE="1"

# ===== Helpers =====
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

set_internal_enabled() {
    printf 'INTERNAL_ENABLED=%s\n' "$1" > "$MONITOR_DIR/settings.conf"
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