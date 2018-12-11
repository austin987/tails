#!/bin/bash

# Replace su by a message to use sudo
# https://redmine.tails.boum.org/code/issues/15583

# Get LANG
. /etc/default/locale
export LANG

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

[ $USER == root ] && return

su (){
    tails_is_password_set.py
    if [ $? -eq 0 ]; then
        "`gettext \"su is disabled. Please use sudo instead.\"`"
    else
        cat /usr/share/tails-greeter/no-password-lecture.txt
    fi
}
