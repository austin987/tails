#!/bin/bash

# Replace su by a message to use sudo
# https://redmine.tails.boum.org/code/issues/15583

[ $USER == root ] && return

su (){
    tails_is_password_set.py
    if [ $? -eq 0 ]; then
        echo su is disabled. Please use sudo instead.
    else
        cat /usr/share/tails-greeter/no-password-lecture.txt
    fi
}
