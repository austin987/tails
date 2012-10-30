#!/usr/bin/python

# ATTENTION: Yes, this can be used as a backdoor, but so can netcat
# and a plethora of other tools. This script is only supposed to be
# run when 'autotest_never_use_this_option' is present on the kernel
# commandline, which is set by Tails automated test suite. It will
# NEVER be run under normal operation. Also note that in most
# realistic scenarios where an adversary can make this script run, the
# adversary has capabilities enough to open a similar backdoor not
# using this script (perhaps through netcat). The worst seems to be if
# a user isn't physically present when his/her Tails boots, and an
# adversary takes the opportunity to add the boot option.

from subprocess import Popen, PIPE
from sys import argv
from json import dumps
from SocketServer import TCPServer, StreamRequestHandler

class RemoteShellServerHandler(StreamRequestHandler):
  def handle(self):
    cmd = self.rfile.readline()
    p = Popen(cmd, stdout=PIPE, stderr=PIPE, shell=True)
    stdout, stderr = p.communicate()
    returncode = p.returncode
    self.wfile.write(dumps([returncode, stdout, stderr]))

def kill_switch():
  for opt in ' '.join(open('/proc/cmdline', 'r').readlines()).split(' '):
    if opt == "autotest_never_use_this_option":
      return
  exit("You are only supposed to run this script with Tails' automated " +
       "test suite. Aborting...")

def main():
  kill_switch()
  port = int(argv[1])
  server = TCPServer(("0.0.0.0", port), RemoteShellServerHandler)
  server.serve_forever()

if __name__ == "__main__":
  main()
