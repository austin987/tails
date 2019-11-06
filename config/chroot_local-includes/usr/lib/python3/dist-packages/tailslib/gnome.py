#!/usr/bin/python3

import os
import shlex
import subprocess

def _gnome_sh_wrapper(cmd):
    command = shlex.split(
        "env -i sh -c '. {lib} && {cmd}'".format(lib=GNOME_SH_PATH, cmd=cmd)
    )
    return subprocess.check_output(command).decode()

GNOME_SH_PATH = "/usr/local/lib/tails-shell-library/gnome.sh"
GNOME_ENV_VARS = _gnome_sh_wrapper("echo ${GNOME_ENV_VARS}").strip().split()

def gnome_env_vars():
    ret = []
    for line in _gnome_sh_wrapper("export_gnome_env && env").split("\n"):
        (key, _, value) = line.rstrip().partition("=")
        if key in GNOME_ENV_VARS:
            ret.append(key + "=" + value)
    return ret
