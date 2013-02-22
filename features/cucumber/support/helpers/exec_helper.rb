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

  def self.wait_until_remote_shell_is_up(vm, timeout = 30)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    begin
      SystemTimer.timeout(timeout) do
        socket.puts('true')
        socket.readline(sep = "\0")
      end
    rescue Timeout::Error
      raise "Remote shell seems to be down"
    ensure
      socket.close
    end
  end

  # The parameter `cmd` cannot contain newlines. Separate multiple
  # commands using ";" instead.
  def execute(vm, cmd, user)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    begin
      socket.puts("sudo -n -H -u #{user} -s /bin/sh -c '#{cmd}'")
      s = socket.readline(sep = "\0").chomp("\0")
    ensure
      socket.close
    end
    return JSON.load(s)
  end

  def success?
    return @returncode == 0
  end

end
