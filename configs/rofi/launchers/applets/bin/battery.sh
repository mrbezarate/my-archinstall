#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

batdir="$(find /sys/class/power_supply -maxdepth 1 -type l -name 'BAT*' | sort | head -n1 || true)"
status='Unknown'
percentage=0
battery='Battery'
if [[ -n "$batdir" ]]; then
    [[ -r "$batdir/status" ]] && status="$(cat "$batdir/status")"
    [[ -r "$batdir/capacity" ]] && percentage="$(cat "$batdir/capacity")"
    battery="$(basename "$batdir")"
fi

prompt="$status"
mesg="${battery}: ${percentage}%"

if [[ "$theme" == *type-1* ]]; then
    list_col=1; list_row=4; win_width=400px
elif [[ "$theme" == *type-3* ]]; then
    list_col=1; list_row=4; win_width=120px
elif [[ "$theme" == *type-5* ]]; then
    list_col=1; list_row=4; win_width=500px
else
    list_col=4; list_row=1; win_width=550px
fi

if [[ "$status" == Charging* || "$status" == Full ]]; then
    ICON=""
else
    ICON=""
fi

layout="$(grep 'USE_ICON' "$theme" | cut -d'=' -f2)"
if [[ "$layout" == NO ]]; then
    option_1=" Remaining ${percentage}%"
    option_2=" $status"
    option_3=" Power profiles"
    option_4=" Power statistics"
else
    option_1="$ICON"
    option_2=""
    option_3=""
    option_4=""
fi

rofi_cmd() {
    rofi -theme-str "window {width: $win_width;}" \
        -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -theme-str "textbox-prompt-colon {str: \"$ICON\";}" \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows \
        -theme "$theme"
}

run_cmd() {
    case "$1" in
        --opt1) notify-send -u low "Battery" "${percentage}%" ;;
        --opt2) notify-send -u low "Battery" "$status" ;;
        --opt3) command -v rog-control-center >/dev/null 2>&1 && rog-control-center || true ;;
        --opt4)
            if command -v powertop >/dev/null 2>&1; then
                alacritty -e powertop
            else
                notify-send -u low "Battery" "Install powertop for power diagnostics."
            fi
            ;;
    esac
}

chosen="$(printf '%s\n' "$option_1" "$option_2" "$option_3" "$option_4" | rofi_cmd || true)"
case "$chosen" in
    "$option_1") run_cmd --opt1 ;;
    "$option_2") run_cmd --opt2 ;;
    "$option_3") run_cmd --opt3 ;;
    "$option_4") run_cmd --opt4 ;;
esac
