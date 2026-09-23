#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

prompt='Applications'
mesg="Installed Packages: $(pacman -Q 2>/dev/null | wc -l)"

if [[ "$theme" == *type-1* || "$theme" == *type-3* || "$theme" == *type-5* ]]; then
    list_col=1; list_row=6
else
    list_col=6; list_row=1
fi

option_1=" Terminal"
option_2=" Files"
option_3=" Editor"
option_4=" Browser"
option_5=" Music"
option_6=" Settings"

rofi_cmd() {
    rofi -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows -theme "$theme"
}

run_cmd() {
    case "$1" in
        --terminal) alacritty & ;;
        --files) thunar & ;;
        --editor) alacritty -e nvim & ;;
        --browser) firefox & ;;
        --music) playerctl play-pause 2>/dev/null || notify-send -u low "Media" "No active player" ;;
        --settings) nwg-look & ;;
    esac
}

chosen="$(printf '%s\n' "$option_1" "$option_2" "$option_3" "$option_4" "$option_5" "$option_6" | rofi_cmd || true)"
case "$chosen" in
    "$option_1") run_cmd --terminal ;;
    "$option_2") run_cmd --files ;;
    "$option_3") run_cmd --editor ;;
    "$option_4") run_cmd --browser ;;
    "$option_5") run_cmd --music ;;
    "$option_6") run_cmd --settings ;;
esac
