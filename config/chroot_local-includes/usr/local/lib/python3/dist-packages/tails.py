#!/usr/bin/env python3

# This file is part of Tails. The purpose of this file is to provide a
# system-wide library that may be useful for other components of Tails.

import subprocess

def is_password_set():
    output = subprocess.check_output(["passwd", "--status"])
    return output.split()[1] == b"P"
