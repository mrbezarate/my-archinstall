#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##



# Get id of an active window
active_pid=$(hyprctl activewindow | grep -o 'pid: [0-9]*' | cut -d' ' -f2)

# Close active window
[ -n "$active_pid" ] && kill -15 "$active_pid" 2>/dev/null