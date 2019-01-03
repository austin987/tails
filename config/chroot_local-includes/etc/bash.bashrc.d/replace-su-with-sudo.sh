#!/bin/bash

# Replace su by a message to use sudo.
#
# In Tails, the administration password doesn't work with 'su'. New
# users in particular may be puzzled by the authentication failures
# while trying to 'su' using administration password.
#
# This script introduces 'su' function for non-root users which asks
# them to use 'sudo' instead of 'su'.
#
# https://redmine.tails.boum.org/code/issues/15583

# Get LANG
. /etc/default/locale
export LANG

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

# Since we don't want to add 'su' function for root user, we will stop
# execution of this script if $USER is root.
[ "$USER" == root ] && return

su (){
    if tails_is_password_set.py; then
        echo "`gettext \"su is disabled. Please use sudo instead.\"`"
    else
        cat /usr/share/tails-greeter/no-password-lecture.txt
    fi
}
