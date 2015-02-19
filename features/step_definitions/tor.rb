def iptables_parse(iptables_output)
  chains = Hash.new
  cur_chain = nil
  cur_chain_policy = nil
  parser_state = :expecting_chain_def

  iptables_output.split("\n").each do |line|
    line.strip!
    if /^Chain /.match(line)
      assert_equal(:expecting_chain_def, parser_state)
      m = /^Chain (.+) \(policy (.+) \d+ packets, \d+ bytes\)$/.match(line)
      if m.nil?
        m = /^Chain (.+) \(\d+ references\)$/.match(line)
      end
      assert_not_nil m
      _, cur_chain, cur_chain_policy = m.to_a
      chains[cur_chain] = {
        "policy" => cur_chain_policy,
        "rules" => Array.new
      }
      parser_state = :expecting_col_descs
    elsif /^pkts\s/.match(line)
      assert_equal(:expecting_col_descs, parser_state)
      assert_equal(["pkts", "bytes", "target", "prot", "opt",
                    "in", "out", "source", "destination"],
                   line.split(/\s+/))
      parser_state = :expecting_rule_or_empty
    elsif line.empty?
      assert_equal(:expecting_rule_or_empty, parser_state)
      cur_chain = nil
      parser_state = :expecting_chain_def
    else
      assert_equal(:expecting_rule_or_empty, parser_state)
      _, _, target, prot, opt, in_iface, out_iface, source, destination, extra =
        line.split(/\s+/, 10)
      [target, prot, opt, in_iface, out_iface, source, destination].each do |var|
        assert_not_empty(var)
        assert_not_nil(var)
      end
      chains[cur_chain]["rules"] << {
        "rule" => line,
        "target" => target,
        "protocol" => prot,
        "opt" => opt,
        "in_iface" => in_iface,
        "out_iface" => out_iface,
        "source" => source,
        "destination" => destination,
        "extra" => extra
      }
    end
  end
  assert_equal(:expecting_rule_or_empty, parser_state)
  return chains
end

Then /^the firewall's policy is to (.+) all IPv4 traffic$/ do |expected_policy|
  next if @skip_steps_while_restoring_background
  expected_policy.upcase!
  iptables_output = @vm.execute_successfully("iptables -L -n -v").stdout
  chains = iptables_parse(iptables_output)
  ["INPUT", "FORWARD", "OUTPUT"].each do |chain_name|
    policy = chains[chain_name]["policy"]
    assert_equal(expected_policy, policy,
                 "Chain #{chain_name} has unexpected policy #{policy}")
  end
end

Then /^the firewall is configured to only allow the (.+) users? to connect directly to the Internet over IPv4$/ do |users_str|
  next if @skip_steps_while_restoring_background
  users = users_str.split(/, | and /)
  expected_uids = Set.new
  users.each do |user|
    expected_uids << @vm.execute_successfully("id -u #{user}").stdout.to_i
  end
  iptables_output = @vm.execute_successfully("iptables -L -n -v").stdout
  chains = iptables_parse(iptables_output)
  allowed_output = chains["OUTPUT"]["rules"].find_all do |rule|
    !(["DROP", "REJECT", "LOG"].include? rule["target"]) &&
      rule["out_iface"] != "lo"
  end
  uids = Set.new
  allowed_output.each do |rule|
    case rule["target"]
    when "ACCEPT"
      expected_destination = "0.0.0.0/0"
      assert_equal(expected_destination, rule["destination"],
                   "The following rule has an unexpected destination:\n" +
                   rule["rule"])
      next if rule["extra"] == "state RELATED,ESTABLISHED"
      m = /owner UID match (\d+)/.match(rule["extra"])
      assert_not_nil(m)
      uid = m[1].to_i
      uids << uid
      assert(expected_uids.include?(uid),
             "The following rule allows uid #{uid} to access the network, " \
             "but we only expect uids #{expected_uids} (#{users_str}) to " \
             "have such access:\n#{rule["rule"]}")
    when "lan"
      lan_subnets = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      assert(lan_subnets.include?(rule["destination"]),
             "The following lan-targeted rule's destination is " \
             "#{rule["destination"]} which may not be a private subnet:\n" +
             rule["rule"])
    else
      raise "Unexpected iptables OUTPUT chain rule:\n#{rule["rule"]}"
    end
  end
  uids_not_found = expected_uids - uids
  assert(uids_not_found.empty?,
         "Couldn't find rules allowing uids #{uids_not_found.to_a.to_s} " \
         "access to the network")
