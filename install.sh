#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------
# ASUS ROG Strix G16 (G614JV) - Arch Linux Setup
# Current Arch packaging: NVIDIA open DKMS + Niri + KVM/libvirt
# ---------------------------------------------------------------------

if [[ ${EUID} -ne 0 ]]; then
    exec sudo -- "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/my-archinstall"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'rc=$?; echo -e "${RED}[!] Installation stopped at line ${BASH_LINENO[0]} (exit ${rc}). Full log: ${LOG_FILE}${NC}" >&2' ERR

clear
printf '%b\n' "${CYAN}===============================================${NC}"
printf '%b\n' "${CYAN} ASUS ROG Strix G16 - Arch/Niri setup${NC}"
printf '%b\n' "${CYAN}===============================================${NC}"

if [[ ! -f /etc/arch-release ]]; then
    echo -e "${RED}[!] This installer is for Arch Linux only.${NC}"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo -e "${RED}[!] pacman is missing.${NC}"
    exit 1
fi

get_target_user() {
    local user="${SUDO_USER:-}"
    if [[ -n "$user" && "$user" != root ]] && getent passwd "$user" >/dev/null; then
        printf '%s\n' "$user"
        return
    fi
    user="$(logname 2>/dev/null || true)"
    if [[ -n "$user" && "$user" != root ]] && getent passwd "$user" >/dev/null; then
        printf '%s\n' "$user"
        return
    fi
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd
}

TARGET_USER="$(get_target_user)"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
    echo -e "${RED}[!] Could not determine the normal user account.${NC}"
    exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
export TARGET_USER TARGET_HOME

echo -e "${BLUE}[*] Target user: ${TARGET_USER}${NC}"
echo -e "${BLUE}[*] Target home: ${TARGET_HOME}${NC}"
echo -e "${BLUE}[*] Log file: ${LOG_FILE}${NC}"

if ! getent group wheel >/dev/null; then
    groupadd wheel
fi
usermod -aG wheel "$TARGET_USER"

enable_multilib() {
    local conf=/etc/pacman.conf
    # The NVIDIA 32-bit userspace package lives in [multilib]. Enable the
    # repository before the first full sync so it cannot be reported as skipped.
    if grep -q '^\[multilib\]$' "$conf"; then
        return 0
    fi
    if grep -q '^#[[:space:]]*\[multilib\]$' "$conf"; then
        sed -i '/^#[[:space:]]*\[multilib\]$/,/^#[[:space:]]*Include[[:space:]]*=/ s/^#//' "$conf"
    else
        cat >> "$conf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    fi
}

echo -e "${CYAN}>>> STEP 0: Enable required repos and fully update Arch <<<${NC}"
enable_multilib
pacman -Syu --needed --noconfirm

# Basic tools required by later steps.
pacman -S --needed --noconfirm git curl base-devel sudo
chmod +x "$SCRIPT_DIR"/scripts/*.sh

echo -e "${CYAN}>>> STEP 1: NVIDIA RTX 4060 / Wayland <<<${NC}"
"$SCRIPT_DIR/scripts/setup_nvidia.sh"

echo -e "${CYAN}>>> STEP 2: KVM / QEMU / libvirt / virtual networking <<<${NC}"
"$SCRIPT_DIR/scripts/setup_kvm.sh"

echo -e "${CYAN}>>> STEP 3: Niri / Waybar / Rofi / SwayNC / SDDM <<<${NC}"
"$SCRIPT_DIR/scripts/setup_niri.sh"

echo -e "${CYAN}>>> STEP 4: Verify installed components <<<${NC}"
"$SCRIPT_DIR/scripts/verify.sh"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}   INSTALLATION FINISHED — CHECK THE VERIFICATION    ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${BLUE}Log: ${LOG_FILE}${NC}"
echo -e "${BLUE}A reboot is recommended before first Niri login.${NC}"

read -r -p "Reboot now? [Y/n] " answer
if [[ ! "$answer" =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}[*] Rebooting...${NC}"
    systemctl reboot
else
    echo -e "${GREEN}[*] Done. Reboot manually when ready.${NC}"
fi
