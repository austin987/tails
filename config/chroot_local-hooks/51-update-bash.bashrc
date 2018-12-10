#!/bin/sh

set -e

# Update /etc/bash.bashrc at runtime as defined in /etc/bash.bashrc.d/*

echo "Updating /etc/bash.bashrc"

OPTS_FILE='/etc/bash.bashrc'
OPTS_DIR='/etc/bash.bashrc.d/*'

cat <<EOF>> "${OPTS_FILE}"

for file in ${OPTS_DIR};
do
    source "\$file"
done
EOF
