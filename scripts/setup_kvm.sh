#!/bin/bash
set -e

echo "=========================================="
echo " [2/3] Setting up KVM, Virt-Manager & Lab "
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo or as root"
    exit 1
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
if [ "$ACTUAL_USER" = "root" ]; then
    echo "[!] Warning: Script running directly as root. Please specify user for group assignment:"
    read -p "Username: " TARGET_USER
    ACTUAL_USER="$TARGET_USER"
fi

echo "[*] Target user: $ACTUAL_USER"

# 1. Install KVM, QEMU, Libvirt, Virt-Manager, Wireshark and Network Utilities
echo "[*] Installing virtualization packages..."
pacman -S --needed --noconfirm \
    qemu-desktop \
    libvirt \
    virt-manager \
    virt-viewer \
    dnsmasq \
    iptables-nft \
    nftables \
    bridge-utils \
    openvswitch \
    ebtables \
    vde2 \
    dmidecode \
    wireshark-qt \
    tcpdump

# 2. Add user to virtualization and packet capture groups
echo "[*] Adding $ACTUAL_USER to libvirt, kvm, wireshark groups..."
groupadd -f libvirt
groupadd -f kvm
groupadd -f wireshark
usermod -aG libvirt,kvm,wireshark,input "$ACTUAL_USER"

# 3. Configure libvirtd socket permissions
echo "[*] Configuring libvirtd socket access..."
sed -i 's/^#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
sed -i 's/^#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf

# 4. Enable and start virtualization daemons
echo "[*] Enabling libvirt services..."
systemctl enable --now libvirtd.service
systemctl enable --now virtlogd.service

# 5. Enable default NAT virtual network
echo "[*] Initializing default NAT virtual network..."
sleep 1
virsh net-autostart default 2>/dev/null || true
virsh net-start default 2>/dev/null || true

# 6. Enable Wireshark capture without root
if [ -f /usr/bin/dumpcap ]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 750 /usr/bin/dumpcap
    setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/dumpcap 2>/dev/null || true
fi

# 7. Create a helper script for creating isolated virtual switches for multi-VM labs
mkdir -p /usr/local/bin
cat << 'EOF' > /usr/local/bin/create-vswitch
#!/bin/bash
# Helper to create isolated Linux Bridges for multi-VM routing labs
# Usage: sudo create-vswitch <bridge_name> (e.g. sudo create-vswitch br-lan1)
if [ -z "$1" ]; then
    echo "Usage: sudo create-vswitch <bridge_name>"
    echo "Example: sudo create-vswitch br-lan1"
    exit 1
fi
NAME="$1"
ip link add name "$NAME" type bridge
ip link set dev "$NAME" up
echo "[?] Virtual switch $NAME created and active!"
EOF
chmod +x /usr/local/bin/create-vswitch

echo "[?] KVM, Virt-Manager and Virtual Networking setup completed!"