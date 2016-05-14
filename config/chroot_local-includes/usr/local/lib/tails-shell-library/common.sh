#!/bin/sh

# Get monotonic time in seconds. See clock_gettime(2) for details.
# Note: we limit ourselves to seconds simply because floating point
# arithmetic is a PITA in the shell.
clock_gettime_monotonic() {
    perl -w -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC \
         -E 'say int(clock_gettime(CLOCK_MONOTONIC))'
}

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
    timeout_at=$(expr $(clock_gettime_monotonic) + ${timeout})
    until eval "${check_expr}"; do
        if [ "$(clock_gettime_monotonic)" -ge "${timeout_at}" ]; then
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

# Sets the `value` of a `key` in a simple configuration `file`. With
# "simple" you should think something like a the shell environment as
# output by the `env` command. Hence this is only useful for
# configuration files that have no structure (e.g. sections with
# semantic meaning, like the namespace secions in .gitconfig), allow
# only one assignment per line, and a fixed/static assignment operator
# (`op`, which defaults to '=', but other examples would be " = " or
# torrc's " "). If the key already exists its value is updated in
# place, otherwise it's added at the end.
set_simple_config_key() {
    local file="${1}"
    local key="${2}"
    local value="${3}"
    local op="${4:-=}"
    if grep -q "^${key}${op}" "${file}"; then
        # Escape / in input so it can be used as the sed separator
        key="$(echo "${key}" | sed 's,/,\\/,g')"
        value="$(echo "${value}" | sed 's,/,\\/,g')"
        sed -i "s/^${key}${op}.*$/${key}${op}${value}/" "${file}"
    else
        echo "${key}${op}${value}" >> "${file}"
    fi
}

# Runs the wrapped command while temporarily disabling `set -e`, if
# enabled. It will always return 0 to not make scripts with `set -e`
# enabled abort but will instead store the wrapped command's return
# value into the global variable _NO_ABORT_RET.
no_abort() {
    local set_e_was_enabled
    if echo "${-}" | grep -q 'e'; then
        set +e
        set_e_was_enabled=true
    else
        set_e_was_enabled=false
    fi
    "${@}"
    _NO_ABORT_RET=${?}
    if [ "${set_e_was_enabled}" = true ]; then
        set -e
    fi
    return 0
}
