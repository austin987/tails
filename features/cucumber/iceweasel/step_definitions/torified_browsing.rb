require 'fileutils'
require 'date'
require 'system_timer'

Given /^a freshly started Tails$/ do
  @vm.start
  @screen.wait('TailsBootSplash.png', 30)
  # Start the VM remote shell
  @screen.type("\t autotest_never_use_this_option" +
               Sikuli::KEY_RETURN)
  @screen.wait('TailsGreeter.png', 120)
end

Given /^the network traffic is sniffed$/ do
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip)
  @sniffer.capture
end

Given /^I log in to a new session$/ do
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
  # Wait until the VM's remote shell is available, which implies
  # that the network is up.
  try_for(120, lambda{ @vm.execute('true').success? })
end

Given /^Tor has bootstrapped$/ do
  # FIXME: A better approach would be to check this via the control
  # port with: GETINFO status/circuit-established
  cmd = 'grep -q "Bootstrapped 100%" /var/log/tor/log'
  try_for(120, lambda{ @vm.execute(cmd, "root").success? })
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
