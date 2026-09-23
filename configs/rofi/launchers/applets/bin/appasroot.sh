#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

prompt='Applications'
mesg='Administrative applications'

if [[ "$theme" == *type-1* || "$theme" == *type-3* || "$theme" == *type-5* ]]; then
    list_col=1; list_row=5; win_width=400px
else
    list_col=5; list_row=1; win_width=670px
fi

option_1=' Terminal'
option_2=' Files'
option_3=' Editor'
option_4=' Shell'
option_5=' Cancel'

rofi_cmd() {
    rofi -theme-str "window {width: $win_width;}" \
        -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows -theme "$theme"
}

run_cmd() {
    case "$1" in
        --terminal) pkexec env DISPLAY="${DISPLAY:-}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" alacritty & ;;
        --files) pkexec env DISPLAY="${DISPLAY:-}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" thunar & ;;
        --editor) pkexec env DISPLAY="${DISPLAY:-}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" alacritty -e nvim & ;;
        --shell) pkexec env DISPLAY="${DISPLAY:-}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" alacritty -e bash & ;;
    esac
}

chosen="$(printf '%s\n' "$option_1" "$option_2" "$option_3" "$option_4" "$option_5" | rofi_cmd || true)"
case "$chosen" in
    "$option_1") run_cmd --terminal ;;
    "$option_2") run_cmd --files ;;
    "$option_3") run_cmd --editor ;;
    "$option_4") run_cmd --shell ;;
    *) exit 0 ;;
esac
