def iptables_chains_parse(iptables, table = "filter", &block)
  assert(block_given?)
  cmd = "#{iptables}-save -c -t #{table} | iptables-xml"
  xml_str = $vm.execute_successfully(cmd).stdout
  rexml = REXML::Document.new(xml_str)
  rexml.get_elements('iptables-rules/table/chain').each do |element|
    yield(
      element.attribute('name').to_s,
      element.attribute('policy').to_s,
      element.get_elements('rule')
    )
  end
end

def ip4tables_chains(table = "filter", &block)
  iptables_chains_parse('iptables', table, &block)
end

def ip6tables_chains(table = "filter", &block)
  iptables_chains_parse('ip6tables', table, &block)
end

def iptables_rules_parse(iptables, chain, table)
  iptables_chains_parse(iptables, table) do |name, _, rules|
    return rules if name == chain
  end
  return nil
end

def iptables_rules(chain, table = "filter")
  iptables_rules_parse("iptables", chain, table)
end

def ip6tables_rules(chain, table = "filter")
  iptables_rules_parse("ip6tables", chain, table)
end

def ip4tables_packet_counter_sum(filters = {})
  pkts = 0
  ip4tables_chains do |name, _, rules|
    next if filters[:tables] && not(filters[:tables].include?(name))
    rules.each do |rule|
      next if filters[:uid] && not(rule.elements["conditions/owner/uid-owner[text()=#{filters[:uid]}]"])
      pkts += rule.attribute('packet-count').to_s.to_i
    end
  end
  return pkts
end

def try_xml_element_text(element, xpath, default = nil)
  node = element.elements[xpath]
  (node.nil? or not(node.has_text?)) ? default : node.text
end

Then /^the firewall's policy is to (.+) all IPv4 traffic$/ do |expected_policy|
  expected_policy.upcase!
  ip4tables_chains do |name, policy, _|
    if ["INPUT", "FORWARD", "OUTPUT"].include?(name)
      assert_equal(expected_policy, policy,
                   "Chain #{name} has unexpected policy #{policy}")
    end
  end
end

Then /^the firewall is configured to only allow the (.+) users? to connect directly to the Internet over IPv4$/ do |users_str|
  users = users_str.split(/, | and /)
  expected_uids = Set.new
  users.each do |user|
    expected_uids << $vm.execute_successfully("id -u #{user}").stdout.to_i
  end
  allowed_output = iptables_rules("OUTPUT").find_all do |rule|
    out_iface = rule.elements['conditions/match/o']
    is_maybe_accepted = rule.get_elements('actions/*').find do |action|
      not(["DROP", "REJECT", "LOG"].include?(action.name))
    end
    is_maybe_accepted &&
    (
      # nil => match all interfaces according to iptables-xml
      out_iface.nil? ||
      ((out_iface.text == 'lo') == (out_iface.attribute('invert').to_s == '1'))
    )
  end
  uids = Set.new
  allowed_output.each do |rule|
    rule.elements.each('actions/*') do |action|
      destination = try_xml_element_text(rule, "conditions/match/d")
      if action.name == "ACCEPT"
        # nil == 0.0.0.0/0 according to iptables-xml
        assert(destination == '0.0.0.0/0' || destination.nil?,
               "The following rule has an unexpected destination:\n" +
               rule.to_s)
        state_cond = try_xml_element_text(rule, "conditions/state/state")
        next if state_cond == "ESTABLISHED"
        assert_not_nil(rule.elements['conditions/owner/uid-owner'])
        rule.elements.each('conditions/owner/uid-owner') do |owner|
          uid = owner.text.to_i
          uids << uid
          assert(expected_uids.include?(uid),
                 "The following rule allows uid #{uid} to access the " +
                 "network, but we only expect uids #{expected_uids.to_a} " +
                 "(#{users_str}) to have such access:\n#{rule.to_s}")
        end
      elsif action.name == "call" && action.elements[1].name == "lan"
        lan_subnets = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        assert(lan_subnets.include?(destination),
               "The following lan-targeted rule's destination is " +
               "#{destination} which may not be a private subnet:\n" +
               rule.to_s)
      else
        raise "Unexpected iptables OUTPUT chain rule:\n#{rule.to_s}"
      end
    end
  end
  uids_not_found = expected_uids - uids
  assert(uids_not_found.empty?,
         "Couldn't find rules allowing uids #{uids_not_found.to_a.to_s} " \
         "access to the network")
