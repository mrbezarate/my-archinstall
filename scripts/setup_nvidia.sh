#!/usr/bin/env bash
# =====================================================================
# Graphics & Hardware Driver Setup (Adaptive for Bare-Metal & VMs)
# Auto-detects: NVIDIA dGPU, Intel iGPU, AMD, VirtualBox, VMware, KVM
# =====================================================================
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "[!] Run this script through install.sh or with sudo."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/env_detect.sh
source "$SCRIPT_DIR/env_detect.sh"
detect_environment

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

# ---------------------------------------------------------------------
# CASE 1: VIRTUAL MACHINE ENVIRONMENT (VirtualBox / VMware / QEMU / KVM)
# ---------------------------------------------------------------------
if [[ "$IS_VM" == "true" ]]; then
    log "Configuring graphics & guest tools for Virtual Machine (${VM_TYPE})"
    
    # Base virtual 3D acceleration and input stack
    pacman_install \
        mesa \
        vulkan-virtio \
        vulkan-icd-loader \
        libinput \
        xf86-input-libinput

    case "$VM_TYPE" in
        oracle|virtualbox)
            log "Installing VirtualBox Guest Additions..."
            pacman_install virtualbox-guest-utils
            systemctl enable vboxservice.service 2>/dev/null || true
            ;;
        vmware)
            log "Installing VMware Tools & video driver..."
            pacman_install open-vm-tools xf86-video-vmware
            systemctl enable vmtoolsd.service 2>/dev/null || true
            ;;
        kvm|qemu|bochs)
            log "Installing QEMU/KVM guest agent and SPICE clipboard agent..."
            pacman_install qemu-guest-agent spice-vdagent
            systemctl enable qemu-guest-agent.service 2>/dev/null || true
            ;;
        *)
            log "Generic VM detected. Installing mesa & spice-vdagent..."
            pacman_install spice-vdagent 2>/dev/null || true
            ;;
    esac

    # Ensure touchpad/mouse tapping is enabled
    install -d -m 0755 /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<'EOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
EOF

    log "Virtual Machine graphics and guest integration configured successfully."
    exit 0
fi

# ---------------------------------------------------------------------
# CASE 2: BARE-METAL PHYSICAL MACHINE (ASUS ROG / Intel / NVIDIA / AMD)
# ---------------------------------------------------------------------

# 1. Install matching kernel headers for DKMS modules
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

# 2. Intel iGPU (common on ASUS ROG laptops alongside RTX 4060)
if [[ "$HAS_INTEL_GPU" == "true" ]]; then
    log "Installing Intel Iris Xe / UHD graphics & hardware acceleration..."
    pacman_install \
        mesa \
        vulkan-intel \
        intel-media-driver \
        libva-intel-driver \
        libinput \
        xf86-input-libinput
fi

# 3. AMD GPU
if [[ "$HAS_AMD_GPU" == "true" ]]; then
    log "Installing AMD Radeon graphics & hardware acceleration..."
    pacman_install \
        mesa \
        vulkan-radeon \
        xf86-video-amdgpu \
        libva-mesa-driver \
        libinput \
        xf86-input-libinput
fi

# 4. NVIDIA dGPU (ASUS ROG Strix G16 RTX 4060)
if [[ "$HAS_NVIDIA" == "true" ]]; then
    log "Installing NVIDIA RTX userspace + open DKMS driver..."
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

    # Early KMS in mkinitcpio so display drivers load before login screen
    if [[ -f /etc/mkinitcpio.conf ]]; then
        # For hybrid laptops, ensure i915 loads before nvidia to prevent black screen freezes
        if [[ "$HAS_INTEL_GPU" == "true" ]] && ! grep -qw 'i915' /etc/mkinitcpio.conf; then
            sed -i "s/^MODULES=(\(.*\))/MODULES=(\1 i915)/" /etc/mkinitcpio.conf
        fi
        for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
            if ! grep -qw "$mod" /etc/mkinitcpio.conf; then
                sed -i "s/^MODULES=(\(.*\))/MODULES=(\1 $mod)/" /etc/mkinitcpio.conf
            fi
        done
    fi

    # DKMS module build
    if command -v dkms >/dev/null 2>&1; then
        log "Checking NVIDIA DKMS status..."
        dkms autoinstall || true
    fi

    # Regenerate initramfs
    if command -v mkinitcpio >/dev/null 2>&1; then
        log "Regenerating initramfs (early KMS modules)..."
        mkinitcpio -P || true
    fi

    for unit in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
        if systemctl list-unit-files "$unit" >/dev/null 2>&1 && systemctl list-unit-files "$unit" | grep -q "$unit"; then
            systemctl enable "$unit" 2>/dev/null || true
        fi
    done
fi

# Touchpad tapping and natural scrolling
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

log "Physical hardware graphics drivers installed successfully."