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
# Architecture: NVIDIA Open DKMS + KVM Lab + Niri (Wayland)
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
printf '%b\n' "${CYAN}======================================================${NC}"
printf '%b\n' "${CYAN} ASUS ROG Strix G16 - Arch Linux Environment Setup   ${NC}"
printf '%b\n' "${CYAN}======================================================${NC}"

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
echo -e "${BLUE}[*] Log file:    ${LOG_FILE}${NC}"

if ! getent group wheel >/dev/null; then
    groupadd wheel
fi
usermod -aG wheel "$TARGET_USER"

# ---------------------------------------------------------------------
# Pre-flight environment diagnostics and network/mirror optimizer
# ---------------------------------------------------------------------
preflight_check() {
    echo -e "\n${CYAN}>>> STEP 0: Pre-Flight Environment Diagnostics & Mirror Optimization <<<${NC}"
    
    # 1. Check for stale database lock
    if [[ -f /var/lib/pacman/db.lck ]]; then
        if pgrep -x pacman >/dev/null 2>&1; then
            echo -e "${YELLOW}[!] Another pacman instance is running. Waiting for it to finish...${NC}"
            while pgrep -x pacman >/dev/null 2>&1; do sleep 1; done
        else
            echo -e "${YELLOW}[*] Removing stale /var/lib/pacman/db.lck lockfile...${NC}"
            rm -f /var/lib/pacman/db.lck
        fi
    fi
    echo -e "  ${GREEN}[?]${NC} Pacman database lock is free"

    # 2. Check disk space on /
    local free_gb
    free_gb=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
    if (( free_gb < 5 )); then
        echo -e "${YELLOW}[!] Warning: Less than 5 GB free on root partition (${free_gb} GB left).${NC}"
    else
        echo -e "  ${GREEN}[?]${NC} Root partition disk space: ${free_gb} GB available"
    fi

    # 3. Check network connectivity
    echo -e "${BLUE}[*] Testing network connectivity...${NC}"
    local net_ok=0
    for target in 1.1.1.1 8.8.8.8 77.88.8.8; do
        if ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
            net_ok=1
            break
        fi
    done

    if [[ $net_ok -eq 0 ]]; then
        echo -e "${RED}[!] Network unreachable! Please connect to Wi-Fi or plug in Ethernet.${NC}"
        echo -e "${YELLOW}[*] Use 'nmtui' or 'nmcli dev wifi connect <SSID> password <PASS>'${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}[?]${NC} Network gateway reachable"

    # 4. Check DNS resolution
    if ! curl -s --connect-timeout 4 -I https://archlinux.org >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] DNS lookup failed. Configuring fallback nameservers in /etc/resolv.conf...${NC}"
        printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 77.88.8.8\n" >> /etc/resolv.conf
        if ! curl -s --connect-timeout 4 -I https://archlinux.org >/dev/null 2>&1; then
            echo -e "${RED}[!] DNS still failing after adding fallback nameservers.${NC}"
            exit 1
        fi
    fi
    echo -e "  ${GREEN}[?]${NC} DNS name resolution working"

    # 5. Optimize /etc/pacman.conf
    echo -e "${BLUE}[*] Optimizing /etc/pacman.conf (ParallelDownloads=5, Color, Multilib)...${NC}"
    local pconf=/etc/pacman.conf
    
    # ParallelDownloads
    if grep -q '^#ParallelDownloads' "$pconf"; then
        sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "$pconf"
    elif ! grep -q '^ParallelDownloads' "$pconf"; then
        sed -i '/\[options\]/a ParallelDownloads = 5' "$pconf"
    fi

    # Visual enhancements
    sed -i 's/^#Color/Color/' "$pconf" 2>/dev/null || true
    if ! grep -q 'ILoveCandy' "$pconf"; then
        sed -i '/Color/a ILoveCandy' "$pconf" 2>/dev/null || true
    fi

    # Enable multilib
    if ! grep -q '^\[multilib\]$' "$pconf"; then
        if grep -q '^#[[:space:]]*\[multilib\]$' "$pconf"; then
            sed -i '/^#[[:space:]]*\[multilib\]$/,/^#[[:space:]]*Include[[:space:]]*=/ s/^#//' "$pconf"
        else
            cat >> "$pconf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
        fi
    fi
    echo -e "  ${GREEN}[?]${NC} Pacman configuration optimized"

    # 6. Ensure fast and reliable mirrors in /etc/pacman.d/mirrorlist
    echo -e "${BLUE}[*] Ensuring fast, reliable mirrors in mirrorlist...${NC}"
    local mlist=/etc/pacman.d/mirrorlist
    if [[ ! -s "$mlist" ]] || ! grep -q '^Server' "$mlist"; then
        echo -e "${YELLOW}[!] Mirrorlist was empty. Populating with official reliable HTTPS mirrors...${NC}"
        cat > "$mlist" <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch
EOF
    else
        # Ensure top tier fallback mirrors are present at the beginning
        if ! grep -q 'geo.mirror.pkgbuild.com' "$mlist"; then
            sed -i '1i Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\nServer = https://mirror.yandex.ru/archlinux/$repo/os/$arch' "$mlist"
        fi
    fi
    echo -e "  ${GREEN}[?]${NC} Mirrorlist configured"

    # 7. Sync databases and update archlinux-keyring
    echo -e "${BLUE}[*] Synchronizing package databases...${NC}"
    pacman -Sy --noconfirm
    echo -e "  ${GREEN}[?]${NC} Package databases synchronized"

    echo -e "${BLUE}[*] Updating archlinux-keyring to prevent signature issues...${NC}"
    pacman -S --needed --noconfirm archlinux-keyring || true
    echo -e "  ${GREEN}[?]${NC} Arch Linux keyring ready"

    echo -e "${BLUE}[*] Upgrading system packages...${NC}"
    pacman -Su --needed --noconfirm
    echo -e "  ${GREEN}[?]${NC} System packages up to date"

    # Basic essential utilities
    pacman -S --needed --noconfirm git curl base-devel sudo
    chmod +x "$SCRIPT_DIR"/scripts/*.sh
}

preflight_check

echo -e "\n${CYAN}>>> STEP 1: NVIDIA RTX 4060 / Wayland Setup <<<${NC}"
"$SCRIPT_DIR/scripts/setup_nvidia.sh"

echo -e "\n${CYAN}>>> STEP 2: KVM / QEMU / Virt-Manager / Network Lab <<<${NC}"
"$SCRIPT_DIR/scripts/setup_kvm.sh"

echo -e "\n${CYAN}>>> STEP 3: Hyprland Desktop (xarefin rice) / Waybar / SwayNC / SDDM <<<${NC}"
"$SCRIPT_DIR/scripts/setup_hyprland.sh"

echo -e "\n${CYAN}>>> STEP 4: Comprehensive System Verification <<<${NC}"
"$SCRIPT_DIR/scripts/verify.sh"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE ? EVERYTHING VERIFIED!      ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${BLUE}Install log saved to: ${LOG_FILE}${NC}"
echo -e "${BLUE}A reboot is recommended to start the Hyprland session.${NC}\n"

read -r -p "Reboot now into Hyprland? [Y/n] " answer
if [[ ! "$answer" =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}[*] Rebooting...${NC}"
    systemctl reboot
else
    echo -e "${GREEN}[*] Done! You can reboot manually with 'systemctl reboot' when ready.${NC}"
fi