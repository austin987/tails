class OpenPGPKeyserverCommunicationError < StandardError
end

def count_gpg_subkeys(key)
  output = $vm.execute_successfully("gpg --batch --list-keys #{key}",
                                    user: LIVE_USER).stdout
  output.scan(/^sub/).count
end

def dirmngr_conf
  "/home/#{LIVE_USER}/.gnupg/dirmngr.conf"
end

Then /^the key "([^"]+)" has no subkeys?$/ do |key|
  count = count_gpg_subkeys(key)
  assert_equal(0, count, "Expected no subkey but found #{count}")
end

Then /^the key "([^"]+)" has (strictly less than|at least) (\d+) subkeys?$/ do |key, qualifier, num|
  count = count_gpg_subkeys(key)
  case qualifier
  when 'strictly less than'
    assert(count < num.to_i,
           "Expected strictly less than #{num} subkeys but found #{count}")
  when 'at least'
    assert(count >= num.to_i,
           "Expected at least #{num} subkeys but found #{count}")
  else
    raise "Unknown operator #{qualifier} passed"
  end
end

When /^the "([^"]+)" OpenPGP key is not in the live user's public keyring$/ do |keyid|
  assert(!$vm.execute("gpg --batch --list-keys '#{keyid}'",
                      user: LIVE_USER).success?,
         "The '#{keyid}' key is in the live user's public keyring.")
end

When /^I fetch the "([^"]+)" OpenPGP key using the GnuPG CLI$/ do |keyid|
  retry_tor do
    @gnupg_recv_key_res = $vm.execute_successfully(
      "timeout 120 gpg --batch --recv-key '#{keyid}'",
      user: LIVE_USER
    )
    if @gnupg_recv_key_res.failure?
      raise "Fetching keys with the GnuPG CLI failed with:\n" \
            "#{@gnupg_recv_key_res.stdout}\n" +
            @gnupg_recv_key_res.stderr.to_s
    end
  end
end

When /^the GnuPG fetch is successful$/ do
  assert(@gnupg_recv_key_res.success?,
         "gpg keyserver fetch failed:\n#{@gnupg_recv_key_res.stderr}")
end

When /^the "([^"]+)" key is in the live user's public keyring(?: after at most (\d) seconds)?$/ do |keyid, delay|
  delay ||= 10
  try_for(delay.to_i,
          msg: "The '#{keyid}' key is not in the live user's public keyring") do
    $vm.execute("gpg --batch --list-keys '#{keyid}'",
                user: LIVE_USER).success?
  end
end

Given /^I delete the "([^"]+)" subkey from the live user's public keyring$/ do |subkeyid|
  $vm.execute("gpg --batch --delete-keys '#{subkeyid}!'",
              user: LIVE_USER).success?
end

def disable_ipv6_for_dirmngr
  # keys.openpgp.org is resolved by dirmngr.
  # By default we would get an IPv6 address here, which works
  # just fine in a normal Tails, but here we exit from Chutney's Tor
  # network that runs on our CI infrastructure, which is IPv4-only, so
  # that would fail. Therefore, let's ensure dirmngr only picks IPv4
  # addresses for keys.openpgp.org.
  if $vm.execute("grep -F --line-regexp disable-ipv6 '#{dirmngr_conf}'")
        .failure?
    $vm.file_append(dirmngr_conf, "disable-ipv6\n")
  end
end

def restart_dirmngr
  $vm.execute_successfully('systemctl --user restart dirmngr.service',
                           user: LIVE_USER)
end

Given /^GnuPG is configured to use a non-Onion keyserver$/ do
  # Validate the shipped configuration ...
  server = /keyserver\s+(\S+)$/.match($vm.file_content(dirmngr_conf))[1]
  assert_equal(
    "hkp://#{CONFIGURED_KEYSERVER_HOSTNAME}", server,
    "GnuPG's dirmngr is not configured to use the correct keyserver"
  )
  # ... before replacing it
  $vm.execute_successfully(
    'sed -i ' \
    "'s|hkp://#{CONFIGURED_KEYSERVER_HOSTNAME}|" \
    "hkps://#{TEST_SUITE_DIRMNGR_KEYSERVER_HOSTNAME}|' " \
    "'#{dirmngr_conf}'"
  )
  disable_ipv6_for_dirmngr
  # Ensure dirmngr picks up the changes we made to its configuration
  restart_dirmngr
end

Then /^GnuPG's dirmngr uses the configured keyserver$/ do
  dirmngr_request = $vm.execute_successfully(
    'gpg-connect-agent --dirmngr "keyserver --hosttable" /bye', user: LIVE_USER
  )
  server = dirmngr_request.stdout.chomp.lines[1].split[4]
  assert_equal(
    TEST_SUITE_DIRMNGR_KEYSERVER_HOSTNAME, server,
    "GnuPG's dirmngr does not use the correct keyserver"
  )
end
