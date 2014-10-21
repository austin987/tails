#!/bin/sh

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
# the "try code block".
try_for() {
    wait_until "${@}"
}

set_key() {
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
