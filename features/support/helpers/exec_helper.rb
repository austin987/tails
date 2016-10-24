require 'json'
require 'socket'

module RemoteShell
  class Failure < StandardError
  end

  # Counter providing unique id:s for each communicate() call.
  @@request_id ||= 0

  def communicate(vm, *args)
    socket = TCPSocket.new("127.0.0.1", vm.get_remote_shell_port)
    id = (@@request_id += 1)
    socket.puts(JSON.dump([id] + args))
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

  module_function :communicate
  private :communicate

  class Command
    # If `:spawn` is false the server will block until it has finished
    # executing `cmd`. If it's true the server won't block, and the
    # response will always be [0, "", ""] (only used as an
    # ACK). execute() will always block until a response is received,
    # though. Spawning is useful when starting processes in the
    # background (or running scripts that does the same) like our
    # onioncircuits wrapper, or any application we want to interact
    # with.
    def self.execute(vm, cmd, options = {})
      options[:user] ||= "root"
      options[:spawn] ||= false
      type = options[:spawn] ? "spawn" : "call"
      debug_log("#{type}ing as #{options[:user]}: #{cmd}")
      ret = RemoteShell.communicate(vm, type, options[:user], cmd)
      debug_log("#{type} returned: #{ret}") if not(options[:spawn])
      return ret
    end

    attr_reader :cmd, :returncode, :stdout, :stderr

    def initialize(vm, cmd, options = {})
      @cmd = cmd
      @returncode, @stdout, @stderr = self.class.execute(vm, cmd, options)
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
end
