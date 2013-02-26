#!/usr/bin/python

# ATTENTION: Yes, this can be used as a backdoor, but only for an
# adversary with access to you *physical* serial port, which means
# that you are screwed any way.

from subprocess import Popen, PIPE
from sys import argv
from json import dumps, loads
from getpass import getuser
import serial

def main():
  dev = argv[1]
  port = serial.Serial(port = dev, baudrate = 4000000)
  port.open()
  while True:
    cmd_type, user, cmd = loads(port.readline())
    if user != getuser():
      cmd = "sudo -n -H -u " + user + " -s /bin/sh -c '" + cmd + "'"
    p = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
    if cmd_type == "spawn":
      returncode, stdout, stderr = 0, "", ""
    else:
      stdout, stderr = p.communicate()
      returncode = p.returncode
    port.write(dumps([returncode, stdout, stderr]) + "\0")

if __name__ == "__main__":
  main()
