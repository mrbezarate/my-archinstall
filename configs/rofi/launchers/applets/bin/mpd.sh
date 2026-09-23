#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

if command -v playerctl >/dev/null 2>&1; then
    status="$(playerctl status 2>/dev/null || true)"
    artist="$(playerctl metadata artist 2>/dev/null || true)"
    title="$(playerctl metadata title 2>/dev/null || true)"
else
    status='No playerctl'
    artist=''
    title=''
fi

case "$status" in
    Playing) prompt="$artist"; option_1=' Pause' ;;
    Paused) prompt="$artist"; option_1=' Play' ;;
    *) prompt='Offline'; option_1=' Play' ;;
esac
mesg="${title:-No active media player}"

if [[ "$theme" == *type-1* || "$theme" == *type-3* || "$theme" == *type-5* ]]; then
    list_col=1; list_row=6
else
    list_col=6; list_row=1
fi

layout="$(grep 'USE_ICON' "$theme" | cut -d'=' -f2)"
if [[ "$layout" == NO ]]; then
    [[ "$status" == Playing ]] && option_1=' Pause' || option_1=' Play'
    option_2=' Stop'; option_3=' Previous'; option_4=' Next'; option_5=' Repeat'; option_6=' Shuffle'
else
    [[ "$status" == Playing ]] && option_1='' || option_1=''
    option_2=''; option_3=''; option_4=''; option_5=''; option_6=''
fi

rofi_cmd() {
    rofi -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -theme-str 'textbox-prompt-colon {str: "";}' \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows \
        -theme "$theme"
}

run_cmd() {
    case "$1" in
        --opt1) playerctl play-pause ;;
        --opt2) playerctl stop ;;
        --opt3) playerctl previous ;;
        --opt4) playerctl next ;;
        --opt5) playerctl loop Track ;;
        --opt6) playerctl shuffle Toggle ;;
    esac
}

chosen="$(printf '%s\n' "$option_1" "$option_2" "$option_3" "$option_4" "$option_5" "$option_6" | rofi_cmd || true)"
case "$chosen" in
    "$option_1") run_cmd --opt1 ;;
    "$option_2") run_cmd --opt2 ;;
    "$option_3") run_cmd --opt3 ;;
    "$option_4") run_cmd --opt4 ;;
    "$option_5") run_cmd --opt5 ;;
    "$option_6") run_cmd --opt6 ;;
esac
