#!/bin/bash

set -e
set -u

if [ ! -x /usr/bin/trimage ]; then
    echo "Please install the \"trimage\" package." >&2
    exit 1
fi

if [ ! -x /usr/bin/mat2 ]; then
    echo "Please install the \"mat2\" package." >&2
    exit 1
fi

for image in "${@}" ; do
    mat2 "${image}"
    trimage -f "${image}"
    mv "${image%.*}.cleaned.${image##*.}" "${image}"
done
