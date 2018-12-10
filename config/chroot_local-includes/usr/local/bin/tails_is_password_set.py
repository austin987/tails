#!/usr/bin/env python3

import subprocess

def is_password_set():
    output = subprocess.check_output(["passwd", "--status"])
    return output.split()[1] == b"P"

def main():
    if is_password_set():
        exit(0)
    else:
        exit(1)

if __name__ == "__main__":
    main()
