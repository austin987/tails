#!/bin/bash

set -e
set -u

if [ ! -x /usr/bin/optipng ]; then
    echo "Please install the \"optipng\" package." >&2
    exit 1
fi

if [ ! -x /usr/bin/advdef ]; then
    echo "Please install the \"advancecomp\" package." >&2
    exit 1
fi

if [ ! -x /usr/bin/mat ]; then
    echo "Please install the \"mat\" package." >&2
    exit 1
fi

for image in "${@}" ; do
    optipng -o6 "${image}"
    advdef -z3 "${image}"
    mat "${image}"
done
