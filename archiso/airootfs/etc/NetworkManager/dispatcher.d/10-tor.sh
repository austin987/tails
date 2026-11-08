#!/usr/bin/env bash
# Manage Tor lifecycle when non-loopback network interfaces change state.
# Does NOT auto-enable DisableNetwork=0 until user confirms clock/bridge config in anitails-tor-connect.
set -euo pipefail

IFACE="${1:-}"
ACTION="${2:-}"

if [[ -z "${IFACE}" || "${IFACE}" == "lo" || "${IFACE}" == veth-* ]]; then
    exit 0
fi

case "${ACTION}" in
    up)
        if grep -qw "anitails.offline=1" /proc/cmdline; then
            logger -t anitails-tor "Offline mode active; refusing to start Tor and downing ${IFACE}"
            /usr/bin/ip link set dev "${IFACE}" down || true
            exit 0
        fi
        /usr/bin/systemctl restart tor.service
        ;;
    down)
        /usr/bin/systemctl stop anitails-tor-bootstrapped.target || true
        ;;
esac
