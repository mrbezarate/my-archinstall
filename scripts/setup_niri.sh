#!/usr/bin/env bash
# Backward compatibility wrapper: forwards directly to setup_hyprland.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/setup_hyprland.sh" "$@"