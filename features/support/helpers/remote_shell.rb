require 'base64'
require 'json'
require 'socket'
require 'timeout'

module RemoteShell
  class Failure < StandardError
  end

  # Used to differentiate vs Timeout::Error, which is thrown by
  # try_for() (by default) and often wraps around remote shell usage
  # -- in that case we don't want to catch that "outer" exception in
  # our handling of remote shell timeouts below.
  class Timeout < Failure
  end

  DEFAULT_TIMEOUT = 20*60

  # Counter providing unique id:s for each communicate() call.
  @@request_id ||= 0

  def communicate(vm, *args, **opts)
    opts[:timeout] ||= DEFAULT_TIMEOUT
    socket = UNIXSocket.new(vm.remote_shell_socket_path)
    id = (@@request_id += 1)
    # Since we already have defined our own Timeout in the current
    # scope, we have to be more careful when referring to the Timeout
    # class from the 'timeout' module. However, note that we want it
    # to throw our own Timeout exception.
    Object::Timeout.timeout(opts[:timeout], Timeout) do
      socket.puts(JSON.dump([id] + args))
      socket.flush
      loop do
        line = socket.readline("\n").chomp("\n")
        response_id, status, *rest = JSON.load(line)
        if response_id == id
          if status != "success"
            if status == "error" and rest.class == Array and rest.size == 1
              msg = rest.first
              raise Failure.new("#{msg}")
            else
              raise "#{status}: #{rest}"
            end
          end
          return rest
        else
          debug_log("Dropped out-of-order remote shell response: " +
                    "got id #{response_id} but expected id #{id}")
        end
      end
    end
  rescue Timeout => e
    debug_log("The remote shell timed out")
    if socket.nil?
      debug_log("The socket is not defined")
    elsif socket.closed?
      debug_log("The socket is closed")
    else
      debug_log("Let's check if there is any data on the socket any way...")
      data = ""
      begin
        loop { try_for(1, exception: Timeout) { data += socket.read(1) } }
      rescue Timeout
        # Expected exit from the above loop
        ;
      end
      if data.size > 1
        if data.end_with?("\n")
          debug_log("The socket gave us perfectly fine data")
        else
          debug_log("The socket contained garbage (data without newline " +
                    "termination)")
        end
        debug_log("Socket content (#{data.size} bytes):")
        debug_log(data)
      else
        debug_log("The socket is empty")
      end
      debug_log("Fetching remote shell log...")
      begin
        try_for(10) do
          id = (@@request_id += 1)
          cmd = [id, 'call', 'root', 'journalctl -u tails-autotest-remote-shell']
          socket.puts(JSON.dump(cmd))
          socket.flush
          line = socket.readline("\n").chomp("\n")
          response_id, status, ret, out, err = JSON.load(line)
          debug_log("\n" + out)
          assert_equal(id, response_id)
          assert_equal(0, ret)
          true
        end
      rescue Exception => f
        debug_log("Something went wrong while fetching the remote shell log")
        debug_log("#{f.class.name}: #{f}")
      end
    end
    raise e
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
    def self.execute(vm, cmd, **opts)
      opts[:user] ||= "root"
      opts[:spawn] = false unless opts.has_key?(:spawn)
      type = opts[:spawn] ? "spawn" : "call"
      debug_log("#{type}ing as #{opts[:user]}: #{cmd}")
      ret = RemoteShell.communicate(vm, type, opts[:user], cmd, **opts)
      debug_log("#{type} returned: #{ret}") if not(opts[:spawn])
      return ret
    end

    attr_reader :cmd, :returncode, :stdout, :stderr

    def initialize(vm, cmd, **opts)
      @cmd = cmd
      @returncode, @stdout, @stderr = self.class.execute(vm, cmd, **opts)
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

  # An IO-like object that is more or less equivalent to a File object
  # opened in rw mode.
  class File
    def self.open(vm, mode, path, *args, **opts)
      debug_log("opening file #{path} in '#{mode}' mode")
      ret = RemoteShell.communicate(vm, mode, path, *args, **opts)
      if ret.size != 1
        raise RemoteShell::Failure.new("expected 1 value but got #{ret.size}")
      end
      debug_log("#{mode} complete")
      return ret.first
    end

    attr_reader :vm, :path

    def initialize(vm, path)
      @vm, @path = vm, path
    end

    def read()
      Base64.decode64(self.class.open(@vm, 'read', @path))
    end

    def write(data)
      self.class.open(@vm, 'write', @path, Base64.encode64(data))
    end

    def append(data)
      self.class.open(@vm, 'append', @path, Base64.encode64(data))
    end
  end
end
