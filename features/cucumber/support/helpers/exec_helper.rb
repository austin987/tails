require 'json'
require 'socket'

class VMCommand

  attr_reader :returncode, :stdout, :stderr

  def initialize(vm, cmd, options = {})
    options[:user] ||= "root"
    options[:spawn] ||= false
    ret = execute(vm, cmd, options[:user], options[:spawn])
    @returncode = ret[0]
    @stdout = ret[1]
    @stderr = ret[2]
  end

  def self.wait_until_remote_shell_is_up(vm, timeout = 30)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    begin
      SystemTimer.timeout(timeout) do
        socket.puts(JSON.dump(["call", "root", "true"]))
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
  # If `spawn` is false the server will block until it has finished
  # executing `cmd`. If it's true the server won't block, and the
  # response will always be [0, "", ""] (only used as an
  # ACK). execute() will always block until a response is received,
  # though. Spawning is useful when starting processes in the
  # background (or running scripts that does the same) like the
  # vidalia-wrapper, or any application we want to interact with.
  def execute(vm, cmd, user, spawn)
    type = spawn ? "spawn" : "call"
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    begin
      socket.puts(JSON.dump([type, user, cmd]))
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
