require 'date'
require 'English'
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
include Test::Unit::Assertions # rubocop:disable Style/MixinUsage

def assert_vmcommand_success(p, msg = nil) # rubocop:disable Naming/MethodParameterName
  assert(p.success?,
         if msg.nil?
           "Command failed: #{p.cmd}\n" \
           "error code: #{p.returncode}\n" \
           "stderr: #{p.stderr}"
         else
           msg
         end)
end

# It's forbidden to throw this exception (or subclasses) in anything
# but try_for() below. Just don't use it anywhere else!
class UniqueTryForTimeoutError < Exception
end

def time_delta(start_time, now)
  elapsed = now - start_time
  # XXX: Drop this version check when we drop support for running the test suite
  # on Debian Stretch.
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.4')
    format('%<elapsed>.2f', elapsed: elapsed)
      .chomp('.00').chomp('.0').chomp('0')
  else
    elapsed.ceil(2)
  end
end

# Call block (ignoring any exceptions it may throw) repeatedly with
# one second breaks until it returns true, or until `timeout` seconds have
# passed when we throw a Timeout::Error exception. If `timeout` is `nil`,
# then we just run the code block with no timeout.
# XXX: giving up on a few worst offenders for now
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity
def try_for(timeout, **options)
  return yield if block_given? && timeout.nil?

  options[:delay] ||= 1
  options[:log] = true if options[:log].nil?
  last_exception = nil
  # Create a unique exception used only for this particular try_for
  # call's Timeout to allow nested try_for:s. If we used the same one,
  # the innermost try_for would catch all outer ones', creating a
  # really strange situation.
  unique_timeout_exception = Class.new(UniqueTryForTimeoutError)
  attempts = 0
  start_time = Time.now
  # rubocop:disable Style/MultilineIfModifier
  Timeout.timeout(timeout, unique_timeout_exception) do
    loop do
      begin
        attempts += 1
        elapsed = time_delta(start_time, Time.now)
        debug_log("try_for: attempt #{attempts} (#{elapsed}s elapsed " \
                  "of #{timeout}s)...") if options[:log]
        if yield
          debug_log('try_for: success!') if options[:log]
          return
        end
        debug_log('try_for: failed by code block ' \
                  'returning failure') if options[:log]
      rescue NameError, UniqueTryForTimeoutError => e
        # NameError most likely means typos, and hiding that is rarely
        # (never?) a good idea, so we rethrow them. See below why we
        # also rethrow *all* the unique exceptions.
        raise e
      rescue StandardError => e
        # Most other exceptions, that inherit from StandardError, are ignored
        # while trying the block. We save the last exception so we can
        # print it in case of a timeout.
        last_exception = e
        debug_log('try_for: failed with exception: ' \
                  "#{last_exception.class}: #{last_exception}") if options[:log]
      rescue Exception => e # rubocop:disable Lint/RescueException
        # Any other exception is rethrown as-is: it is probably not
        # the kind of failure that try_for is supposed to mask.
        # For example, try_for should not prevent a SignalException
        # from being handled by Ruby.
        raise e
      end
      sleep options[:delay]
    end
  end
  # rubocop:enable Style/MultilineIfModifier

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
rescue unique_timeout_exception
  msg = options[:msg] || 'try_for() timeout expired'
  exc_class = options[:exception] || Timeout::Error
  if last_exception
    msg += "\nLast ignored exception was: " \
           "#{last_exception.class}: #{last_exception}"
  end
  raise exc_class, msg
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/CyclomaticComplexity

class TorFailure < StandardError
end

class MaxRetriesFailure < StandardError
end

def force_new_tor_circuit
  debug_log('Forcing new Tor circuit...')
  # Tor rate limits NEWNYM to at most one per 10 second period.
  interval = 10
  if $__last_newnym
    elapsed = Time.now - $__last_newnym
    # We sleep an extra second to avoid tight timings.
    sleep interval - elapsed + 1 if elapsed.positive? && elapsed < interval
  end
  $vm.execute_successfully('tor_control_send "signal NEWNYM"', libs: 'tor')
  $__last_newnym = Time.now
end

