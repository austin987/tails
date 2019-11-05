require 'date'
require 'io/console'
require 'pry'
require 'timeout'
require 'test/unit'

# Test::Unit adds an at_exit hook which, among other things, consumes
# the command-line arguments that were intended for cucumber. If
# e.g. `--format` was passed it will throw an error since it's not a
# valid option for Test::Unit, and it throwing an error at this time
# (at_exit) will make Cucumber think it failed and consequently exit
# with an error. Fooling Test::Unit that this hook has already run
# works around this craziness.
Test::Unit.run = true

# Make all the assert_* methods easily accessible in any context.
include Test::Unit::Assertions

def assert_vmcommand_success(p, msg = nil)
  assert(p.success?, msg.nil? ? "Command failed: #{p.cmd}\n" + \
                                "error code: #{p.returncode}\n" \
                                "stderr: #{p.stderr}" : \
                                msg)
end

# It's forbidden to throw this exception (or subclasses) in anything
# but try_for() below. Just don't use it anywhere else!
class UniqueTryForTimeoutError < Exception
end

# Call block (ignoring any exceptions it may throw) repeatedly with
# one second breaks until it returns true, or until `timeout` seconds have
# passed when we throw a Timeout::Error exception. If `timeout` is `nil`,
# then we just run the code block with no timeout.
def try_for(timeout, options = {})
  if block_given? && timeout.nil?
    return yield
  end
  options[:delay] ||= 1
  last_exception = nil
  # Create a unique exception used only for this particular try_for
  # call's Timeout to allow nested try_for:s. If we used the same one,
  # the innermost try_for would catch all outer ones', creating a
  # really strange situation.
  unique_timeout_exception = Class.new(UniqueTryForTimeoutError)
  Timeout::timeout(timeout, unique_timeout_exception) do
    loop do
      begin
        return if yield
      rescue NameError, UniqueTryForTimeoutError => e
        # NameError most likely means typos, and hiding that is rarely
        # (never?) a good idea, so we rethrow them. See below why we
        # also rethrow *all* the unique exceptions.
        raise e
      rescue Exception => e
        # All other exceptions are ignored while trying the
        # block. Well we save the last exception so we can print it in
        # case of a timeout.
        last_exception = e
      end
      sleep options[:delay]
    end
  end
  # At this point the block above either succeeded and we'll return,
  # or we are throwing an exception. If the latter, we either have a
  # NameError that we'll not catch (and will any try_for below us in
  # the stack), or we have a unique exception. That can mean one of
  # two things:
  # 1. it's the one unique to this try_for, and in that case we'll
  #    catch it, rethrowing it as something that will be ignored by
  #    inside the blocks of all try_for:s below us in the stack.
  # 2. it's an exception unique to another try_for. Assuming that we
  #    do not throw the unique exceptions in any other place or way
  #    than we do it in this function, this means that there is a
  #    try_for below us in the stack to which this exception must be
  #    unique to.
  # Let 1 be the base step, and 2 the inductive step, and we have a
  # inductive argument for the correctness of nested try_for. It shows
  # that for an arbitrary large stack of try_for:s, any of the unique
  # exceptions will be caught only by the try_for instance it is
  # unique to, and all try_for:s in between will ignore it.
rescue unique_timeout_exception => e
  msg = options[:msg] || 'try_for() timeout expired'
  exc_class = options[:exception] || Timeout::Error
  if last_exception
    msg += "\nLast ignored exception was: " +
           "#{last_exception.class}: #{last_exception}"
  end
  raise exc_class.new(msg)
end

class TorFailure < StandardError
end

class MaxRetriesFailure < StandardError
end

def force_new_tor_circuit()
  debug_log("Forcing new Tor circuit...")
  # Tor rate limits NEWNYM to at most one per 10 second period.
  interval = 10
  if $__last_newnym
    elapsed = Time.now - $__last_newnym
    # We sleep an extra second to avoid tight timings.
    sleep interval - elapsed + 1 if 0 < elapsed && elapsed < interval
  end
  $vm.execute_successfully('tor_control_send "signal NEWNYM"', :libs => 'tor')
  $__last_newnym = Time.now
end

# This will retry the block up to MAX_NEW_TOR_CIRCUIT_RETRIES
# times. The block must raise an exception for a run to be considered
# as a failure. After a failure recovery_proc will be called (if
# given) and the intention with it is to bring us back to the state
# expected by the block, so it can be retried.
def retry_tor(recovery_proc = nil, &block)
  tor_recovery_proc = Proc.new do
    force_new_tor_circuit
    recovery_proc.call if recovery_proc
  end

  retry_action($config['MAX_NEW_TOR_CIRCUIT_RETRIES'],
               :recovery_proc => tor_recovery_proc,
               :operation_name => 'Tor operation', &block)
end

def retry_action(max_retries, options = {}, &block)
  assert(max_retries.is_a?(Integer), "max_retries must be an integer")
  options[:recovery_proc] ||= nil
  options[:operation_name] ||= 'Operation'

  retries = 1
  loop do
    begin
      block.call
      return
    rescue NameError => e
      # NameError most likely means typos, and hiding that is rarely
      # (never?) a good idea, so we rethrow them.
      raise e
    rescue Exception => e
      if retries <= max_retries
        debug_log("#{options[:operation_name]} failed (Try #{retries} of " +
                  "#{max_retries}) with:\n" +
                  "#{e.class}: #{e.message}")
        options[:recovery_proc].call if options[:recovery_proc]
        retries += 1
      else
        raise MaxRetriesFailure.new("#{options[:operation_name]} failed (despite retrying " +
                                    "#{max_retries} times) with\n" +
                                    "#{e.class}: #{e.message}")
      end
    end
  end
