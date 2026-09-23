#!/bin/bash
set -e

echo "=========================================="
echo " [1/3] Setting up NVIDIA RTX 4060 & Wayland"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo or as root"
    exit 1
fi

# 1. Enable multilib repository if not already enabled
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "[*] Enabling multilib repository in /etc/pacman.conf..."
    cat << 'EOF' >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    pacman -Sy
fi

# 2. Install Linux Kernel Headers & NVIDIA Drivers
echo "[*] Installing NVIDIA drivers and kernel modules..."
pacman -S --needed --noconfirm \
    linux-headers \
    nvidia-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    egl-wayland \
    opencl-nvidia

# 3. Configure DRM kernel modesetting (Required for Wayland)
echo "[*] Configuring nvidia-drm modeset..."
cat << 'EOF' > /etc/modprobe.d/nvidia.conf
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

# 4. Set global Wayland environment variables
echo "[*] Setting Wayland environment variables in /etc/environment..."
grep -q "LIBVA_DRIVER_NAME=nvidia" /etc/environment 2>/dev/null || echo "LIBVA_DRIVER_NAME=nvidia" >> /etc/environment
grep -q "GBM_BACKEND=nvidia-drm" /etc/environment 2>/dev/null || echo "GBM_BACKEND=nvidia-drm" >> /etc/environment
grep -q "__GLX_VENDOR_LIBRARY_NAME=nvidia" /etc/environment 2>/dev/null || echo "__GLX_VENDOR_LIBRARY_NAME=nvidia" >> /etc/environment
grep -q "NVD_BACKEND=direct" /etc/environment 2>/dev/null || echo "NVD_BACKEND=direct" >> /etc/environment
grep -q "ELECTRON_OZONE_PLATFORM_HINT=auto" /etc/environment 2>/dev/null || echo "ELECTRON_OZONE_PLATFORM_HINT=auto" >> /etc/environment

# 5. Enable NVIDIA systemd power management services
echo "[*] Enabling NVIDIA power management services..."
systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

echo "[?] NVIDIA setup completed successfully!"