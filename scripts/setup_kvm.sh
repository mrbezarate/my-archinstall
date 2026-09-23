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

log "Installing KVM/QEMU/libvirt and network lab tools"
# NOTE: ebtables is intentionally excluded because iptables-nft already provides and conflicts with it.
pacman_install \
    qemu-desktop \
    libvirt \
    virt-manager \
    virt-viewer \
    edk2-ovmf \
    swtpm \
    dnsmasq \
    iptables-nft \
    nftables \
    openvswitch \
    dmidecode \
    wireshark-qt \
    tcpdump

for group in libvirt kvm wireshark; do
    getent group "$group" >/dev/null || groupadd "$group"
done
usermod -aG libvirt,kvm,wireshark "$ACTUAL_USER"

# Make libvirt socket group access explicit
if [[ -f /etc/libvirt/libvirtd.conf ]]; then
    grep -q '^unix_sock_group = "libvirt"' /etc/libvirt/libvirtd.conf || \
        printf '\nunix_sock_group = "libvirt"\n' >> /etc/libvirt/libvirtd.conf
    grep -q '^unix_sock_rw_perms = "0770"' /etc/libvirt/libvirtd.conf || \
        printf 'unix_sock_rw_perms = "0770"\n' >> /etc/libvirt/libvirtd.conf
fi

systemctl enable --now libvirtd.service 2>/dev/null || true
if systemctl list-unit-files virtlogd.socket >/dev/null 2>&1; then
    systemctl enable --now virtlogd.socket 2>/dev/null || true
fi

# Ensure libvirt default NAT network exists and is active
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
    virsh net-define /tmp/libvirt-default.xml || true
    rm -f /tmp/libvirt-default.xml
fi
virsh net-autostart default 2>/dev/null || true
if ! virsh net-info default 2>/dev/null | grep -q '^Active:[[:space:]]*yes'; then
    virsh net-start default 2>/dev/null || true
fi

# Wireshark capture without root
if [[ -x /usr/bin/dumpcap ]]; then
    chgrp wireshark /usr/bin/dumpcap
    chmod 750 /usr/bin/dumpcap
    if command -v setcap >/dev/null 2>&1; then
        setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/dumpcap 2>/dev/null || true
    fi
fi

# Isolated virtual switch helper for 4-Debian routing lab
cat > /usr/local/bin/create-vswitch <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
    echo "Usage: sudo create-vswitch <bridge_name>"
    echo "Example: sudo create-vswitch br-lan1"
    exit 1
fi
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "Invalid bridge name: $NAME"
    exit 1
fi
if ip link show "$NAME" >/dev/null 2>&1; then
    echo "Bridge $NAME already exists and active."
else
    ip link add name "$NAME" type bridge
    ip link set dev "$NAME" up
    echo "[?] Virtual switch $NAME created and active!"
fi
EOF
chmod 0755 /usr/local/bin/create-vswitch

log "KVM, Virt-Manager and virtual networking setup complete."