#!/bin/bash

for image in $* ; do
    optipng -o6 $image
    advdef -z3 $image
done
