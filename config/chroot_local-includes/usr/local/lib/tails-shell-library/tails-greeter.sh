#!/bin/sh

PERSISTENCE_SETTING='/var/lib/live/config/tails.persistence'
MACSPOOF_SETTING='/var/lib/live/config/tails.macspoof'
NETWORK_SETTING='/var/lib/live/config/tails.network'

_get_tg_setting() {
    if [ -r "${1}" ]; then
        . "${1}"
        eval "echo \${${2}:-}"
    fi
}

persistence_is_enabled() {
    [ "$(_get_tg_setting "${PERSISTENCE_SETTING}" TAILS_PERSISTENCE_ENABLED)" = true ]
}

persistence_is_enabled_for() {
    persistence_is_enabled && mountpoint -q "$1" 2>/dev/null
}

persistence_is_enabled_read_write() {
    persistence_is_enabled && \
    [ "$(_get_tg_setting "${PERSISTENCE_SETTING}" TAILS_PERSISTENCE_READONLY)" != true ]
}

mac_spoof_is_enabled() {
    # Only return false when explicitly told so to increase failure
    # safety.
    [ "$(_get_tg_setting "${MACSPOOF_SETTING}" TAILS_MACSPOOF_ENABLED)" != false ]
}

tails_netconf() {
    _get_tg_setting "${NETWORK_SETTING}" TAILS_NETCONF
}
