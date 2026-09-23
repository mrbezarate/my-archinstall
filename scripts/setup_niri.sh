#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "[!] Run this script through install.sh or with sudo."
    exit 1
fi

ACTUAL_USER="${TARGET_USER:-${SUDO_USER:-}}"
TARGET_HOME="${TARGET_HOME:-}"
if [[ -z "$ACTUAL_USER" || "$ACTUAL_USER" == root ]] || ! getent passwd "$ACTUAL_USER" >/dev/null; then
    echo "[!] Normal target user could not be determined."
    exit 1
fi
[[ -n "$TARGET_HOME" ]] || TARGET_HOME="$(getent passwd "$ACTUAL_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/configs"

log() { printf '\033[0;36m[*]\033[0m %s\n' "$*"; }

log "Installing desktop/session packages"
pacman -S --needed --noconfirm \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    pavucontrol \
    bluez \
    bluez-utils \
    networkmanager \
    network-manager-applet \
    nm-connection-editor \
    power-profiles-daemon \
    libnotify \
    sddm \
    polkit \
    qt6-5compat \
    qt6-declarative \
    qt6-svg \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-gnome

log "Installing Niri/Wayland UI"
pacman -S --needed --noconfirm \
    niri \
    xwayland-satellite \
    waybar \
    swaync \
    rofi-wayland \
    swaybg \
    hyprlock \
    hypridle \
    wl-clipboard \
    cliphist \
    brightnessctl \
    playerctl \
    alacritty \
    zsh \
    thunar \
    thunar-archive-plugin \
    file-roller \
    firefox \
    neovim \
    htop \
    powertop \
    xdg-user-dirs \
    nwg-look \
    mate-polkit \
    fastfetch \
    jq \
    curl \
    git \
    starship \
    xcursor-themes \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-font-awesome

systemctl enable --now NetworkManager.service 2>/dev/null || true
systemctl enable --now bluetooth.service 2>/dev/null || true
systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true

# ASUS tools (asusctl): attempt official repository or AUR fallback without aborting on network errors
install_asus_tools() {
    log "Configuring ASUS ROG utilities..."
    local key='8F654886F17D497FEFE3DB448B15A6B0E9A3FA35'
    pacman-key --init 2>/dev/null || true
    
    if pacman-key --recv-key "$key" 2>/dev/null && pacman-key --lsign-key "$key" 2>/dev/null; then
        if ! grep -q '^\[ogc\]$' /etc/pacman.conf; then
            cat >> /etc/pacman.conf <<'EOF'

[ogc]
Server = https://pacman.opengamingcollective.org
EOF
        fi
        pacman -Sy --needed --noconfirm asusctl rog-control-center 2>/dev/null || true
    else
        log "Warning: ASUS OGC key import skipped; you can install asusctl later from AUR."
    fi
    
    if systemctl list-unit-files asusd.service 2>/dev/null | grep -q '^asusd.service'; then
        systemctl enable asusd.service 2>/dev/null || true
    fi
}
install_asus_tools || true

log "Deploying configuration to $TARGET_HOME/.config"
install -d -o "$ACTUAL_USER" -g "$ACTUAL_USER" "$TARGET_HOME/.config"

cp -a "$CONFIG_SOURCE"/niri "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/waybar "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/swaync "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/rofi "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/alacritty "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/fastfetch "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/starship.toml "$TARGET_HOME/.config/"

# Also deploy hyprlock and hypridle configs
if [[ -d "$CONFIG_SOURCE/hypr" ]]; then
    cp -a "$CONFIG_SOURCE"/hypr "$TARGET_HOME/.config/"
    # Fix lock command in hypridle so lock works reliably
    if [[ -f "$TARGET_HOME/.config/hypr/hypridle.conf" ]]; then
        sed -i 's|pidof hyprlock|pidof hyprlock \|\| hyprlock|g' "$TARGET_HOME/.config/hypr/hypridle.conf"
    fi
fi

# Import bundled fonts
FONT_HOME="$TARGET_HOME/.local/share/fonts"
install -d "$FONT_HOME"
if [[ -d "$CONFIG_SOURCE/hypr/Fonts" ]]; then
    find "$CONFIG_SOURCE/hypr/Fonts" -type f \
        \( -iname '*.otf' -o -iname '*.ttf' \) -exec cp -f {} "$FONT_HOME/" \;
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$FONT_HOME"
    sudo -u "$ACTUAL_USER" fc-cache -f >/dev/null 2>&1 || true
fi

log "Installing aesthetic wallpaper"
WALLPAPER_DIR="$TARGET_HOME/Pictures/Wallpapers"
install -d "$WALLPAPER_DIR"
if [[ -f "$SCRIPT_DIR/assets/wallpaper.png" ]]; then
    cp -f "$SCRIPT_DIR/assets/wallpaper.png" "$WALLPAPER_DIR/wallpaper.png"
elif [[ -f "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" ]]; then
    cp -f "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" "$WALLPAPER_DIR/wallpaper.png"
fi

# Adapt all text configs: replace /home/xal with target home
while IFS= read -r -d '' file; do
    sed -i \
        -e "s|/home/xal|$TARGET_HOME|g" \
        -e 's|\.config/rofi/applets|.config/rofi/launchers/applets|g' \
        "$file"
done < <(find "$TARGET_HOME/.config" -type f \
    \( -name '*.kdl' -o -name '*.json' -o -name '*.jsonc' -o -name '*.rasi' \
       -o -name '*.sh' -o -name '*.bash' -o -name '*.css' -o -name '*.toml' -o -name '*.conf' \) -print0)

# Set correct wallpaper path in niri config cleanly without doubling
if [[ -f "$TARGET_HOME/.config/niri/config.kdl" ]]; then
    sed -i "s|swaybg.*|swaybg\" \"-m\" \"fill\" \"-i\" \"$WALLPAPER_DIR/wallpaper.png\"|g" "$TARGET_HOME/.config/niri/config.kdl"
    # Ensure polkit path is valid on Arch
    if [[ ! -f /usr/libexec/polkit-mate-authentication-agent-1 && -f /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 ]]; then
        sed -i 's|/usr/libexec/polkit-mate-authentication-agent-1|/usr/lib/mate-polkit/polkit-mate-authentication-agent-1|g' "$TARGET_HOME/.config/niri/config.kdl"
    fi
fi

# Remove stale waybar entries cleanly with multiple -e flags
WAYBAR="$TARGET_HOME/.config/waybar/modules.json"
if [[ -f "$WAYBAR" ]]; then
    sed -i \
        -e '/"on-scroll-right": "~\/scripts\/wall\.sh"/d' \
        -e '/"on-click-right": "~\/scripts\/cycle_tuned\.sh"/d' \
        -e '/"on-click-right": "~\/scripts\/mono\.sh"/d' \
        -e '/"on-scroll-up": "~\/scripts\/planner\.sh up"/d' \
        -e '/"on-scroll-down": "~\/scripts\/planner\.sh down"/d' \
        "$WAYBAR"
fi

# Setup Starship prompt in ~/.bashrc if not present
BASHRC="$TARGET_HOME/.bashrc"
if [[ -f "$BASHRC" ]] && ! grep -q 'starship init bash' "$BASHRC"; then
    echo 'eval "$(starship init bash)"' >> "$BASHRC"
fi

# Sanitize ownership and permissions
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_HOME/.config" "$TARGET_HOME/Pictures"
find "$TARGET_HOME/.config" -type f -name '*.sh' -exec chmod 0755 {} +

log "Niri/UI setup complete."