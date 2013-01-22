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
    serial = File.new(vm.get_remote_shell_device, "r+")
    serial.puts("sudo -n -H -u " + user + " -s /bin/sh " + "-c \'" + cmd + "\'")
    s = ""
    while (c = serial.read(1)) != "\0" do
      s += c
    end
    serial.close
    return JSON.load(s)
  end

  def success?
    return @returncode == 0
  end

end
