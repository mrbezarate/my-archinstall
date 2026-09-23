#!/usr/bin/env bash
set -Eeuo pipefail

source "$HOME/.config/rofi/launchers/applets/shared/theme.bash"
theme="$type/$style"

get_sink_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2 * 100)}'
}
get_source_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print int($2 * 100)}'
}
sink_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q '\[MUTED\]'
}
source_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q '\[MUTED\]'
}

speaker="$(get_sink_volume || echo 0)"
mic="$(get_source_volume || echo 0)"
if sink_muted; then stext='Muted'; sicon=''; else stext='Unmuted'; sicon=''; fi
if source_muted; then mtext='Muted'; micon=''; else mtext='Unmuted'; micon=''; fi

prompt="S:$stext, M:$mtext"
mesg="PipeWire - Speaker: ${speaker}%, Mic: ${mic}%"

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
    option_1=" Increase"
    option_2="$sicon $stext"
    option_3=" Decrease"
    option_4="$micon $mtext"
    option_5=" Settings"
else
    option_1=""; option_2="$sicon"; option_3=""; option_4="$micon"; option_5=""
fi

rofi_cmd() {
    rofi -theme-str "window {width: $win_width;}" \
        -theme-str "listview {columns: $list_col; lines: $list_row;}" \
        -theme-str 'textbox-prompt-colon {str: "";}' \
        -dmenu -p "$prompt" -mesg "$mesg" -markup-rows \
        -theme "$theme"
}

run_cmd() {
    case "$1" in
        --opt1) wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
        --opt2) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
        --opt3) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
        --opt4) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
        --opt5) pavucontrol ;;
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
