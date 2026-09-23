#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

USER_NAME="${TARGET_USER:-${SUDO_USER:-}}"
HOME_DIR="${TARGET_HOME:-}"
[[ -n "$USER_NAME" ]] || USER_NAME="$(logname 2>/dev/null || true)"
[[ -n "$HOME_DIR" ]] || HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"

ok_count=0
warn_count=0
fail_count=0

report_ok() {
    printf "  ${GREEN}[? OK]${NC} %s\n" "$*"
    ((ok_count+=1)) || true
}

report_warn() {
    printf "  ${YELLOW}[? WARN]${NC} %s\n" "$*"
    ((warn_count+=1)) || true
}

report_fail() {
    printf "  ${RED}[? FAIL]${NC} %s\n" "$*"
    ((fail_count+=1)) || true
}

echo -e "\n${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD}       SYSTEM HEALTH & CONFIGURATION AUDIT            ${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "Target User: ${BOLD}$USER_NAME${NC} | Home: ${BOLD}$HOME_DIR${NC}\n"

# ---------------------------------------------------------------------
# 1. NVIDIA RTX 4060 & DRIVERS
# ---------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[1/6] NVIDIA RTX 4060 & Graphic Drivers${NC}"
if pacman -Q nvidia-open-dkms >/dev/null 2>&1 || pacman -Q nvidia >/dev/null 2>&1 || pacman -Q nvidia-dkms >/dev/null 2>&1; then
    nv_pkg=$(pacman -Q nvidia-open-dkms 2>/dev/null || pacman -Q nvidia 2>/dev/null || pacman -Q nvidia-dkms 2>/dev/null)
    report_ok "NVIDIA kernel driver installed: $nv_pkg"
else
    report_fail "NVIDIA kernel driver package not found!"
fi

if pacman -Q nvidia-utils >/dev/null 2>&1; then
    report_ok "NVIDIA userspace utilities (nvidia-utils) installed"
else
    report_fail "nvidia-utils is missing"
fi

if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_name=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo "NVIDIA GPU")
    report_ok "nvidia-smi detected hardware: $gpu_name"
else
    report_warn "nvidia-smi not yet loaded into active kernel (will be active after reboot)"
fi

if [[ -f /etc/modprobe.d/nvidia.conf ]] && grep -q 'modeset=1' /etc/modprobe.d/nvidia.conf; then
    report_ok "DRM Kernel Mode Setting enabled in /etc/modprobe.d/nvidia.conf"
else
    report_warn "DRM modeset not configured in /etc/modprobe.d/nvidia.conf"
fi

if command -v prime-run >/dev/null 2>&1; then
    report_ok "NVIDIA PRIME offload launcher (prime-run) available"
else
    report_warn "prime-run is missing (optional)"
fi

# ---------------------------------------------------------------------
# 2. KVM / QEMU / LAB VIRTUALIZATION
# ---------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[2/6] KVM / QEMU & Virtual Networking Lab${NC}"
for kvm_tool in qemu-system-x86_64:qemu libvirtd:libvirt virt-manager:virt-manager wireshark:wireshark-qt tcpdump:tcpdump; do
    bin="${kvm_tool%%:*}"
    pkg="${kvm_tool#*:}"
    if command -v "$bin" >/dev/null 2>&1; then
        report_ok "Virtualization binary '$bin' ($pkg) installed"
    else
        report_fail "Virtualization tool '$bin' ($pkg) is NOT installed"
    fi
done

if pacman -Q edk2-ovmf >/dev/null 2>&1; then
    report_ok "UEFI VM firmware (edk2-ovmf) installed"
else
    report_warn "edk2-ovmf not installed (UEFI VMs won't boot, only BIOS)"
fi

if pacman -Q swtpm >/dev/null 2>&1; then
    report_ok "TPM 2.0 emulator (swtpm) installed"
else
    report_warn "swtpm not installed"
fi

if systemctl is-enabled libvirtd.service >/dev/null 2>&1 || systemctl is-active libvirtd.service >/dev/null 2>&1; then
    report_ok "libvirtd hypervisor service is enabled/active"
else
    report_warn "libvirtd.service is not enabled"
fi

if virsh net-info default >/dev/null 2>&1; then
    report_ok "libvirt default NAT network (virbr0) configured"
else
    report_warn "libvirt default NAT network not initialized yet"
fi

if [[ -x /usr/local/bin/create-vswitch ]]; then
    report_ok "Virtual switch lab creator (/usr/local/bin/create-vswitch) ready"
else
    report_fail "/usr/local/bin/create-vswitch script missing or not executable"
fi

for grp in libvirt kvm wireshark; do
    if id -nG "$USER_NAME" 2>/dev/null | grep -qw "$grp"; then
        report_ok "User '$USER_NAME' is in '$grp' group (no sudo needed)"
    else
        report_warn "User '$USER_NAME' is NOT yet in '$grp' group"
    fi
done

# ---------------------------------------------------------------------
# 3. DESKTOP COMPOSITORS (NIRI & HYPRLAND)
# ---------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[3/6] Window Compositors (Niri & Hyprland)${NC}"
if command -v niri >/dev/null 2>&1; then
    report_ok "Niri compositor installed: $(command -v niri)"
