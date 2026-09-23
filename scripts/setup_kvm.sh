#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "[!] Run this script through install.sh or with sudo."
    exit 1
fi

ACTUAL_USER="${TARGET_USER:-${SUDO_USER:-}}"
if [[ -z "$ACTUAL_USER" || "$ACTUAL_USER" == root ]] || ! getent passwd "$ACTUAL_USER" >/dev/null; then
    echo "[!] Normal target user could not be determined."
    exit 1
fi

log() { printf '\033[0;36m[*]\033[0m %s\n' "$*"; }

log "Installing KVM/QEMU/libvirt and network lab tools"
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

for group in libvirt kvm wireshark; do
    getent group "$group" >/dev/null || groupadd "$group"
done
usermod -aG libvirt,kvm,wireshark "$ACTUAL_USER"

# Make libvirt's legacy socket group access explicit when the config exists.
if [[ -f /etc/libvirt/libvirtd.conf ]]; then
    grep -q '^unix_sock_group = "libvirt"' /etc/libvirt/libvirtd.conf || \
        printf '\nunix_sock_group = "libvirt"\n' >> /etc/libvirt/libvirtd.conf
    grep -q '^unix_sock_rw_perms = "0770"' /etc/libvirt/libvirtd.conf || \
        printf 'unix_sock_rw_perms = "0770"\n' >> /etc/libvirt/libvirtd.conf
fi

systemctl enable --now libvirtd.service
if systemctl list-unit-files virtlogd.socket >/dev/null 2>&1; then
    systemctl enable --now virtlogd.socket
fi

# Ensure libvirt's default NAT network exists, is active, and autostarts.
if ! virsh net-info default >/dev/null 2>&1; then
    cat > /tmp/libvirt-default.xml <<'EOF'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-define /tmp/libvirt-default.xml
    rm -f /tmp/libvirt-default.xml
fi
virsh net-autostart default
if ! virsh net-info default | grep -q '^Active:[[:space:]]*yes'; then
    virsh net-start default
fi

# Wireshark capture without root.
if [[ -x /usr/bin/dumpcap ]]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 750 /usr/bin/dumpcap
    if command -v setcap >/dev/null 2>&1; then
        setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/dumpcap
    fi
fi

# Idempotent isolated bridge helper. It is intentionally L2-only; give it an IP
# from the router VM instead of silently turning the host into another router.
cat > /usr/local/bin/create-vswitch <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
    echo "Usage: sudo create-vswitch <bridge_name>"
    exit 1
fi
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "Invalid bridge name: $NAME"
    exit 1
fi
if ip link show "$NAME" >/dev/null 2>&1; then
    echo "Bridge $NAME already exists."
else
    ip link add name "$NAME" type bridge
fi
ip link set dev "$NAME" up
echo "Bridge $NAME is up."
EOF
chmod 0755 /usr/local/bin/create-vswitch

log "KVM/libvirt setup complete"
log "Create isolated VM networks with: sudo create-vswitch br-lan1"