end

Then /^the firewall's NAT rules only redirect traffic for Tor's TransPort and DNSPort$/ do
  next if @skip_steps_while_restoring_background
  iptables_nat_output = @vm.execute_successfully("iptables -t nat -L -n -v").stdout
  chains = iptables_parse(iptables_nat_output)
  chains.each_pair do |name, chain|
    rules = chain["rules"]
    if name == "OUTPUT"
      good_rules = rules.find_all do |rule|
        rule["target"] == "REDIRECT" &&
          (
           rule["extra"] == "redir ports 9040" ||
           rule["extra"] == "udp dpt:53 redir ports 5353"
          )
      end
      assert_equal(rules, good_rules,
                   "The NAT table's OUTPUT chain contains some unexptected " \
                   "rules:\n" +
                   ((rules - good_rules).map { |r| r["rule"] }).join("\n"))
    else
      assert(rules.empty?,
             "The NAT table contains unexpected rules for the #{name} " \
             "chain:\n" + (rules.map { |r| r["rule"] }).join("\n"))
    end
  end
end

Then /^the firewall is configured to block all IPv6 traffic$/ do
  next if @skip_steps_while_restoring_background
  expected_policy = "DROP"
  ip6tables_output = @vm.execute_successfully("ip6tables -L -n -v").stdout
  chains = iptables_parse(ip6tables_output)
  chains.each_pair do |name, chain|
    policy = chain["policy"]
    assert_equal(expected_policy, policy,
                 "The IPv6 #{name} chain has policy #{policy} but we " \
                 "expected #{expected_policy}")
    rules = chain["rules"]
    bad_rules = rules.find_all do |rule|
      !["DROP", "REJECT", "LOG"].include?(rule["target"])
    end
    assert(bad_rules.empty?,
           "The NAT table's OUTPUT chain contains some unexptected rules:\n" +
           (bad_rules.map { |r| r["rule"] }).join("\n"))
  end
end

Then /^untorified network connections to (\S+) fail$/ do |host|
  next if @skip_steps_while_restoring_background
  expected_stderr = "curl: (7) couldn't connect to host"
  cmd = "unset SOCKS_SERVER ; unset SOCKS5_SERVER ; " \
        "curl --noproxy '*' 'http://#{host}'"
  status = @vm.execute(cmd, LIVE_USER)
  assert(!status.success? && status.stderr[expected_stderr],
         "The command `#{cmd}` didn't fail as expected:\n#{status.to_s}")
end

When /^the system DNS is( still)? using the local DNS resolver$/ do |_|
  next if @skip_steps_while_restoring_background
  resolvconf = @vm.file_content("/etc/resolv.conf")
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
      :grep_monitor_expr => '/curl\>',
      :socksport => 9062
    }
  when "tails-security-check", "tails-upgrade-frontend-wrapper"
    # We only grep connections with ESTABLISHED statate since `perl`
    # is also used by monkeysphere's validation agent, which LISTENs
    {
      :grep_monitor_expr => '\<ESTABLISHED\>.\+/perl\>',
      :socksport => 9062
    }
  when "Tor Browser"
    {
      :grep_monitor_expr => '/firefox\>',
      :socksport => 9150
    }
  when "Gobby"
    {
      :grep_monitor_expr => '/gobby\>',
      :socksport => 9050
    }
  when "SSH"
    {
      :grep_monitor_expr => '/\(connect-proxy\|ssh\)\>',
      :socksport => 9050
    }
  when "whois"
    {
      :grep_monitor_expr => '/whois\>',
      :socksport => 9050
    }
  else
    raise "Unknown application '#{application}' for the stream isolation tests"
  end
end

When /^I monitor the network connections of (.*)$/ do |application|
  next if @skip_steps_while_restoring_background
  @process_monitor_log = "/tmp/netstat.log"
  info = stream_isolation_info(application)
  @vm.spawn("while true; do " +
            "  netstat -taupen | grep \"#{info[:grep_monitor_expr]}\"; " +
            "  sleep 0.1; " +
            "done > #{@process_monitor_log}")
end

