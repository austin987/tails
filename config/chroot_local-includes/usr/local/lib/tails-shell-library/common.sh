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
