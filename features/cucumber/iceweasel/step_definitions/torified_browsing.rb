require 'fileutils'
require 'date'
require 'system_timer'

def wait_until_remote_shell_is_up
  try_for(120, lambda{ @vm.execute('true').success? })
end

def wait_until_tor_is_working
  try_for(120, lambda{ @vm.execute(
    '. /usr/local/lib/tails-shell-library/tor.sh; ' +
    'tor_control_getinfo status/circuit-established',
                                   'root').stdout  == "1\n" })
end

def restore_background
  snapshot = Dir.pwd + "/tmpfs/IceweaselBackgroundDone.state"
  @vm.restore_snapshot(snapshot)
  # Wait for virt-viewer to be available to sikuli. Otherwise we could
  # lose sikuli actions (e.g. key presses) if they come really early
  # after the restore
  @screen.wait("IceweaselRunning.png", 10)

  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  wait_until_remote_shell_is_up
  @vm.execute("service tor stop", "root")
  @vm.host_to_guest_time_sync
  @vm.execute("service tor start", "root")
  wait_until_tor_is_working
end

Given /^I restore the background snapshot if it exists$/ do
  snapshot = Dir.pwd + "/tmpfs/IceweaselBackgroundDone.state"
  if File.exists?(snapshot)
    restore_background
    @background_restored = true
  end
end

Given /^a freshly started Tails$/ do
  next if @background_restored
  @vm.start
  @screen.wait('TailsBootSplash.png', 30)
  # Start the VM remote shell
  @screen.type("\t autotest_never_use_this_option" +
               Sikuli::KEY_RETURN)
  @screen.wait('TailsGreeter.png', 120)
end

Given /^the network traffic is sniffed$/ do
  # The sniffer is external to the restored VM's state, so we can't skip
  # it when restoring the background from a snapshot.
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip, @vm.ip6)
  @sniffer.capture
end

Given /^I log in to a new session$/ do
  next if @background_restored
  @screen.click('TailsGreeterLoginButton.png')
end

# Call `f` (ignoring any exceptions it may throw) repeatedly with one
# second breaks until it returns true, or until `t` seconds have
# passed when we throw Timeout:Error.
def try_for(t, f)
  SystemTimer.timeout(t) do
    loop do
      begin
        return if f.call
      rescue Exception
        # noop
      end
      sleep 1
    end
  end
end

Given /^I have a network connection$/ do
  next if @background_restored
  # Wait until the VM's remote shell is available, which implies
  # that the network is up.
  wait_until_remote_shell_is_up
end

Given /^Tor has bootstrapped$/ do
  next if @background_restored
  # FIXME: A better approach would be to check this via the control
  # port with: GETINFO status/circuit-established
  cmd = 'grep -q "Bootstrapped 100%" /var/log/tor/log'
  try_for(120, lambda{ @vm.execute(cmd, "root").success? })
end

Given /^Iceweasel has autostarted and is not loading a web page$/ do
  next if @background_restored
  @screen.wait("IceweaselRunning.png", 120)

  # Stop iceweasel to load its home page. We do this to prevent Tor
  # from gerring confused in case we save and restore a snapshot in
  # the middle of loading a page.
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type("about:blank" + Sikuli::KEY_RETURN)
end

Given /^the time has synced$/ do
  next if @background_restored
  ["/var/run/tordate/done", "/var/run/htpdate/success"].each do |file|
    try_for(300, lambda{ @vm.execute("test -e #{file}").success? })
  end
end

Given /^I save the background snapshot if it does not exist$/ do
  if !@background_restored
    snapshot = Dir.pwd + "/tmpfs/IceweaselBackgroundDone.state"
    @vm.save_snapshot(snapshot)
    restore_background
  end
end

Then /^I see "([^"]*)" after at most (\d+) seconds$/ do |image, time|
  @screen.wait(image, time.to_i)
end

When /^I open a new tab in Iceweasel$/ do
  @screen.type("t", Sikuli::KEY_CTRL)
end

When /^I open the address "([^"]*)" in Iceweasel$/ do |address|
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type(address + Sikuli::KEY_RETURN)
end

Then /^all Internet traffic has only flowed through Tor$/ do
  @sniffer.stop
  # This command will grab all router IP addresses from the Tor
  # consensus in the VM.
  cmd = 'awk "/^r/ { print \$6 }" /var/lib/tor/cached-microdesc-consensus'
  tor_relays = @vm.execute(cmd, "root").stdout.split("\n")
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, tor_relays)
  if !leaks.empty?
    if !leaks.ipv4_tcp_leaks.empty?
      puts "The following IPv4 TCP non-Tor Internet hosts were contacted:"
      puts leaks.ipv4_tcp_leaks.join("\n")
      puts
    end
    if !leaks.ipv4_nontcp_leaks.empty?
      puts "The following IPv4 non-TCP Internet hosts were contacted:"
      puts leaks.ipv4_nontcp_leaks.join("\n")
      puts
    end
    if !leaks.ipv6_leaks.empty?
      puts "The following IPv6 Internet hosts were contacted:"
      puts leaks.ipv6_leaks.join("\n")
      puts
    end
    pcap_copy = Dir.pwd + "/pcap_with_leaks-" + DateTime.now.to_s
    FileUtils.cp(@sniffer.pcap_file, pcap_copy)
    puts "Full network capture available at: #{pcap_copy}"
    raise "There were network leaks!"
  end
end
