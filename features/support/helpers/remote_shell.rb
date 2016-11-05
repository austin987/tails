require 'base64'
require 'json'
require 'socket'
require 'timeout'

module RemoteShell
  class ServerFailure < StandardError
  end

  # This exception is *only* supposed to be use internally in
  # communicate() -- in particular it must not be raised by a
  # Timeout.timeout() wrapping around communicate() or any use of it.
  class SocketReadTimeout < Exception
  end

  # Used to differentiate vs Timeout::Error, which is thrown by
  # try_for() (by default) and often wraps around remote shell usage
  # -- in that case we don't want to catch that "outer" exception in
  # our handling of remote shell timeouts below.
  class Timeout < ServerFailure
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
        # Calling socket.readline() and then just wait for the data to
        # arrive is prone to stalling for some reason. A timed read()
        # can perhaps work around this.
        line_init = nil
        begin
          Object::Timeout.timeout(1, SocketReadTimeout) do
            line_init = socket.read(1)
          end
        rescue SocketReadTimeout
          next
        end
        # There may be a race above: imagine if we time out after
        # reading one byte from the socket, but before it's stored in
        # our variable. That would mean we lose that byte. Note that
        # we always must succeed reading one byte *and* storing it the
        # next time, so at most one byte can be lost. Luckily, since
        # we know what the first byte must be, when can easily detect
        # and correct for this.
        if line_init != '['
          line_init = '[' + line_init
        end
        line = line_init + socket.readline("\n").chomp("\n")
        response_id, status, *rest = JSON.load(line)
        if response_id == id
          if status != "success"
            if status == "error" and rest.class == Array and rest.size == 1
              msg = rest.first
              raise ServerFailure.new("#{msg}")
            else
              raise ServerFailure.new("Uncaught exception: #{status}: #{rest}")
            end
          end
          return rest
        else
          debug_log("Dropped out-of-order remote shell response: " +
                    "got id #{response_id} but expected id #{id}")
        end
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
        raise ServerFailure.new("expected 1 value but got #{ret.size}")
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