else
    report_fail "Niri compositor is NOT installed"
fi

if command -v Hyprland >/dev/null 2>&1 || command -v hyprland >/dev/null 2>&1; then
    report_ok "Hyprland compositor installed"
else
    report_warn "Hyprland is not installed (optional, Niri is primary)"
fi

if [[ -f /usr/share/wayland-sessions/niri.desktop ]]; then
    report_ok "Niri session registered in Display Manager (/usr/share/wayland-sessions/niri.desktop)"
else
    report_warn "niri.desktop not found in /usr/share/wayland-sessions/"
fi

# ---------------------------------------------------------------------
# 4. DESKTOP UI COMPONENTS (WAYBAR, ROFI, SWAYNC, ETC.)
# ---------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[4/6] Desktop UI Components${NC}"
for ui_tool in waybar:Waybar rofi:Rofi swaync:SwayNC alacritty:Alacritty swaybg:SwayBG hyprlock:Hyprlock hypridle:Hypridle pipewire:PipeWire firefox:Firefox; do
    bin="${ui_tool%%:*}"
    name="${ui_tool#*:}"
    if command -v "$bin" >/dev/null 2>&1; then
        report_ok "$name interface component ready"
    else
        report_fail "$name component ($bin) is NOT installed"
    fi
done

# ---------------------------------------------------------------------
# 5. USER CONFIGURATION (DOTFILES IN ~/.config)
# ---------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[5/6] User Configuration & Dotfiles ($HOME_DIR/.config)${NC}"

if [[ -f "$HOME_DIR/.config/niri/config.kdl" ]]; then
    if grep -q '/home/xal' "$HOME_DIR/.config/niri/config.kdl"; then
        report_fail "Niri config still has unreplaced /home/xal paths!"
    else
        report_ok "Niri config ($HOME_DIR/.config/niri/config.kdl) properly deployed"
    fi
else
    report_fail "Niri config ($HOME_DIR/.config/niri/config.kdl) is MISSING!"
fi

if [[ -d "$HOME_DIR/.config/waybar" && -f "$HOME_DIR/.config/waybar/config.jsonc" ]]; then
    report_ok "Waybar status bar config deployed"
else
    report_fail "Waybar config ($HOME_DIR/.config/waybar) is missing"
fi

if [[ -d "$HOME_DIR/.config/swaync" && -f "$HOME_DIR/.config/swaync/config.json" ]]; then
    report_ok "SwayNC Nova-Dark notification center deployed"
else
    report_fail "SwayNC config is missing"
fi

if [[ -d "$HOME_DIR/.config/rofi" ]]; then
    report_ok "Rofi app launcher menus deployed"
else
    report_fail "Rofi menus config is missing"
fi

if [[ -d "$HOME_DIR/.config/alacritty" ]]; then
    report_ok "Alacritty terminal aesthetic config deployed"
else
    report_fail "Alacritty config is missing"
fi

if [[ -f "$HOME_DIR/Pictures/Wallpapers/wallpaper.png" ]]; then
    report_ok "Wallpaper image deployed to ~/Pictures/Wallpapers/wallpaper.png"
else
    report_warn "Wallpaper image missing in ~/Pictures/Wallpapers/wallpaper.png"
fi

font_count=$(find "$HOME_DIR/.local/share/fonts" -type f 2>/dev/null | wc -l)
if (( font_count > 0 )); then
    report_ok "Custom fonts deployed ($font_count fonts in ~/.local/share/fonts)"
else
    report_warn "No custom fonts found in ~/.local/share/fonts"
fi

# ---------------------------------------------------------------------
# 6. DISPLAY MANAGER & SESSIONS
# ---------------------------------------------------------------------
echo -e "\n${BLUE}${BOLD}[6/6] Login Display Manager (SDDM)${NC}"
if systemctl is-enabled sddm.service >/dev/null 2>&1; then
    report_ok "SDDM Login Manager service is enabled on boot"
else
    report_warn "sddm.service is not enabled (you will need to start graphical session manually)"
fi

echo -e "\n${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD}                 AUDIT SUMMARY                        ${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"
printf "  ${GREEN}? Passed:${NC} %d checks\n" "$ok_count"
printf "  ${YELLOW}? Warnings:${NC} %d checks\n" "$warn_count"
printf "  ${RED}? Failures:${NC} %d checks\n" "$fail_count"

if (( fail_count == 0 )); then
    echo -e "\n${GREEN}${BOLD}[SUCCESS] All core components and configs are installed correctly!${NC}"
    echo -e "${CYAN}${BOLD}HOW TO LOGIN TO NIRI / HYPRLAND:${NC}"
    echo -e "  1. Reboot your computer."
    echo -e "  2. On the SDDM login screen (where you enter password):"
    echo -e "     Look at the ${BOLD}Session dropdown${NC} (bottom-left or top-left corner)."
    echo -e "  3. Select ${BOLD}'Niri'${NC} (or 'Hyprland') instead of 'Plasma (KDE)'."
    echo -e "  4. Type your password and enjoy your aesthetic desktop!\n"
else
    echo -e "\n${RED}${BOLD}[ATTENTION] There were $fail_count issues detected above.${NC}"
    echo -e "Review the [? FAIL] lines above to see exactly what failed."
fi