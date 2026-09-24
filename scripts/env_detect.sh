#!/usr/bin/env bash
# =====================================================================
# Archinstall - Automatic Hardware & Environment Detection Engine
# Detects: Virtual Machine vs Bare-Metal, GPU vendor, ASUS ROG, CPU Virt
# =====================================================================

detect_environment() {
    # 1. Virtual Machine Detection
    local virt_tool="none"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt_tool="$(systemd-detect-virt 2>/dev/null || echo "none")"
    fi

    local dmi_product=""
    [[ -r /sys/class/dmi/id/product_name ]] && dmi_product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
    local dmi_vendor=""
    [[ -r /sys/class/dmi/id/sys_vendor ]] && dmi_vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    local dmi_board=""
    [[ -r /sys/class/dmi/id/board_name ]] && dmi_board="$(cat /sys/class/dmi/id/board_name 2>/dev/null || true)"

    if [[ "$virt_tool" != "none" ]] || [[ "$dmi_vendor" =~ (QEMU|innotek|VMware|Bochs) ]] || [[ "$dmi_product" =~ (VirtualBox|VMware|KVM|QEMU) ]]; then
        export IS_VM="true"
        if [[ "$virt_tool" != "none" ]]; then
            export VM_TYPE="$virt_tool"
        elif [[ "$dmi_vendor" =~ innotek ]] || [[ "$dmi_product" =~ VirtualBox ]]; then
            export VM_TYPE="oracle"
        elif [[ "$dmi_vendor" =~ VMware ]] || [[ "$dmi_product" =~ VMware ]]; then
            export VM_TYPE="vmware"
        elif [[ "$dmi_vendor" =~ QEMU ]] || [[ "$dmi_product" =~ KVM ]]; then
            export VM_TYPE="kvm"
        else
            export VM_TYPE="generic-vm"
        fi
    else
        export IS_VM="false"
        export VM_TYPE="none"
    fi

    # 2. GPU Hardware Detection
    export HAS_NVIDIA="false"
    export HAS_INTEL_GPU="false"
    export HAS_AMD_GPU="false"

    if command -v lspci >/dev/null 2>&1; then
        local pci_display
        pci_display="$(lspci 2>/dev/null | grep -iE 'vga compatible controller|3d controller|display controller' || true)"
        if echo "$pci_display" | grep -qi 'nvidia'; then
            export HAS_NVIDIA="true"
        fi
        if echo "$pci_display" | grep -qi 'intel'; then
            export HAS_INTEL_GPU="true"
        fi
        if echo "$pci_display" | grep -qiE 'amd|ati|radeon|advanced micro devices'; then
            export HAS_AMD_GPU="true"
        fi
    fi

    # 3. ASUS ROG / TUF Detection
    export IS_ASUS="false"
    if [[ "$IS_VM" == "false" ]]; then
        if [[ "$dmi_vendor" =~ (ASUSTeK|ASUS) ]] || [[ "$dmi_product" =~ (ROG|Strix|TUF|Zephyrus|Flow|Scar) ]] || [[ "$dmi_board" =~ (G614|G814|FA507|FX507) ]]; then
            export IS_ASUS="true"
        fi
    fi

    # 4. CPU Hardware Virtualization (VT-x / AMD-V)
    export HAS_CPU_VIRT="false"
    if grep -q -E '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
        export HAS_CPU_VIRT="true"
    fi

    # Persist environment profile for all subsequent tools & verify scripts
    install -d -m 0755 /etc
    cat > /etc/archinstall-env.conf <<EOF
IS_VM="${IS_VM}"
VM_TYPE="${VM_TYPE}"
HAS_NVIDIA="${HAS_NVIDIA}"
HAS_INTEL_GPU="${HAS_INTEL_GPU}"
HAS_AMD_GPU="${HAS_AMD_GPU}"
IS_ASUS="${IS_ASUS}"
HAS_CPU_VIRT="${HAS_CPU_VIRT}"
EOF
}

# Auto-load persisted environment if available
if [[ -f /etc/archinstall-env.conf ]]; then
    # shellcheck source=/dev/null
    source /etc/archinstall-env.conf
fi