end

Then /^the firewall's NAT rules only redirect traffic for Tor's TransPort and DNSPort$/ do
  loopback_address = "127.0.0.1/32"
  tor_onion_addr_space = "127.192.0.0/10"
  tor_trans_port = "9040"
  dns_port = "53"
  tor_dns_port = "5353"
  ip4tables_chains('nat') do |name, _, rules|
    if name == "OUTPUT"
      good_rules = rules.find_all do |rule|
        redirect = rule.get_elements('actions/*').all? do |action|
          action.name == "REDIRECT"
        end
        destination = try_xml_element_text(rule, "conditions/match/d")
        redir_port = try_xml_element_text(rule, "actions/REDIRECT/to-ports")
        redirected_to_trans_port = redir_port == tor_trans_port
        udp_destination_port = try_xml_element_text(rule, "conditions/udp/dport")
        dns_redirected_to_tor_dns_port = (udp_destination_port == dns_port) &&
                                         (redir_port == tor_dns_port)
        redirect &&
        (
         (destination == tor_onion_addr_space && redirected_to_trans_port) ||
         (destination == loopback_address && dns_redirected_to_tor_dns_port)
        )
      end
      bad_rules = rules - good_rules
      assert(bad_rules.empty?,
             "The NAT table's OUTPUT chain contains some unexpected " +
             "rules:\n#{bad_rules}")
    else
      assert(rules.empty?,
             "The NAT table contains unexpected rules for the #{name} " +
             "chain:\n#{rules}")
    end
  end
end

Then /^the firewall is configured to block all external IPv6 traffic$/ do
  ip6_loopback = '::1/128'
  expected_policy = "DROP"
  ip6tables_chains do |name, policy, rules|
    assert_equal(expected_policy, policy,
                 "The IPv6 #{name} chain has policy #{policy} but we " \
                 "expected #{expected_policy}")
    good_rules = rules.find_all do |rule|
      ["DROP", "REJECT", "LOG"].any? do |target|
        rule.elements["actions/#{target}"]
      end \
      ||
      ["s", "d"].all? do |x|
        try_xml_element_text(rule, "conditions/match/#{x}") == ip6_loopback
      end
    end
    bad_rules = rules - good_rules
    assert(bad_rules.empty?,
           "The IPv6 table's #{name} chain contains some unexpected rules:\n" +
           (bad_rules.map { |r| r.to_s }).join("\n"))
  end
end

def firewall_has_dropped_packet_to?(proto, host, port)
  regex = "^Dropped outbound packet: .* "
  regex += "DST=#{Regexp.escape(host)} .* "
  regex += "PROTO=#{Regexp.escape(proto)} "
  regex += ".* DPT=#{port} " if port
  $vm.execute("journalctl --dmesg --output=cat | grep -qP '#{regex}'").success?
end

When /^I open an untorified (TCP|UDP|ICMP) connection to (\S*)(?: on port (\d+))?$/ do |proto, host, port|
  assert(!firewall_has_dropped_packet_to?(proto, host, port),
         "A #{proto} packet to #{host}" +
         (port.nil? ? "" : ":#{port}") +
         " has already been dropped by the firewall")
  @conn_proto = proto
  @conn_host = host
  @conn_port = port
  case proto
  when "TCP"
    assert_not_nil(port)
    cmd = "echo | nc.traditional #{host} #{port}"
    user = LIVE_USER
  when "UDP"
    assert_not_nil(port)
    cmd = "echo | nc.traditional -u #{host} #{port}"
    user = LIVE_USER
  when "ICMP"
    cmd = "ping -c 5 #{host}"
    user = 'root'
  end
  @conn_res = $vm.execute(cmd, :user => user)