Then /^I see that (.+) is properly stream isolated$/ do |application|
  next if @skip_steps_while_restoring_background
  expected_port = stream_isolation_info(application)[:socksport]
  assert_not_nil(@process_monitor_log)
  log_lines = @vm.file_content(@process_monitor_log).split("\n")
  assert(log_lines.size > 0,
         "Couldn't see any connection made by #{application} so " \
         "something is wrong")
  log_lines.each do |line|
    addr_port = line.split(/\s+/)[4]
    assert_equal("127.0.0.1:#{expected_port}", addr_port,
                 "#{application} should use SocksPort #{expected_port} but " \
                 "was seen connecting to #{addr_port}")
  end
end

And /^I re-run tails-security-check$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("/usr/local/bin/tails-security-check", LIVE_USER)
end

And /^I re-run htpdate$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("service htpdate stop ; " \
                           "rm -f /var/run/htpdate/* ; " \
                           "service htpdate start")
  step "the time has synced"
end

And /^I re-run tails-upgrade-frontend-wrapper$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("/usr/local/bin/tails-upgrade-frontend-wrapper", LIVE_USER)
end

And /^I do a whois-lookup of domain (.+)$/ do |domain|
  next if @skip_steps_while_restoring_background
  @vm.execute_successfully("/usr/local/bin/whois '#{domain}'", LIVE_USER)
end

When /^I connect Gobby to "([^"]+)"$/ do |host|
  next if @skip_steps_while_restoring_background
  @screen.wait("GobbyWindow.png", 30)
  @screen.wait("GobbyWelcomePrompt.png", 10)
  @screen.click("GnomeCloseButton.png")
  @screen.wait("GobbyWindow.png", 10)
  @screen.type("t", Sikuli::KeyModifier.CTRL)
  @screen.wait("GobbyConnectPrompt.png", 10)
  @screen.type(host + Sikuli::Key.ENTER)
  @screen.wait("GobbyConnectionComplete.png", 60)
end

When /^the Tor Launcher autostarts$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('TorLauncherWindow.png', 30)
end

When /^I configure some (\w+) pluggable transports in Tor Launcher$/ do |bridge_type|
  next if @skip_steps_while_restoring_background
  bridge_type.downcase!
  bridge_type.capitalize!
  begin
    @bridges = $config["Tor"]["Transports"][bridge_type]
    assert_not_nil(@bridges)
    assert(!@bridges.empty?)
  rescue NoMethodError, AssertionFailedError
    raise(
<<EOF
It seems no #{bridge_type} pluggable transports are defined in your local configuration file (#{LOCAL_CONFIG_FILE}). Example entry:
Tor:
  Transports:
    #{bridge_type}:
      - ipv4_address: 1.2.3.4
        ipv4_port: 443
        fingerprint: 01234567890abcdef01234567890abcdef012345
EOF
)
  end
  @screen.wait_and_click('TorLauncherConfigureButton.png', 10)
  @screen.wait_and_click('TorLauncherNextButton.png', 10)
  @screen.hide_cursor
  @screen.wait_and_click('TorLauncherNextButton.png', 10)
  @screen.wait('TorLauncherBridgePrompt.png', 10)
  @screen.wait_and_click('TorLauncherYesRadioOption.png', 10)
  @screen.wait_and_click('TorLauncherNextButton.png', 10)
  @screen.wait_and_click('TorLauncherBridgeList.png', 10)
  for bridge in @bridges do
    bridge_line = bridge_type.downcase   + " " +
                  bridge["ipv4_address"] + ":" +
                  bridge["ipv4_port"].to_s
    bridge_line += " " + bridge["fingerprint"].to_s if bridge["fingerprint"]
    @screen.type(bridge_line + Sikuli::Key.ENTER)
  end
  @screen.wait_and_click('TorLauncherFinishButton.png', 10)
  @screen.wait('TorLauncherConnectingWindow.png', 10)
  @screen.waitVanish('TorLauncherConnectingWindow.png', 120)
end

When /^all Internet traffic has only flowed through the configured pluggable transports$/ do
  next if @skip_steps_while_restoring_background
  assert_not_nil(@bridges, "No bridges has been configured via the " +
                 "'I configure some ... bridges in Tor Launcher' step")
  bridge_hosts = []
  for bridge in @bridges do
    bridge_hosts << bridge["ipv4_address"]
  end
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, bridge_hosts)
  leaks.assert_no_leaks
end
