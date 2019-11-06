#!/usr/bin/python3

import contextlib
import os
import logging
import pwd
import subprocess

from tailslib import LIVE_USERNAME

X_ENV = {"DISPLAY": ":1",
         "XAUTHORITY": "/run/user/1000/gdm/Xauthority"}


# Credits go to kurin from this Reddit thread:
#   https://www.reddit.com/r/Python/comments/1sxil3/chdir_a_context_manager_for_switching_working/ce29rcm
@contextlib.contextmanager
def chdir(path):
    curdir = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(curdir)


def launch_x_application(username, command, *args):
    """Launch an X application and wait for its completion."""
    live_user_uid = pwd.getpwnam(LIVE_USERNAME).pw_uid

    xhost_cmd = ["xhost", "+SI:localuser:" + username]
    if os.geteuid() != live_user_uid:
        xhost_cmd = ["sudo", "-u", LIVE_USERNAME] + xhost_cmd
    subprocess.run(
        xhost_cmd,
        stderr=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        env=X_ENV,
        check=True)

    cmdline = ["sudo", "-u", username, command]
    cmdline.extend(args)
    try:
        subprocess.run(cmdline,
                       stderr=subprocess.PIPE,
                       env=X_ENV,
                       check=True,
                       universal_newlines=True)
    except subprocess.CalledProcessError as e:
        logging.error("{command} returned with {returncode}".format(
            command=command, returncode=e.returncode))
        for line in e.stderr.splitlines():
            logging.error(line)
        raise
    finally:
        xhost_cmd = ["xhost", "-SI:localuser:" + username]
        if os.geteuid() != live_user_uid:
            xhost_cmd = ["sudo", "-u", LIVE_USERNAME] + xhost_cmd
        subprocess.run(
            xhost_cmd,
            stderr=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            env=X_ENV,
            check=True)
