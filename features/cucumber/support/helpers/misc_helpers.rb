require 'date'
require 'system_timer'

def assert(b)
  raise RuntimeError, "Assertion failed!", caller if ! b
end

# Call block (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout:Error.
def try_for(t, delay = 1)
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
  return false
end

def guest_has_network?
  # FIXME: or "ping -ncq1 #{bridge_ip}"?
  @vm.execute("/sbin/ifconfig eth0 | grep -q 'inet addr'").success?
end

def wait_until_remote_shell_is_up
  try_for(120) { @vm.execute('true').success? }
end

def wait_until_tor_is_working
  try_for(120) { @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; ' +
    'tor_control_getinfo status/circuit-established').stdout  == "1\n" }
end

def guest_has_process?(process)
  return @vm.execute("pidof " + process).success?
end
