require 'socket'
require 'json'

class VMCommand

  attr_reader :returncode, :stdout, :stderr

  def initialize(vm, cmd, user = "amnesia")
    ret = execute(vm, cmd, user)
    @returncode = ret[0]
    @stdout = ret[1]
    @stderr = ret[2]
  end

  # The parameter `cmd` cannot contain newlines. Separate multiple
  # commands using ";" instead.
  def execute(vm, cmd, user)
    socket = TCPSocket.new(vm.ip, vm.remote_shell_port)
    socket.puts("sudo -n -H -u " + user + " -s /bin/sh " + "-c \'" + cmd + "\'")
    answer = JSON.load(socket.gets)
    socket.close
    return answer
  end

  def success?
    return @returncode == 0
  end

end