# This will retry the block up to MAX_NEW_TOR_CIRCUIT_RETRIES
# times. The block must raise an exception for a run to be considered
# as a failure. After a failure recovery_proc will be called (if
# given) and the intention with it is to bring us back to the state
# expected by the block, so it can be retried.
def retry_tor(recovery_proc = nil, &block)
  tor_recovery_proc = proc do
    force_new_tor_circuit
    recovery_proc&.call
  end

  retry_action($config['MAX_NEW_TOR_CIRCUIT_RETRIES'],
               recovery_proc:  tor_recovery_proc,
               operation_name: 'Tor operation', &block)
end

def retry_action(max_retries, options = {}, &block)
  assert(max_retries.is_a?(Integer), 'max_retries must be an integer')
  options[:recovery_proc] ||= nil
  options[:operation_name] ||= 'Operation'

  retries = 1
  loop do
    begin
      debug_log("retry_action: trying #{options[:operation_name]} (attempt " \
                "#{retries} of #{max_retries})...")
      block.call
      debug_log('retry_action: success!')
      return
    rescue NameError => e
      # NameError most likely means typos, and hiding that is rarely
      # (never?) a good idea, so we rethrow them.
      raise e
    rescue StandardError => e
      if retries <= max_retries
        debug_log("retry_action: #{options[:operation_name]} failed with " \
                  "exception: #{e.class}: #{e.message}")
        options[:recovery_proc]&.call
        retries += 1
      else
        raise MaxRetriesFailure,
              "#{options[:operation_name]} failed (despite retrying " \
              "#{max_retries} times) with\n" \
              "#{e.class}: #{e.message}"
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      # Any other exception is rethrown as-is: it is probably not
      # the kind of failure that retry_action is supposed to mask.
      # For example, retry_action should not prevent a SignalException
      # from being handled by Ruby.
      raise e
    end
  end
end

class TorBootstrapFailure < StandardError
end

def wait_until_tor_is_working
  try_for(270) do
    $vm.execute(
      '/bin/systemctl --quiet is-active tails-tor-has-bootstrapped.target'
    ).success?
  end
rescue Timeout::Error
  # Save Tor logs before erroring out
  File.open("#{$config['TMPDIR']}/log.tor", 'w') do |file|
    $vm.execute(
      'journalctl --no-pager -u tor@default.service > /tmp/tor.journal'
    )
    file.write($vm.file_content('/tmp/tor.journal'))
    file.write($vm.file_content('/var/log/tor/log'))
  end
  raise TorBootstrapFailure, 'Tor failed to bootstrap'
end

def convert_bytes_mod(unit)
  mod = {
    'bytes' => 1,
    'b'     => 1,
    'KB'    => 10**3,
    'k'     => 2**10,
    'KiB'   => 2**10,
    'MB'    => 10**6,
    'M'     => 2**20,
    'MiB'   => 2**20,
    'GB'    => 10**9,
    'G'     => 2**30,
    'GiB'   => 2**30,
    'TB'    => 10**12,
    'T'     => 2**40,
    'TiB'   => 2**40,
  }
  mod[unit] || raise("invalid memory unit '#{unit}'")
end

def convert_to_bytes(size, unit)
  (size * convert_bytes_mod(unit)).to_i
end

def convert_to_MiB(size, unit)
  (size * convert_bytes_mod(unit) / (2**20)).to_i
end

def convert_from_bytes(size, unit)
  size.to_f / convert_bytes_mod(unit)
end

def cmd_helper(cmd, env = {})
  if cmd.instance_of?(Array)
    cmd << { err: [:child, :out] }
  elsif cmd.instance_of?(String)
    cmd += ' 2>&1'
  end
  env = ENV.to_h.merge(env)
  IO.popen(env, cmd) do |p|
    out = p.readlines.join("\n")
    Process.wait(p.pid)
    ret = $CHILD_STATUS
    assert_equal(0, ret, "Command failed (returned #{ret}): #{cmd}:\n#{out}")
    return out
  end
end

def all_tor_hosts
  nodes = []
  chutney_torrcs = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*/torrc"
  )
  chutney_torrcs.each do |torrc|
    File.open(torrc) do |f|
      nodes += f.grep(/^(Or|Dir)Port\b/).map do |line|
        { address: $vmnet.bridge_ip_addr, port: line.split.last.to_i }
      end
    end
  end
  nodes
end

def allowed_hosts_under_tor_enforcement
  all_tor_hosts + @extra_allowed_hosts
end

