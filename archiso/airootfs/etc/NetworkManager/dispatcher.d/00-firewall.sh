#!/usr/bin/env bash
# Re-verify atomic nftables ruleset whenever any interface transitions UP;
# fail closed immediately if nftables ruleset is missing or fails validation.
set -euo pipefail

IFACE="${1:-}"
ACTION="${2:-}"

if [[ "${ACTION}" != "up" && "${ACTION}" != "pre-up" ]]; then
    exit 0
fi

if ! /usr/bin/nft -f /etc/nftables.conf; then
    logger -t anitails-firewall -p authpriv.crit "CRITICAL: nftables reload failed on ${IFACE} (${ACTION}); entering network panic!"
    if [[ -n "${IFACE}" && "${IFACE}" != "lo" ]]; then
        /usr/bin/ip link set dev "${IFACE}" down || true
    fi
    /usr/bin/systemctl start anitails-network-panic.service || true
    exit 1
fi
