#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "[!] Run this script through install.sh or with sudo."
    exit 1
fi

log() { printf '\033[0;36m[*]\033[0m %s\n' "$*"; }

pacman_install() {
    local max=3
    for ((i=1; i<=max; i++)); do
        if pacman -S --needed --noconfirm "$@"; then
            return 0
        fi
        log "pacman download attempt $i failed. Retrying in 2s..."
        sleep 2
    done
    return 1
}

log "Configuring NVIDIA RTX 4060 for Wayland"

# Install matching kernel headers for installed kernels
header_pkgs=()
while IFS= read -r kernel_pkg; do
    case "$kernel_pkg" in
        linux)          header_pkgs+=(linux-headers) ;;
        linux-lts)      header_pkgs+=(linux-lts-headers) ;;
        linux-zen)      header_pkgs+=(linux-zen-headers) ;;
        linux-hardened) header_pkgs+=(linux-hardened-headers) ;;
    esac
done < <(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened)?$' || true)

if ((${#header_pkgs[@]})); then
    log "Installing matching kernel headers: ${header_pkgs[*]}"
    pacman_install "${header_pkgs[@]}"
fi

log "Installing Intel Iris Xe iGPU, Mesa, and Touchpad drivers"
pacman_install \
    mesa \
    vulkan-intel \
    intel-media-driver \
    libinput \
    xf86-input-libinput

log "Installing NVIDIA userspace + open DKMS driver"
pacman_install \
    nvidia-open-dkms \
    nvidia-utils \
    nvidia-settings \
    nvidia-prime \
    egl-wayland \
    opencl-nvidia

if pacman -Si lib32-nvidia-utils >/dev/null 2>&1; then
    pacman_install lib32-nvidia-utils || true
fi

# Persistent DRM modeset + fbdev for Wayland on modern NVIDIA
install -d -m 0755 /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

# Ensure touchpad tapping and natural scrolling are enabled system-wide
install -d -m 0755 /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<'EOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "ClickMethod" "clickfinger"
    Option "NaturalScrolling" "true"
EndSection
EOF

# Early KMS in mkinitcpio so display drivers load before login screen
if [[ -f /etc/mkinitcpio.conf ]]; then
    for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        if ! grep -q "$mod" /etc/mkinitcpio.conf; then
            sed -i "s/^MODULES=(\(.*\))/MODULES=(\1 $mod)/" /etc/mkinitcpio.conf
        fi
    done
fi

# DKMS pacman hooks compile modules automatically. dkms autoinstall is non-fatal if running kernel differs from new headers
if command -v dkms >/dev/null 2>&1; then
    log "Checking NVIDIA DKMS status..."
    dkms autoinstall || true
fi

# mkinitcpio creates the initramfs ramdisk for early driver loading (NOT a bootloader)
if command -v mkinitcpio >/dev/null 2>&1; then
    log "Regenerating initramfs (early KMS modules)..."
    mkinitcpio -P || true
fi

for unit in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1 && systemctl list-unit-files "$unit" | grep -q "$unit"; then
        systemctl enable "$unit" 2>/dev/null || true
    fi
done

log "NVIDIA setup complete."