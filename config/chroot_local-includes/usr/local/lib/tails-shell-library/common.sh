#!/bin/sh

# Run `check_expr` until `timeout` seconds has passed, and sleep
# `delay` (optional, defaults to 1) seconds in between the calls.
# Note that execution isn't aborted exactly after `timeout`
# seconds. In the worst case (the timeout happens right after we check
# if the timeout has happened) we'll wait in total: `timeout` seconds +
# `delay` seconds + the time needed for `check_expr`.
wait_until() {
    local timeout check_expr delay timeout_at
    timeout="${1}"
    check_expr="${2}"
    delay="${3:-1}"
    timeout_at=$(expr $(date +%s) + ${timeout})
    until eval "${check_expr}"; do
        if [ "$(date +%s)" -ge "${timeout_at}" ]; then
            return 1
        fi
        sleep ${delay}
    done
    return 0
}

# Just an alias. The second argument (wait_until()'s check_expr) is
# the "try code block". Just like in `wait_until()`, the timeout isn't
# very accurate.
try_for() {
    wait_until "${@}"
}

set_simple_config_key() {
    local key="${1}"
    local value="${2}"
    local file="${3}"
    local op="${4:-=}"
    if grep -q "^${key}${op}" "${file}"; then
        sed -i -n "s/^${key}${op}.*$/${key}${op}${value}/p" "${file}"
    else
        echo "${key}${op}${value}" >> "${file}"
    fi
}
