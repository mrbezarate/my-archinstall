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

pacman_install() {
    if pacman -S --needed --noconfirm "$@"; then
        return 0
    fi
    log "Bulk install encountered an issue. Refreshing database and retrying..."
    pacman -Sy --noconfirm 2>/dev/null || true
    if pacman -S --needed --noconfirm "$@"; then
        return 0
    fi
    log "Installing packages individually..."
    for pkg in "$@"; do
        pacman -S --needed --noconfirm "$pkg" 2>/dev/null || log "Note: package $pkg skipped or already satisfied."
    done
    return 0
}

log "Installing desktop/session packages"
pacman_install \
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

log "Installing Hyprland / Wayland UI (xarefin rice)"
pacman_install \
    hyprland \
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
    zsh \
    thunar \
    thunar-archive-plugin \
    file-roller \
    firefox \
    neovim \
    htop \
    btop \
    powertop \
    xdg-user-dirs \
    nwg-look \
    mate-polkit \
    fastfetch \
    kitty \
    wlogout \
    lua \
    cava \
    jq \
    curl \
    git \
    starship \
    xcursor-themes \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    woff2-font-awesome

# Build wlogout from upstream source (it is an AUR package not present in official repos)
if ! command -v wlogout >/dev/null 2>&1; then
    log "Compiling wlogout from source..."
    pacman -S --needed --noconfirm meson ninja scdoc gtk3 gtk-layer-shell 2>/dev/null || true
    rm -rf /tmp/wlogout
    if git clone --depth 1 https://github.com/ArtsyMacaw/wlogout.git /tmp/wlogout 2>/dev/null; then
        (cd /tmp/wlogout && meson setup build --prefix=/usr && ninja -C build install) 2>/dev/null || true
        rm -rf /tmp/wlogout
    fi
fi

systemctl enable --now NetworkManager.service 2>/dev/null || true
systemctl enable --now bluetooth.service 2>/dev/null || true
systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true

log "Configuring SDDM Display Manager (Default session: Hyprland, cursor: visible)"
install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-session.conf <<'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors

[Users]
DefaultSession=hyprland.desktop
EOF

# If Breeze theme is available, use our beautiful wallpaper in SDDM login screen
if [[ -d /usr/share/sddm/themes/breeze && -f "$SCRIPT_DIR/assets/wallpaper.png" ]]; then
    cp -f "$SCRIPT_DIR/assets/wallpaper.png" /usr/share/sddm/themes/breeze/wallpaper.png 2>/dev/null || true
fi

# ASUS tools (asusctl): attempt official repository or AUR fallback without aborting on network errors
install_asus_tools() {
    log "Configuring ASUS ROG utilities..."
    pacman-key --init 2>/dev/null || true
    
    # Import and sign both official ASUS OGC keys
    local keys=('8F654886F17D497FEFE3DB448B15A6B0E9A3FA35' 'EE2BAD4D46522D3D15BF4849B51CCBABCFF928FA')
    for k in "${keys[@]}"; do
        pacman-key --recv-key "$k" 2>/dev/null || true
        pacman-key --lsign-key "$k" 2>/dev/null || true
    done

    if ! grep -q '^\[ogc\]$' /etc/pacman.conf; then
        cat >> /etc/pacman.conf <<'EOF'

[ogc]
SigLevel = Optional TrustAll
Server = https://pacman.opengamingcollective.org
EOF
    else
        if ! grep -A 2 '^\[ogc\]$' /etc/pacman.conf | grep -q 'SigLevel'; then
            sed -i '/^\[ogc\]$/a SigLevel = Optional TrustAll' /etc/pacman.conf
        fi
    fi
    pacman -Sy --needed --noconfirm asusctl rog-control-center 2>/dev/null || true
}
install_asus_tools || true

log "Deploying configuration to $TARGET_HOME/.config"
install -d -o "$ACTUAL_USER" -g "$ACTUAL_USER" "$TARGET_HOME/.config"

cp -a "$CONFIG_SOURCE"/waybar "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/swaync "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/rofi "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/alacritty "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/fastfetch "$TARGET_HOME/.config/"
cp -a "$CONFIG_SOURCE"/starship.toml "$TARGET_HOME/.config/"

if [[ -d "$CONFIG_SOURCE/btop" ]]; then
    cp -a "$CONFIG_SOURCE"/btop "$TARGET_HOME/.config/"
fi
if [[ -d "$CONFIG_SOURCE/cava" ]]; then
    cp -a "$CONFIG_SOURCE"/cava "$TARGET_HOME/.config/"
fi

# Also deploy hyprland, hyprlock, and hypridle configs (full xarefin rice)
if [[ -d "$CONFIG_SOURCE/hypr" ]]; then
    cp -a "$CONFIG_SOURCE"/hypr "$TARGET_HOME/.config/"
    if [[ -f "$TARGET_HOME/.config/hypr/hypridle.conf" ]]; then
        sed -i 's|pidof hyprlock|pidof hyprlock \|\| hyprlock|g' "$TARGET_HOME/.config/hypr/hypridle.conf"
    fi
fi

# Deploy wlogout, wlogout-img and kitty
if [[ -d "$CONFIG_SOURCE/wlogout" ]]; then
    cp -a "$CONFIG_SOURCE"/wlogout "$TARGET_HOME/.config/"
fi
if [[ -d "$CONFIG_SOURCE/wlogout-img" ]]; then
    cp -a "$CONFIG_SOURCE"/wlogout-img "$TARGET_HOME/.config/"
fi
if [[ -d "$CONFIG_SOURCE/kitty" ]]; then
    cp -a "$CONFIG_SOURCE"/kitty "$TARGET_HOME/.config/"
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

if [[ -d "$SCRIPT_DIR/assets/wallpapers" ]]; then
    cp -a "$SCRIPT_DIR/assets/wallpapers"/* "$WALLPAPER_DIR/" 2>/dev/null || true
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

# Setup Starship prompt in ~/.bashrc if not present
BASHRC="$TARGET_HOME/.bashrc"
if [[ -f "$BASHRC" ]] && ! grep -q 'starship init bash' "$BASHRC"; then
    echo 'eval "$(starship init bash)"' >> "$BASHRC"
fi

# Sanitize ownership and permissions across entire user home directory
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_HOME"
find "$TARGET_HOME/.config" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 0755 {} +
chmod 0700 "$TARGET_HOME"

log "Hyprland UI setup complete."