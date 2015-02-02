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
