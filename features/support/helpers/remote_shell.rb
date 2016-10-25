require 'json'
require 'socket'
require 'base64'

module RemoteShell
  class Failure < StandardError
  end

  # Counter providing unique id:s for each communicate() call.
  @@request_id ||= 0

  def communicate(vm, *args)
    socket = UNIXSocket.new(vm.remote_shell_socket_path)
    id = (@@request_id += 1)
    socket.puts(JSON.dump([id] + args))
    socket.flush
    loop do
      s = socket.readline.chomp("\n")
      response_id, status, *rest = JSON.load(s)
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

  # An IO-like object that is more or less equivalent to a File object
  # opened in rw mode.
  class File
    def self.open(vm, mode, path, *args)
      debug_log("opening file #{path} in '#{mode}' mode")
      ret = RemoteShell.communicate(vm, mode, path, *args)
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
