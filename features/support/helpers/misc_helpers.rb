require 'date'
require 'timeout'
require 'test/unit'

# Make all the assert_* methods easily accessible in any context.
include Test::Unit::Assertions

def assert_vmcommand_success(p, msg = nil)
  assert(p.success?, msg.nil? ? "Command failed: #{p.cmd}\n" + \
                                "error code: #{p.returncode}\n" \
                                "stderr: #{p.stderr}" : \
                                msg)
end

# Call block (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout::Error. As a precondition, the code
# block cannot throw Timeout::Error.
def try_for(t, options = {})
  options[:delay] ||= 1
  begin
    Timeout::timeout(t) do
      loop do
        begin
          return true if yield
        rescue NameError => e
          raise e
        rescue Timeout::Error => e
          if options[:msg]
            raise RuntimeError, options[:msg], caller
          else
            raise e
          end
        rescue Exception
          # noop
        end
        sleep options[:delay]
      end
    end
  rescue Timeout::Error => e
    if options[:msg]
      raise RuntimeError, options[:msg], caller
    else
      raise e
    end
  end
end

def wait_until_tor_is_working
  try_for(270) { @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; tor_is_working').success? }
end

def convert_bytes_mod(unit)
  case unit
  when "bytes", "b" then mod = 1
  when "KB"         then mod = 10**3
  when "k", "KiB"   then mod = 2**10
  when "MB"         then mod = 10**6
  when "M", "MiB"   then mod = 2**20
  when "GB"         then mod = 10**9
  when "G", "GiB"   then mod = 2**30
  when "TB"         then mod = 10**12
  when "T", "TiB"   then mod = 2**40
  else
    raise "invalid memory unit '#{unit}'"
  end
  return mod
end

def convert_to_bytes(size, unit)
  return (size*convert_bytes_mod(unit)).to_i
end

def convert_to_MiB(size, unit)
  return (size*convert_bytes_mod(unit) / (2**20)).to_i
end

def convert_from_bytes(size, unit)
  return size.to_f/convert_bytes_mod(unit).to_f
end

def cmd_helper(cmd)
  IO.popen(cmd + " 2>&1") do |p|
    out = p.readlines.join("\n")
    p.close
    ret = $?
    assert_equal(0, ret, "Command failed (returned #{ret}): #{cmd}:\n#{out}")
    return out
  end
end

# This command will grab all router IP addresses from the Tor
# consensus in the VM.
def get_tor_relays
  cmd = 'awk "/^r/ { print \$6 }" /var/lib/tor/cached-microdesc-consensus'
  @vm.execute(cmd).stdout.chomp.split("\n")
end

def get_free_space(machine, path)
  case machine
  when 'host'
    assert(File.exists?(path), "Path '#{path}' not found on #{machine}.")
    free = cmd_helper("df '#{path}'")
  when 'guest'
    assert(@vm.file_exist?(path), "Path '#{path}' not found on #{machine}.")
    free = @vm.execute_successfully("df '#{path}'")
  else
    raise 'Unsupported machine type #{machine} passed.'
  end
  output = free.split("\n").last
  return output.match(/[^\s]\s+[0-9]+\s+[0-9]+\s+([0-9]+)\s+.*/)[1].chomp.to_i
end
