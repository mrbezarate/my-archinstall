#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "[!] Run this script through install.sh or with sudo."
    exit 1
fi

log() { printf '\033[0;36m[*]\033[0m %s\n' "$*"; }

log "Configuring NVIDIA RTX 4060 for Wayland"

# nvidia-dkms was removed from current Arch packaging. For RTX 4060/Turing+
# use NVIDIA's open kernel modules through DKMS.
log "Installing NVIDIA userspace + open DKMS driver"
pacman -S --needed --noconfirm \
    nvidia-open-dkms \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-settings \
    nvidia-prime \
    egl-wayland \
    opencl-nvidia

# Install headers for every stock Arch kernel that is actually installed.
header_pkgs=()
while IFS= read -r kernel_pkg; do
    case "$kernel_pkg" in
        linux)     header_pkgs+=(linux-headers) ;;
        linux-lts) header_pkgs+=(linux-lts-headers) ;;
        linux-zen) header_pkgs+=(linux-zen-headers) ;;
        linux-hardened) header_pkgs+=(linux-hardened-headers) ;;
    esac
done < <(pacman -Qq | grep -E '^linux(-lts|-zen|-hardened)?$' || true)

if ((${#header_pkgs[@]})); then
    log "Installing matching kernel headers: ${header_pkgs[*]}"
    pacman -S --needed --noconfirm "${header_pkgs[@]}"
else
    log "No stock Arch kernel package was detected; checking /usr/lib/modules instead."
fi

# Persistent DRM modeset. Modern NVIDIA drivers may already default to this,
# but keeping it explicit avoids relying on driver defaults for Wayland.
install -d -m 0755 /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

# The old installer exported several NVIDIA variables globally in /etc/environment.
# They can interfere with Intel/iGPU apps on a hybrid laptop, so we deliberately do
# not add them globally. Use prime-run for applications that need the RTX 4060.

if command -v dkms >/dev/null 2>&1; then
    log "Building NVIDIA DKMS modules"
    dkms autoinstall
fi

if command -v mkinitcpio >/dev/null 2>&1; then
    log "Regenerating initramfs"
    mkinitcpio -P
fi

for unit in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1 && systemctl list-unit-files "$unit" | grep -q "$unit"; then
        systemctl enable "$unit" || true
    fi
done

log "NVIDIA setup complete. Verify with: nvidia-smi && dkms status"
