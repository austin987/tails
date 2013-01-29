require 'json'
require 'socket'

class VMCommand

  attr_reader :returncode, :stdout, :stderr

  def initialize(vm, cmd, user = "root")
    ret = execute(vm, cmd, user)
    @returncode = ret[0]
    @stdout = ret[1]
    @stderr = ret[2]
  end

  # The parameter `cmd` cannot contain newlines. Separate multiple
  # commands using ";" instead.
  def execute(vm, cmd, user)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    socket.puts("sudo -n -H -u #{user} -s /bin/sh -c '#{cmd}'")
    s = ""
    while (c = socket.read(1)) != "\0" do
      s += c
    end
    socket.close
    return JSON.load(s)
  end

  def success?
    return @returncode == 0
  end

end