end

alias :retry_times :retry_action

class TorBootstrapFailure < StandardError
end

def wait_until_tor_is_working
  try_for(270) { $vm.execute('/bin/systemctl --quiet is-active tails-tor-has-bootstrapped.target').success? }
rescue Timeout::Error
  # Save Tor logs before erroring out
  File.open("#{$config["TMPDIR"]}/log.tor", 'w') { |file|
    $vm.execute('journalctl --no-pager -u tor@default.service > /tmp/tor.journal')
    file.write($vm.file_content('/tmp/tor.journal'))
    file.write($vm.file_content('/var/log/tor/log'))
  }
  raise TorBootstrapFailure.new('Tor failed to bootstrap')
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

def cmd_helper(cmd, env = {})
  if cmd.instance_of?(Array)
    cmd << {:err => [:child, :out]}
  elsif cmd.instance_of?(String)
    cmd += " 2>&1"
  end
  env = ENV.to_h.merge(env)
  IO.popen(env, cmd) do |p|
    out = p.readlines.join("\n")
    p.close
    ret = $?
    assert_equal(0, ret, "Command failed (returned #{ret}): #{cmd}:\n#{out}")
    return out
  end
end

def all_tor_hosts
  nodes = Array.new
  chutney_torrcs = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*/torrc"
  )
  chutney_torrcs.each do |torrc|
    open(torrc) do |f|
      nodes += f.grep(/^(Or|Dir)Port\b/).map do |line|
        { address: $vmnet.bridge_ip_addr, port: line.split.last.to_i }
      end
    end
  end
  return nodes
end

def allowed_hosts_under_tor_enforcement
  all_tor_hosts + @extra_allowed_hosts
end

def get_free_space(machine, path)
  case machine
  when 'host'
    assert(File.exists?(path), "Path '#{path}' not found on #{machine}.")
    free = cmd_helper(["df", path])
  when 'guest'
    assert($vm.file_exist?(path), "Path '#{path}' not found on #{machine}.")
    free = $vm.execute_successfully("df '#{path}'")
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

# Sanitize the filename from unix-hostile filename characters
def sanitize_filename(filename, options = {})
  options[:replacement] ||= '_'
  bad_unix_filename_chars = Regexp.new("[^A-Za-z0-9_\\-.,+:]")
  filename.gsub(bad_unix_filename_chars, options[:replacement])
end

def info_log_artifact_location(type, path)
  if $config['ARTIFACTS_BASE_URI']
    # Remove any trailing slashes, we'll add one ourselves
    base_url = $config['ARTIFACTS_BASE_URI'].gsub(/\/*$/, "")
    path = "#{base_url}/#{File.basename(path)}"
  end
  info_log("#{type.capitalize}: #{path}")
end

def notify_user(message)
  alarm_script = $config['NOTIFY_USER_COMMAND']
  return if alarm_script.nil? || alarm_script.empty?
  cmd_helper(alarm_script.gsub('%m', message))
end

def pause(message = "Paused")
  notify_user(message)
  STDERR.puts
  STDERR.puts message
  # Ring the ASCII bell for a helpful notification in most terminal
  # emulators.
  STDOUT.write "\a"
  STDERR.puts
  loop do
    STDERR.puts "Return: Continue; d: Debugging REPL"
    c = STDIN.getch
    case c
    when "\r"
      return
    when "d"
      binding.pry(quiet: true)
    end
  end
end

# Converts dbus-send replies into a suitable Ruby value
def dbus_send_ret_conv(ret)
  type, val = /^\s*(\S+)\s+(.+)$/m.match(ret)[1,2]
  case type
  when 'string'
    # Unquote
    val[1...-1]
  when 'int32'
    val.to_i
  when 'array'
    # Drop array start/stop markers ([])
    val.split("\n")[1...-1].map { |e| dbus_send_ret_conv(e) }
  else
    raise "No Ruby type conversion for D-Bus type '#{type}'"
  end
end

def dbus_send_get_shellcommand(service, object_path, method, *args, **opts)
  opts ||= {}
  ruby_type_to_dbus_type = {
    String => 'string',
    Fixnum => 'int32',
  }
  typed_args = args.map do |arg|
    type = ruby_type_to_dbus_type[arg.class]
    assert_not_nil(type, "No D-Bus type conversion for Ruby type '#{arg.class}'")
    "#{type}:#{arg}"
  end
  $vm.execute(
    "dbus-send --print-reply --dest=#{service} #{object_path} " +
    "    #{method} #{typed_args.join(' ')}",
    **opts
  )
end

def dbus_send(*args, **opts)
  opts ||= {}
  opts[:return_shellcommand] ||= false
  c = dbus_send_get_shellcommand(*args, **opts)
  return c if opts[:return_shellcommand]
  assert_vmcommand_success(c)
  # The first line written is about timings and other stuff we don't
  # care about; we only care about the return values.
  ret_lines = c.stdout.split("\n")
  ret_lines.shift
  ret = ret_lines.join("\n")
  dbus_send_ret_conv(ret)
end
