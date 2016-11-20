#!/bin/sh

faketime_wrapper() {
    apt-get --yes install faketime
    faketime "${@}"
    apt-get --yes purge faketime '^libfaketime*'
}

faketime_sde_wrapper() {
    if [ -z "${SOURCE_DATE_EPOCH}" ]; then
        echo "SOURCE_DATE_EPOCH was not set!" >&2
        exit 1
    fi
    faketime_wrapper "$(date -d '@${SOURCE_DATE_EPOCH}')" "${@}"
}
