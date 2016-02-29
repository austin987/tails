#!/bin/sh

# Import set_simple_config_key().
. /usr/local/lib/tails-shell-library/common.sh

# Import language_code_from_locale().
. /usr/local/lib/tails-shell-library/localization.sh

I2P_DEFAULT_CONFIG="/usr/share/i2p"
I2P_CONFIG="/var/lib/i2p/i2p-config"
I2P_TUNNEL_CONFIG="${I2P_CONFIG}/i2ptunnel.config"
I2P_WRAPPER_LOG="/var/log/i2p/wrapper.log"

i2p_is_enabled() {
    grep -qw "i2p" /proc/cmdline
}

i2p_eep_proxy_address() {
    # We retrieve the host and port number from the I2P profile. This
    # shouldn't be anywhere other than 127.0.0.1:4444 but in case
    # someone modifies the hook scripts or the default changes in I2P,
    # this check should still work.
    local listen_host listen_port
    listen_host=$(awk -F= '/^tunnel\.0\.interface/{print $2}' \
                      "${I2P_TUNNEL_CONFIG}")
    listen_port=$(awk -F= '/^tunnel\.0\.listenPort/{print $2}' \
                      "${I2P_TUNNEL_CONFIG}")
    echo ${listen_host}:${listen_port}
}

i2p_reseed_started() {
    grep -q 'Reseed start$' "${I2P_WRAPPER_LOG}"
}

i2p_reseed_failed() {
    grep -q 'Reseed failed, check network connection$' "${I2P_WRAPPER_LOG}"
}

i2p_reseed_completed() {
    grep -q "Reseed complete" "${I2P_WRAPPER_LOG}"
}

i2p_reseed_status() {
    if i2p_reseed_completed; then
        echo success
    elif i2p_reseed_failed; then
        echo failure
    elif i2p_reseed_started; then
        echo running
    fi
}

i2p_built_a_tunnel() {
    netstat -nlp | grep -qwF "$(i2p_eep_proxy_address)"
}

i2p_router_console_address() {
    echo 127.0.0.1:7657
}

i2p_router_console_is_ready() {
    netstat -nlp | grep -qwF "$(i2p_router_console_address)"
}

set_best_i2p_router_console_lang() {
    # We will use the detected language even if I2P doesn't support it; it
    # will default to English in that case.
    local lang="$(language_code_from_locale "${LANG}")"
    # We first try to set it in an existing "live" config, even though
    # the effect will only appear after a restart.
    local config
    for config in "${I2P_CONFIG}/router.config" \
                  "${I2P_DEFAULT_CONFIG}/router.config"; do
        if [ -e "${config}" ]; then
            set_simple_config_key "${config}" "routerconsole.lang" "${lang}"
            return 0
        fi
    done
    return 1
}
