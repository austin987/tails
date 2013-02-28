require 'date'
require 'system_timer'

def assert(b, msg = "Assertion failed!")
  raise RuntimeError, msg, caller if ! b
end

# Call block (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout:Error.
def try_for(t, options = {})
  options[:delay] ||= 1
  begin
    SystemTimer.timeout(t) do
      loop do
        begin
          return true if yield
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
  try_for(120) { @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; ' +
    'tor_control_getinfo status/circuit-established').stdout  == "1\n" }
end

def convert_to_bytes(size, unit)
  case unit
  when "b"        then mod = 1
  when "KB"       then mod = 10**3
  when "k", "KiB" then mod = 2**10
  when "MB"       then mod = 10**6
  when "M", "MiB" then mod = 2**20
  when "GB"       then mod = 10**9
  when "G", "GiB" then mod = 2**30
  when "TB"       then mod = 10**12
  when "T", "TiB" then mod = 2**40
  else
    raise "invalid memory unit"
  end
  return size*mod
end
