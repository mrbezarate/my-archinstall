#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

prompt='Screenshot'
mesg='Niri native screenshot actions'

if [[ "$theme" == *type-1* ]]; then
    list_col=1; list_row=5; win_width=400px
elif [[ "$theme" == *type-3* ]]; then
    list_col=1; list_row=5; win_width=120px
elif [[ "$theme" == *type-5* ]]; then
    list_col=1; list_row=5; win_width=520px
else
    list_col=5; list_row=1; win_width=670px
fi

layout="$(grep 'USE_ICON' "$theme" | cut -d'=' -f2)"
if [[ "$layout" == NO ]]; then
    option_1=' Screen / interactive'
    option_2=' Window'
    option_3=' Screen now'
    option_4=' Screen in 5s'
    option_5=' Screen in 10s'
else
    option_1=''; option_2=''; option_3=''; option_4=''; option_5=''
fi

rofi_cmd() {
    rofi -theme-str "window {width: $win_width;}" \
        -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -theme-str 'textbox-prompt-colon {str: "";}' \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows \
        -theme "$theme"
}

run_cmd() {
    case "$1" in
        --opt1|--opt3) niri msg action screenshot ;;
        --opt2) niri msg action screenshot-window ;;
        --opt4)
            sleep 5
            niri msg action screenshot
            ;;
        --opt5)
            sleep 10
            niri msg action screenshot
            ;;
    esac
}

chosen="$(printf '%s\n' "$option_1" "$option_2" "$option_3" "$option_4" "$option_5" | rofi_cmd || true)"
case "$chosen" in
    "$option_1") run_cmd --opt1 ;;
    "$option_2") run_cmd --opt2 ;;
    "$option_3") run_cmd --opt3 ;;
    "$option_4") run_cmd --opt4 ;;
    "$option_5") run_cmd --opt5 ;;
esac