end

Then /^the untorified connection fails$/ do
  case @conn_proto
  when "TCP"
    expected_in_stderr = "Connection refused"
    conn_failed = !@conn_res.success? &&
      @conn_res.stderr.chomp.end_with?(expected_in_stderr)
  when "UDP", "ICMP"
    conn_failed = !@conn_res.success?
  end
  assert(conn_failed,
         "The untorified #{@conn_proto} connection didn't fail as expected:\n" +
         @conn_res.to_s)
end

Then /^the untorified connection is logged as dropped by the firewall$/ do
  assert(firewall_has_dropped_packet_to?(@conn_proto, @conn_host, @conn_port),
         "No #{@conn_proto} packet to #{@conn_host}" +
         (@conn_port.nil? ? "" : ":#{@conn_port}") +
         " was dropped by the firewall")
end

When /^the system DNS is(?: still)? using the local DNS resolver$/ do
  resolvconf = $vm.file_content("/etc/resolv.conf")
  bad_lines = resolvconf.split("\n").find_all do |line|
    !line.start_with?("#") && !/^nameserver\s+127\.0\.0\.1$/.match(line)
  end
  assert_empty(bad_lines,
               "The following bad lines were found in /etc/resolv.conf:\n" +
               bad_lines.join("\n"))
end

def stream_isolation_info(application)
  case application
  when "htpdate"
    {
      :grep_monitor_expr => 'users:(("curl"',
      :socksport => 9062
    }
  when "tails-security-check"
    {
      :grep_monitor_expr => 'users:(("tails-security-"',
      :socksport => 9062
    }
  when "tails-upgrade-frontend-wrapper"
    {
      :grep_monitor_expr => 'users:(("tails-iuk-get-u"',
      :socksport => 9062
    }
  when "Tor Browser"
    {
      :grep_monitor_expr => 'users:(("firefox\.real"',
      :socksport => 9150,
      :controller => true,
    }
  when "Gobby"
    {
      :grep_monitor_expr => 'users:(("gobby-0.5"',
      :socksport => 9050
    }
  when "SSH"
    {
      :grep_monitor_expr => 'users:(("\(nc\|ssh\)"',
      :socksport => 9050
    }
  when "whois"
    {
      :grep_monitor_expr => 'users:(("whois"',
      :socksport => 9050
    }
  else
    raise "Unknown application '#{application}' for the stream isolation tests"
  end
end

When /^I monitor the network connections of (.*)$/ do |application|
  @process_monitor_log = "/tmp/ss.log"
  info = stream_isolation_info(application)
  $vm.spawn("while true; do " +
            "  ss -taupen | grep '#{info[:grep_monitor_expr]}'; " +
            "  sleep 0.1; " +
            "done > #{@process_monitor_log}")
end

Then /^I see that (.+) is properly stream isolated$/ do |application|
  info = stream_isolation_info(application)
  expected_ports = [info[:socksport]]
  expected_ports << 9051 if info[:controller]
  assert_not_nil(@process_monitor_log)
  log_lines = $vm.file_content(@process_monitor_log).split("\n")
  assert(log_lines.size > 0,
         "Couldn't see any connection made by #{application} so " \
         "something is wrong")
  log_lines.each do |line|
    ip_port = line.split(/\s+/)[5]
    assert(expected_ports.map { |port| "127.0.0.1:#{port}" }.include?(ip_port),
           "#{application} should only connect to #{expected_ports} but " \
           "was seen connecting to #{ip_port}")
  end
end

And /^I re-run tails-security-check$/ do
  $vm.execute_successfully("tails-security-check", :user => LIVE_USER)
end

And /^I re-run htpdate$/ do
  $vm.execute_successfully("service htpdate stop && " \
                           "rm -f /run/htpdate/* && " \
                           "systemctl --no-block start htpdate.service")
  step "the time has synced"
