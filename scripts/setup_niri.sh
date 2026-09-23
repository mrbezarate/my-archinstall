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
    rofi \
    swaybg \
    hyprlock \
    hypridle \
    wl-clipboard \
    cliphist \
    brightnessctl \
    playerctl \
    alacritty \
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

systemctl enable --now NetworkManager.service
systemctl enable --now bluetooth.service
systemctl enable --now power-profiles-daemon.service
systemctl enable sddm.service

# The ASUS Linux project currently recommends its official OGC repository for
# packaged ASUS utilities rather than relying on an AUR build for core daemons.
install_asus_repo() {
    local key='8F654886F17D497FEFE3DB448B15A6B0E9A3FA35'
    pacman-key --init

    if ! pacman-key --list-keys "$key" >/dev/null 2>&1; then
        log "Importing the official ASUS Linux/OGC repository key"
        pacman-key --recv-key "$key"
        pacman-key --lsign-key "$key"
    fi

    if ! grep -q '^\[ogc\]$' /etc/pacman.conf; then
        log "Adding the official ASUS Linux/OGC repository"
        cat >> /etc/pacman.conf <<'EOF'

[ogc]
Server = https://pacman.opengamingcollective.org
EOF
    elif ! awk '/^\[ogc\]$/{f=1; next} /^\[/{f=0} f && /^Server[[:space:]]*=/{ok=1} END{exit ok?0:1}' /etc/pacman.conf; then
        log "Repairing the existing [ogc] repository section"
        awk '
            /^\[ogc\]$/ { print; print "Server = https://pacman.opengamingcollective.org"; inserted=1; next }
            /^\[/ && inserted { print; inserted=0; next }
            { print }
            END { if (!inserted) exit 0 }
        ' /etc/pacman.conf > /tmp/pacman.conf.fixed
        mv /tmp/pacman.conf.fixed /etc/pacman.conf
    fi

    pacman -Syu --needed --noconfirm
}

if install_asus_repo; then
    log "Installing ASUS ROG control tools"
    pacman -S --needed --noconfirm asusctl rog-control-center
    if systemctl list-unit-files asusd.service | grep -q '^asusd.service'; then
        systemctl enable --now asusd.service
    fi
else
    echo "[!] Official ASUS repository setup failed; ASUS utilities are NOT silently skipped."
    echo "[!] Re-run after fixing pacman-key/network and the rest of the setup remains usable."
    exit 1
fi

# supergfxctl is currently being phased out. It is not needed for ordinary Wayland
# multi-GPU use; install it only when explicitly requested (e.g. VFIO experiments).
if [[ "${INSTALL_SUPERGFXCTL:-0}" == 1 ]]; then
    log "Installing explicitly requested supergfxctl"
    pacman -S --needed --noconfirm supergfxctl
    systemctl enable --now supergfxd.service
fi

log "Deploying configuration to $TARGET_HOME/.config"
install -d -o "$ACTUAL_USER" -g "$ACTUAL_USER" "$TARGET_HOME/.config"
cp -a "$CONFIG_SOURCE"/niri "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/waybar "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/swaync "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/rofi "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/alacritty "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/fastfetch "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/starship.toml "$TARGET_HOME/.config/"

# Import the bundled SF Pro / JetBrains fonts.
FONT_HOME="$TARGET_HOME/.local/share/fonts"
install -d "$FONT_HOME"
find "$CONFIG_SOURCE/hypr/Fonts" -type f \
    \( -iname '*.otf' -o -iname '*.ttf' \) -exec cp -f {} "$FONT_HOME/" \;
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_HOME/.local/share/fonts"
sudo -u "$ACTUAL_USER" fc-cache -f >/dev/null 2>&1 || true

log "Installing wallpaper"
WALLPAPER_DIR="$TARGET_HOME/Pictures/Wallpapers"
install -d "$WALLPAPER_DIR"
if [[ -f "$SCRIPT_DIR/assets/wallpaper.png" ]]; then
    cp -f "$SCRIPT_DIR/assets/wallpaper.png" "$WALLPAPER_DIR/wallpaper.png"
elif [[ -f "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" ]]; then
    cp -f "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" "$WALLPAPER_DIR/wallpaper.png"
fi

# Adapt all text configs to the actual account. In particular this fixes the old
# /home/xal references in niri, waybar, rofi, and fastfetch.
while IFS= read -r -d '' file; do
    sed -i \
        -e "s|/home/xal|$TARGET_HOME|g" \
        -e 's|\.config/rofi/applets|.config/rofi/launchers/applets|g' \
        "$file"
done < <(find "$TARGET_HOME/.config" -type f \
    \( -name '*.kdl' -o -name '*.json' -o -name '*.jsonc' -o -name '*.rasi' \
       -o -name '*.sh' -o -name '*.bash' -o -name '*.css' -o -name '*.toml' -o -name '*.conf' \) -print0)

# Ensure the wallpaper path is correct even if an old config had a different file.
if [[ -f "$TARGET_HOME/.config/niri/config.kdl" && -f "$WALLPAPER_DIR/wallpaper.png" ]]; then
    sed -i "s|/Downloads/wallhaven-0we3m7_1920x1200.png|/Pictures/Wallpapers/wallpaper.png|g" \
        "$TARGET_HOME/.config/niri/config.kdl"
fi

# Remove stale references to external ~/scripts files from the archived theme.
# These files are not part of this repository and made several Waybar clicks dead.
WAYBAR="$TARGET_HOME/.config/waybar/modules.json"
if [[ -f "$WAYBAR" ]]; then
    sed -i \
        '/"on-scroll-right": "~\/scripts\/wall\.sh"/d' \
        '/"on-click-right": "~\/scripts\/cycle_tuned\.sh"/d' \
        '/"on-click-right": "~\/scripts\/mono\.sh"/d' \
        '/"on-scroll-up": "~\/scripts\/planner\.sh up"/d' \
        '/"on-scroll-down": "~\/scripts\/planner\.sh down"/d' \
        "$WAYBAR"
fi

# Fix Niri startup to use the real wallpaper path and the current native rofi config.
if [[ -f "$TARGET_HOME/.config/niri/config.kdl" ]]; then
    sed -i "s|/Pictures/Wallpapers/wallpaper.png|$WALLPAPER_DIR/wallpaper.png|g" \
        "$TARGET_HOME/.config/niri/config.kdl"
fi

# Sanitize ownership/permissions for all deployed user configs.
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_HOME/.config" "$TARGET_HOME/Pictures"
find "$TARGET_HOME/.config" -type f -name '*.sh' -exec chmod 0755 {} +

log "Niri/UI setup complete"
log "Use 'systemctl status sddm' and select the Niri session after reboot."
