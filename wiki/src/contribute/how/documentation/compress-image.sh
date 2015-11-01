#!/bin/bash

# To run this script in Debian, install the packages 'optipng' and 'advancecomp'.

set -e
set -u

for image in $* ; do
    optipng -o6 $image
    advdef -z3 $image
    mat $image
done
