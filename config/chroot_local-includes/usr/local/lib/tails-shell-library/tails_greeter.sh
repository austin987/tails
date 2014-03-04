#!/bin/sh

PERSISTENCE_STATE='/var/lib/live/config/tails.persistence'
PHYSICAL_SECURITY_SETTINGS='/var/lib/live/config/tails.physical_security'

persistence_is_enabled() {
    local TAILS_PERSISTENCE_ENABLED
    TAILS_PERSISTENCE_ENABLED=""
    if [ -r "${PERSISTENCE_STATE}" ]; then
        . "${PERSISTENCE_STATE}"
    fi
    [ "${TAILS_PERSISTENCE_ENABLED}" = true ]
}

mac_spoof_is_enabled() {
    if [ -r "${PHYSICAL_SECURITY_SETTINGS}" ]; then
        . "${PHYSICAL_SECURITY_SETTINGS}"
    fi
    # Only return false when explicitly told so to increase failure
    # safety.
    [ "${TAILS_MACSPOOF_ENABLED}" != false ]
}

tails_netconf() {
    local TAILS_NETCONF
    TAILS_NETCONF=""
    if [ -r "${PHYSICAL_SECURITY_SETTINGS}" ]; then
        . "${PHYSICAL_SECURITY_SETTINGS}"
    fi
    echo "${TAILS_NETCONF}"
}
