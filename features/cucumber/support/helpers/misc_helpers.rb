require 'date'
require 'system_timer'

def assert(b, msg = "Assertion failed!")
  raise RuntimeError, msg, caller if ! b
end

# Call block (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout:Error.
def try_for(t, delay = 1, msg = nil)
  begin
    SystemTimer.timeout(t) do
      loop do
        begin
          return true if yield
        rescue Exception
          # noop
        end
        sleep delay
      end
    end
  rescue Timeout::Error => e
    if msg
      raise RuntimeError, msg, caller
    else
      raise e
    end
  end
end

def new_tails_instance
  @vm.stop if @vm
  @vm = VM.new
end

def wait_until_tor_is_working
  try_for(120) { @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; ' +
    'tor_control_getinfo status/circuit-established').stdout  == "1\n" }
end
