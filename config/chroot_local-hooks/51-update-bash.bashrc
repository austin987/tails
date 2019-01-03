#!/bin/sh

set -e
set -u

# Make /etc/bash.bashrc source /etc/bash.bashrc.d/*

echo "Updating /etc/bash.bashrc"

OPTS_FILE='/etc/bash.bashrc'

cat <<EOF>> "${OPTS_FILE}"

for file in /etc/bash.bashrc.d/*;
do
    source "\$file"
done
EOF
