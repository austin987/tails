#!/bin/bash

# To run this script in Debian, install the packages 'qrencode'.

set -e
set -u

for code in $* ; do
    file=$(echo "${code}" | sed -r "s#http(s)?://##;s#/\$##;s#[/\.]#_#g")
    qrencode -o "${file}.png" -s 5 "${code}"
    compress-image.sh "${file}.png"
done
