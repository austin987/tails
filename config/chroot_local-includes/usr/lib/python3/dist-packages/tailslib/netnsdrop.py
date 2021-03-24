#!/usr/bin/env python3
"""
This module is useful for all those scripts that are meant to run a specific application inside a network
namespace.

This functions make many assumptions about the working of it; that's in the hope that those scripts will keep
a somewhat similar structure. This is:
    - the netns has already been created, of course
    - somewhere in /etc/sudoers.d/ the wrapper can be run as root
    - the systemd user unit tails-a11y-proxy-netns@$NETNS is running
"""
import os
import logging

from tailslib.gnome import gnome_env_vars


def run_in_netns(*args, netns, user="amnesia"):
    # base bwrap sharing most of the system
    bwrap = ["bwrap", "--bind", "/", "/", "--proc", "/proc", "--dev", "/dev"]
    # passes data to us
    bwrap += [
        "--bind",
        os.path.join("/tmp/netns-specific/", netns),
        "/tmp/shared-with-me/",
    ]
    # hide data not for us
    bwrap += ["--tmpfs", "/tmp/netns-specific/"]
    cmd = [
        "/bin/ip",
        "netns",
        "exec",
        netns,
        "/sbin/runuser",
        "-u",
        user,
        "--",
        *bwrap,
        "/usr/bin/env",
        *gnome_env_vars(),
        "AT_SPI_BUS_ADDRESS=unix:path=/tmp/shared-with-me/at.sock",
        *args,
    ]
    logging.info("Running %s", cmd)
    os.execvp(cmd[0], cmd)


def run(real_executable: str, netns: str, wrapper_executable: str, keep_env = True, extra_env={}):
    if os.getuid() == 0:
        run_in_netns(real_executable, netns=netns)
    else:
        env = os.environ.copy() if keep_env else {}
        env.update(extra_env)
        args = (
            ["sudo", "--non-interactive", wrapper_executable]
        )
        os.execvpe(args[0], args, env=env)
