require 'json'
require 'socket'

class VMCommand

  @@request_id ||= 0

  attr_reader :cmd, :returncode, :stdout, :stderr

  def initialize(vm, cmd, options = {})
    @cmd = cmd
    @returncode, @stdout, @stderr = VMCommand.execute(vm, cmd, options)
  end

  def VMCommand.wait_until_remote_shell_is_up(vm, timeout = 90)
    try_for(timeout, :msg => "Remote shell seems to be down") do
      Timeout::timeout(3) do
        VMCommand.execute(vm, "echo 'hello?'")
      end
    end
  end

  # If `:spawn` is false the server will block until it has finished
  # executing `cmd`. If it's true the server won't block, and the
  # response will always be [0, "", ""] (only used as an
  # ACK). execute() will always block until a response is received,
  # though. Spawning is useful when starting processes in the
  # background (or running scripts that does the same) or any
  # application we want to interact with.
  def VMCommand.execute(vm, cmd, options = {})
    options[:user] ||= "root"
    options[:spawn] ||= false
    type = options[:spawn] ? "spawn" : "call"
    id = (@@request_id += 1)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    debug_log("#{type}ing as #{options[:user]}: #{cmd}")
    socket.puts(JSON.dump([id, type, options[:user], cmd]))
    loop do
      s = socket.readline(sep = "\0").chomp("\0")
      response_id, *rest = JSON.load(s)
      if response_id == id
        debug_log("#{type} returned: #{s}") if not(options[:spawn])
        return rest
      else
        debug_log("Dropped out-of-order remote shell response: " +
                  "got id #{response_id} but expected id #{id}")
      end
    end
  ensure
    socket.close if defined?(socket) && socket
  end

  def success?
    return @returncode == 0
  end

  def failure?
    return not(success?)
  end

  def to_s
    "Return status: #{@returncode}\n" +
    "STDOUT:\n" +
    @stdout +
    "STDERR:\n" +
    @stderr
  end

end
