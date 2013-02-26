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
    try:
      line = port.readline()
    except Exception as e:
      # port must be opened wrong, so we restart everything and pray
      # that it works.
      print str(e)
      port.close()
      return main()
    try:
      cmd_type, user, cmd = loads(line)
    except Exception as e:
      # We had a parse/pack error, so we just send a \0 as an ACK,
      # releasing the client from blocking.
      print str(e)
      port.write("\0")
      continue
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
