#!/usr/bin/env bash
set -Eeuo pipefail

USER_NAME="${TARGET_USER:-${SUDO_USER:-}}"
HOME_DIR="${TARGET_HOME:-}"
[[ -n "$USER_NAME" ]] || USER_NAME="$(logname 2>/dev/null || true)"
[[ -n "$HOME_DIR" ]] || HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"

ok=0
bad=0
check_cmd() {
    local label="$1" cmd="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  [OK] %s -> %s\n' "$label" "$(command -v "$cmd")"
        ((ok+=1)) || true
    else
        printf '  [!!] %s -> %s missing\n' "$label" "$cmd"
        ((bad+=1)) || true
    fi
}
check_pkg() {
    local pkg="$1"
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        printf '  [OK] package %-24s %s\n' "$pkg" "$(pacman -Q "$pkg")"
        ((ok+=1)) || true
    else
        printf '  [!!] package %-24s NOT INSTALLED\n' "$pkg"
        ((bad+=1)) || true
    fi
}
check_unit() {
    local unit="$1"
    if systemctl is-enabled "$unit" >/dev/null 2>&1; then
        printf '  [OK] service %s enabled\n' "$unit"
        ((ok+=1)) || true
    else
        printf '  [!!] service %s not enabled\n' "$unit"
        ((bad+=1)) || true
    fi
}

echo '--- command checks ---'
for pair in \
    'Niri:niri' 'Waybar:waybar' 'Rofi:rofi' 'Alacritty:alacritty' \
    'SwayNC:swaync' 'Hyprlock:hyprlock' 'Cliphist:cliphist' \
    'PipeWire:pw-cli' 'NetworkManager:nmcli' 'Virt-manager:virt-manager' \
    'Virsh:virsh' 'Wireshark:wireshark' 'NVIDIA:nvidia-smi' 'Prime:prime-run' \
    'Brightness:brightnessctl' 'Playerctl:playerctl' 'jq:jq' \
    'HTOP:htop' 'Powertop:powertop' 'Neovim:nvim' 'Firefox:firefox' \
    'Nwg-look:nwg-look' 'Screenshot:wl-copy'; do
    label="${pair%%:*}"; cmd="${pair#*:}"; check_cmd "$label" "$cmd"
done

echo '--- package checks ---'
for pkg in niri waybar swaync rofi hyprlock hypridle pipewire pipewire-audio pipewire-pulse \
           wireplumber networkmanager sddm power-profiles-daemon libvirt virt-manager \
           qemu-desktop wireshark-qt nvidia-open-dkms nvidia-utils lib32-nvidia-utils \
           firefox neovim htop powertop xdg-user-dirs nwg-look; do
    check_pkg "$pkg"
done

echo '--- service checks ---'
for unit in NetworkManager.service bluetooth.service power-profiles-daemon.service libvirtd.service sddm.service; do
    check_unit "$unit"
done

if [[ -f "$HOME_DIR/.config/niri/config.kdl" ]]; then
    if grep -q '/home/xal' "$HOME_DIR/.config/niri/config.kdl"; then
        echo '  [!!] Niri config still contains /home/xal'
        ((bad+=1)) || true
    else
        echo '  [OK] Niri config has no hardcoded /home/xal'
        ((ok+=1)) || true
    fi
fi

if [[ -f "$HOME_DIR/.config/rofi/launchers/type-7/launcher.sh" && -f "$HOME_DIR/.config/rofi/launchers/applets/shared/theme.bash" ]]; then
    echo '  [OK] Rofi launcher + applet theme paths exist'
    ((ok+=1)) || true
else
    echo '  [!!] Rofi applet theme path is missing'
    ((bad+=1)) || true
fi

echo '--- deployed config sanity ---'
if grep -RIlE 'rofi-wayland|nvidia-dkms|future-dark-cursors|~/scripts/|(\/home\/xal)|amixer|mpc -q|xfce4-power-manager-settings|betterlockscreen|maim|xrandr' \
       "$HOME_DIR/.config/niri" "$HOME_DIR/.config/waybar" "$HOME_DIR/.config/swaync" "$HOME_DIR/.config/rofi" >/tmp/my-archinstall-stale.txt 2>/dev/null; then
    echo '  [!!] Stale/obsolete references found:'
    sed 's/^/       /' /tmp/my-archinstall-stale.txt
    rm -f /tmp/my-archinstall-stale.txt
    ((bad+=1)) || true
else
    echo '  [OK] No obsolete package/X11 references in deployed UI config'
    rm -f /tmp/my-archinstall-stale.txt
    ((ok+=1)) || true
fi

echo
printf 'Verification: %d OK, %d problems\n' "$ok" "$bad"
if ((bad > 0)); then
    exit 1
fi
