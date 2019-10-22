#!/usr/bin/env python3

# This file is part of Tails.

import subprocess

def is_password_set():
    output = subprocess.check_output(["passwd", "--status"])
    return output.split()[1] == b"P"
