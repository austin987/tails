require 'date'
require 'system_timer'

# Call block (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout:Error.
def try_for(t)
  SystemTimer.timeout(t) do
    loop do
      begin
        return true if yield
      rescue Exception
        # noop
      end
      sleep 1
    end
  end
  return false
end

def wait_until_remote_shell_is_up
  try_for(120) { @vm.execute('true').success? }
end

def wait_until_tor_is_working
  try_for(120) { @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; ' +
    'tor_control_getinfo status/circuit-established',
                                   'root').stdout  == "1\n" }
end