def get_free_space(machine, path)
  case machine
  when 'host'
    assert(File.exist?(path), "Path '#{path}' not found on #{machine}.")
    free = cmd_helper(['df', path])
  when 'guest'
    assert($vm.file_exist?(path), "Path '#{path}' not found on #{machine}.")
    free = $vm.execute_successfully("df '#{path}'")
  else
    raise "Unsupported machine type #{machine} passed."
  end
  output = free.split("\n").last
  output.match(/[^\s]\s+[0-9]+\s+[0-9]+\s+([0-9]+)\s+.*/)[1].chomp.to_i
end

def random_string_from_set(set, min_len, max_len)
  len = (min_len..max_len).to_a.sample
  len ||= min_len
  (0..len - 1).map { set.sample }.join
end

def random_alpha_string(min_len, max_len = 0)
  alpha_set = ('A'..'Z').to_a + ('a'..'z').to_a
  random_string_from_set(alpha_set, min_len, max_len)
end

def random_alnum_string(min_len, max_len = 0)
  alnum_set = ('A'..'Z').to_a + ('a'..'z').to_a + (0..9).to_a.map(&:to_s)
  random_string_from_set(alnum_set, min_len, max_len)
end

# Sanitize the filename from unix-hostile filename characters
def sanitize_filename(filename, **options)
  options[:replacement] ||= '_'
  bad_unix_filename_chars = Regexp.new('[^A-Za-z0-9_\\-.,+:]')
  filename.gsub(bad_unix_filename_chars, options[:replacement])
end

def info_log_artifact_location(type, path)
  if $config['ARTIFACTS_BASE_URI']
    # Remove any trailing slashes, we'll add one ourselves
    base_url = $config['ARTIFACTS_BASE_URI'].gsub(%r{/*$}, '')
    path = "#{base_url}/#{File.basename(path)}"
  end
  info_log("#{type.capitalize}: #{path}")
end

def notify_user(message)
  alarm_script = $config['NOTIFY_USER_COMMAND']
  return if alarm_script.nil? || alarm_script.empty?

  cmd_helper(alarm_script.gsub('%m', message))
end

def pause(message = 'Paused')
  notify_user(message)
  STDERR.puts
  warn message
  # Ring the ASCII bell for a helpful notification in most terminal
  # emulators.
  STDOUT.write "\a"
  STDERR.puts
  loop do
    warn 'Return/q: Continue; d: Debugging REPL'
    c = STDIN.getch
    case c
    when 'q', "\r", 3.chr # Ctrl+C => 3
      return
    when 'd'
      binding.pry(quiet: true) # rubocop:disable Lint/Debugger
    end
  end
end

# Converts dbus-send replies into a suitable Ruby value
def dbus_send_ret_conv(ret)
  type, val = /^\s*(\S+)\s+(.+)$/m.match(ret)[1, 2]
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
    String  => 'string',
    # XXX:Buster: drop the Fixnum line once we stop supporting Stretch
    Fixnum  => 'int32', # rubocop:disable Lint/UnifiedInteger
    Integer => 'int32',
  }
  typed_args = args.map do |arg|
    type = ruby_type_to_dbus_type[arg.class]
    assert_not_nil(type,
                   "No D-Bus type conversion for Ruby type '#{arg.class}'")
    "#{type}:#{arg}"
  end
  $vm.execute(
    "dbus-send --print-reply --dest=#{service} #{object_path} " \
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

def ffmpeg
  if cmd_helper('lsb_release --short --codename').chomp == 'stretch'
    'avconv'
  else
    'ffmpeg'
  end
end

# This is IO.popen() that ensures that we wait() for the subprocess to
# finish. Please use this instead IO.popen() when running a subprocess
# inside a try_for() or other Timeout::timeout() block!
def popen_wait(*args, **opts)
  p = IO.popen(*args, **opts)
  Process.wait(p.pid)
  p
ensure
  # If popen is run inside a Timeout::timeout() block we might abort
  # while the subprocess is still running and before the above wait()
  # does its clean up, which would leave a defunct process around
  # unless we take care to finish wait():ing.
  begin
    begin
      Process.wait(p.pid)
    rescue Errno::ECHILD
      # Process has already exited.
    else
      begin
        Process.kill('KILL', p.pid)
      rescue IOError, Errno::ESRCH
        # Process has already exited.
      end
    end
  rescue NameError
    # We aborted before p was assigned, so no clean up needed.
  end
end
