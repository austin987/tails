import sh
import os.path
from logging import getLogger
import subprocess

log = getLogger(os.path.basename(__file__))


def systemd_ready():
    try:
        # XXX: discard stdout/stderr
        subprocess.Popen(["systemd-notify", "--ready"])
    except FileNotFoundError:
        # systemd not installed
        pass
    else:
        log.info("systemd was notified")


def tor_has_bootstrapped() -> bool:
    try:
        sh.systemctl("is-active", "tails-tor-has-bootstrapped.target")
        return True
    except sh.ErrorReturnCode:
        return False