end

And /^I re-run tails-upgrade-frontend-wrapper$/ do
  $vm.execute_successfully("tails-upgrade-frontend-wrapper", :user => LIVE_USER)
end

When /^I connect Gobby to "([^"]+)"$/ do |host|
  gobby = Dogtail::Application.new('gobby-0.5')
  gobby.child('Welcome to Gobby', roleName: 'label')
  gobby.button('Close').click
  # This indicates that Gobby has finished initializing itself
  # (generating DH parameters, etc.) -- before, the UI is not responsive
  # and our CTRL-t is lost.
  gobby.child('Failed to share documents', roleName: 'label')
  gobby.menu('File').click
  gobby.menuItem('Connect to Server...').click
  @screen.type("t", Sikuli::KeyModifier.CTRL)
  connect_dialog = gobby.dialog('Connect to Server')
  connect_dialog.child('', roleName: 'text').typeText(host)
  connect_dialog.button('Connect').click
  # This looks for the live user's presence entry in the chat, which
  # will only be shown if the connection succeeded.
  try_for(60) { gobby.child(LIVE_USER, roleName: 'table cell'); true }
end

When /^the Tor Launcher autostarts$/ do
  @screen.wait('TorLauncherWindow.png', 60)
end

When /^I configure some (\w+) pluggable transports in Tor Launcher$/ do |bridge_type|
  @screen.wait_and_click('TorLauncherConfigureButton.png', 10)
  @screen.wait_and_click('TorLauncherBridgeCheckbox.png', 10)
  @screen.wait_and_click('TorLauncherBridgeList.png', 10)
  @bridge_hosts = []
  chutney_src_dir = "#{GIT_DIR}/submodules/chutney"
  bridge_dirs = Dir.glob(
    "#{$config['TMPDIR']}/chutney-data/nodes/*#{bridge_type}/"
  )
  bridge_dirs.each do |bridge_dir|
    address = $vmnet.bridge_ip_addr
    port = nil
    fingerprint = nil
    extra = nil
    if bridge_type == 'bridge'
      open(bridge_dir + "/torrc") do |f|
        port = f.grep(/^OrPort\b/).first.split.last
      end
    else
      # This is the pluggable transport case. While we could set a
      # static port via ServerTransportListenAddr we instead let it be
      # picked randomly so an already used port is not picked --
      # Chutney already has issues with that for OrPort selection.
      pt_re = /Registered server transport '#{bridge_type}' at '[^']*:(\d+)'/
      open(bridge_dir + "/notice.log") do |f|
        pt_lines = f.grep(pt_re)
        port = pt_lines.last.match(pt_re)[1]
      end
      if bridge_type == 'obfs4'
        open(bridge_dir + "/pt_state/obfs4_bridgeline.txt") do |f|
          extra = f.readlines.last.chomp.sub(/^.* cert=/, 'cert=')
        end
      end
    end
    open(bridge_dir + "/fingerprint") do |f|
      fingerprint = f.read.chomp.split.last
    end
    @bridge_hosts << { address: address, port: port.to_i }
    bridge_line = bridge_type + " " + address + ":" + port
    [fingerprint, extra].each { |e| bridge_line += " " + e.to_s if e }
    @screen.type(bridge_line + Sikuli::Key.ENTER)
  end
  @screen.hide_cursor
  @screen.wait_and_click('TorLauncherFinishButton.png', 10)
  @screen.wait('TorLauncherConnectingWindow.png', 10)
  @screen.waitVanish('TorLauncherConnectingWindow.png', 120)
end

When /^all Internet traffic has only flowed through the configured pluggable transports$/ do
  assert_not_nil(@bridge_hosts, "No bridges has been configured via the " +
                 "'I configure some ... bridges in Tor Launcher' step")
  assert_all_connections(@sniffer.pcap_file) do |c|
    @bridge_hosts.include?({ address: c.daddr, port: c.dport })
  end
end
