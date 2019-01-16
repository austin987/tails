#!/bin/bash

# Replace su by a message to use sudo.
#
# In Tails, the administration password doesn't work with 'su'. New
# users in particular may be puzzled by the authentication failures
# while trying to 'su' using administration password.
#
# This script introduces 'su' function for non-root users. The 'su'
# function executes '/usr/local/bin/replace-su-with-sudo', which asks
# them to use 'sudo' instead of 'su'.
#
# https://redmine.tails.boum.org/code/issues/15583

# Get LIVE_USERNAME
. /etc/live/config.d/username.conf

# Since we don't want to add 'su' function for root user, we will stop
# execution of this script if $USER is root.
[ "$USER" == "$LIVE_USERNAME" ] || return

su (){
    /usr/local/bin/replace-su-with-sudo
}
