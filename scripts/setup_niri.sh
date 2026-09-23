#!/bin/bash
set -e

echo "=========================================="
echo " [3/3] Setting up Niri, traits-configs & UI"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo or as root"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
if [ "$ACTUAL_USER" = "root" ]; then
    echo "[!] Warning: Script running directly as root. Please specify target username:"
    read -p "Username: " TARGET_USER
    ACTUAL_USER="$TARGET_USER"
fi

TARGET_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
echo "[*] Target user: $ACTUAL_USER (Home: $TARGET_HOME)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Install Audio, Bluetooth, Network, Display Manager & Tools
echo "[*] Installing desktop essentials..."
pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    pavucontrol \
    bluez \
    bluez-utils \
    networkmanager \
    sddm \
    qt6-5compat \
    qt6-declarative \
    qt6-svg

# Enable Audio, Bluetooth, Network and SDDM
systemctl enable --now NetworkManager.service 2>/dev/null || true
systemctl enable --now bluetooth.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true

# 2. Install Niri and Wayland components
echo "[*] Installing Niri compositor and GUI tools..."
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
    thunar \
    thunar-archive-plugin \
    file-roller \
    mate-polkit \
    fastfetch \
    starship \
    xcursor-themes \
    ttf-jetbrains-mono-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-font-awesome

# 3. Install YAY (AUR Helper) if missing
if ! sudo -u "$ACTUAL_USER" which yay &>/dev/null; then
    echo "[*] Installing 'yay' AUR helper..."
    rm -rf /tmp/yay-bin
    sudo -u "$ACTUAL_USER" git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    sudo -u "$ACTUAL_USER" makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf /tmp/yay-bin
fi

# 4. Install AUR Packages (ASUS ROG controls & Quickshell)
echo "[*] Installing ASUS ROG utilities from AUR..."
sudo -u "$ACTUAL_USER" yay -S --needed --noconfirm \
    asusctl \
    supergfxctl \
    future-dark-cursors 2>/dev/null || true

systemctl enable --now supergfxd.service 2>/dev/null || true
systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

# 5. Deploy configs to user's .config directory
echo "[*] Deploying configs to $TARGET_HOME/.config..."
mkdir -p "$TARGET_HOME/.config"

CONFIG_SOURCE="$SCRIPT_DIR/configs"
if [ ! -d "$CONFIG_SOURCE" ]; then
    echo "[*] Fetching traits-arch/configs..."
    rm -rf /tmp/traits-configs
    git clone --depth 1 https://github.com/traits-arch/configs.git /tmp/traits-configs
    CONFIG_SOURCE="/tmp/traits-configs"
fi

cp -r "$CONFIG_SOURCE"/niri "$TARGET_HOME/.config/"
cp -r "$CONFIG_SOURCE"/waybar "$TARGET_HOME/.config/"
cp -r "$CONFIG_SOURCE"/swaync "$TARGET_HOME/.config/"
cp -r "$CONFIG_SOURCE"/rofi "$TARGET_HOME/.config/"
cp -r "$CONFIG_SOURCE"/alacritty "$TARGET_HOME/.config/"
cp -r "$CONFIG_SOURCE"/fastfetch "$TARGET_HOME/.config/"
cp "$CONFIG_SOURCE"/starship.toml "$TARGET_HOME/.config/"

# 6. Setup Wallpaper
echo "[*] Setting up aesthetic wallpaper..."
mkdir -p "$TARGET_HOME/Pictures/Wallpapers"
if [ -f "$SCRIPT_DIR/assets/wallpaper.png" ]; then
    cp "$SCRIPT_DIR/assets/wallpaper.png" "$TARGET_HOME/Pictures/Wallpapers/wallpaper.png"
elif [ -f "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" ]; then
    cp "$CONFIG_SOURCE/rofi/powermenu/type-4/image.png" "$TARGET_HOME/Pictures/Wallpapers/wallpaper.png"
fi

# 7. Fix hardcoded paths in Niri & Rofi configs
echo "[*] Adapting config paths for $ACTUAL_USER..."
sed -i "s|/home/xal|$TARGET_HOME|g" "$TARGET_HOME/.config/niri/config.kdl"
sed -i "s|/home/xal/Downloads/wallhaven-0we3m7_1920x1200.png|$TARGET_HOME/Pictures/Wallpapers/wallpaper.png|g" "$TARGET_HOME/.config/niri/config.kdl"

# Fix rofi scripts permissions and paths
find "$TARGET_HOME/.config/rofi" -type f -name "*.sh" -exec chmod +x {} +
find "$TARGET_HOME/.config/rofi" -type f -name "*.sh" -exec sed -i "s|/home/xal|$TARGET_HOME|g" {} +

# 8. Set permissions
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$TARGET_HOME/.config" "$TARGET_HOME/Pictures"

echo "[?] Niri and traits-configs environment setup completed!"