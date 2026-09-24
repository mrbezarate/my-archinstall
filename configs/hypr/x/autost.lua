-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

local home = os.getenv("HOME") or "/home/" .. (os.getenv("USER") or "alex")

hl.on("hyprland.start", function ()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("swaybg -m fill -i " .. home .. "/Pictures/Wallpapers/wallpaper.png")
    hl.exec_cmd("sh -c '/usr/lib/mate-polkit/polkit-mate-authentication-agent-1 || /usr/libexec/polkit-mate-authentication-agent-1'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("bluetoothctl power on")
    hl.exec_cmd(home .. "/.config/hypr/scripts/upbat.sh")
end)
