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

class TryForTimeoutError < Timeout::Error
end

# Call block (ignoring any exceptions it may throw) repeatedly with
# one second breaks until it returns true, or until `timeout` seconds have
# passed when we throw a TryForTimeoutError exception. Nested try_for
# is forbidden, so the block cannot itself call try_for.
def try_for(timeout, options = {})
  options[:delay] ||= 1
  Timeout::timeout(timeout, TryForTimeoutError) do
    loop do
      begin
        return if yield
      rescue NameError, TryForTimeoutError => e
        # Let's not catch our own timeout (note that if we'd have a
        # nested try_for we might catch another try_for's
        # TryForTimeoutError exception here, and that's why such
        # nesting is forbidden). Also, let's not catch what most
        # likely is a typo.
        raise e
      rescue Exception
        # All other exceptions are ignored while trying the block.
      end
      sleep options[:delay]
    end
  end
rescue TryForTimeoutError => e
  msg = options[:msg] || 'try_for() timeout expired'
  raise TryForTimeoutError.new(msg)
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
  if cmd.instance_of?(Array)
    cmd << {:err => [:child, :out]}
  elsif cmd.instance_of?(String)
    cmd += " 2>&1"
  end
  IO.popen(cmd) do |p|
    out = p.readlines.join("\n")
    p.close
    ret = $?
    assert_equal(0, ret, "Command failed (returned #{ret}): #{cmd}:\n#{out}")
    return out
  end
end

# This command will grab all router IP addresses from the Tor
# consensus in the VM + the hardcoded TOR_AUTHORITIES.
def get_all_tor_nodes
  cmd = 'awk "/^r/ { print \$6 }" /var/lib/tor/cached-microdesc-consensus'
  @vm.execute(cmd).stdout.chomp.split("\n") + TOR_AUTHORITIES
end

def get_free_space(machine, path)
  case machine
  when 'host'
    assert(File.exists?(path), "Path '#{path}' not found on #{machine}.")
    free = cmd_helper(["df", path])
  when 'guest'
    assert(@vm.file_exist?(path), "Path '#{path}' not found on #{machine}.")
    free = @vm.execute_successfully("df '#{path}'")
  else
    raise 'Unsupported machine type #{machine} passed.'
  end
  output = free.split("\n").last
  return output.match(/[^\s]\s+[0-9]+\s+[0-9]+\s+([0-9]+)\s+.*/)[1].chomp.to_i
end

def random_string_from_set(set, min_len, max_len)
  len = (min_len..max_len).to_a.sample
  len ||= min_len
  (0..len-1).map { |n| set.sample }.join
end

def random_alpha_string(min_len, max_len = 0)
  alpha_set = ('A'..'Z').to_a + ('a'..'z').to_a
  random_string_from_set(alpha_set, min_len, max_len)
end

def random_alnum_string(min_len, max_len = 0)
  alnum_set = ('A'..'Z').to_a + ('a'..'z').to_a + (0..9).to_a.map { |n| n.to_s }
  random_string_from_set(alnum_set, min_len, max_len)
end
