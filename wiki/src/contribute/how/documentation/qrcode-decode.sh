#!/bin/bash

# To run this script in Debian, install the packages 'zbar-tools'.

set -e
set -u

for code in $* ; do
    echo "${code}"
    zbarimg "${code}"
done
