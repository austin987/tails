require 'resolv'

class OpenPGPKeyserverCommunicationError < StandardError
end

def count_gpg_signatures(key)
  output = $vm.execute_successfully("gpg --batch --list-sigs #{key}",
                                    :user => LIVE_USER).stdout
  output.scan(/^sig/).count
end

def check_for_seahorse_error
  if @screen.exists('GnomeCloseButton.png')
    raise OpenPGPKeyserverCommunicationError.new(
      "Found GnomeCloseButton.png' on the screen"
    )
  end
end

def start_or_restart_seahorse
  assert_not_nil(@withgpgapplet)
  if @withgpgapplet
    seahorse_menu_click_helper('GpgAppletIconNormal.png', 'GpgAppletManageKeys.png')
  else
    step 'I start "Passwords and Keys" via GNOME Activities Overview'
  end
  step 'Seahorse has opened'
end

Then /^the key "([^"]+)" has (less|more) than (\d+) signatures$/ do |key, qualifier, num|
  count = count_gpg_signatures(key)
  case qualifier
  when 'less'
    assert(count < num.to_i, "Expected less than #{num} signatures but found #{count}")
  when 'more'
    assert(count > num.to_i, "Expected more than #{num} signatures but found #{count}")
  else
    raise "Unknown operator #{qualifier} passed"
  end
end

When /^the "([^"]+)" OpenPGP key is not in the live user's public keyring$/ do |keyid|
  assert(!$vm.execute("gpg --batch --list-keys '#{keyid}'",
                      :user => LIVE_USER).success?,
         "The '#{keyid}' key is in the live user's public keyring.")
end

def setup_onion_keyserver
  resolver = Resolv::DNS.new
  keyservers = resolver.getaddresses('pool.sks-keyservers.net').select do |addr|
    addr.class == Resolv::IPv4
  end
  onion_keyserver_address = keyservers.sample
  hkp_port = 11371
  @onion_keyserver_job = chutney_onionservice_redir(
    onion_keyserver_address, hkp_port
  )
end

When /^I fetch the "([^"]+)" OpenPGP key using the GnuPG CLI( without any signatures)?$/ do |keyid, without|
  # Make keyid an instance variable so we can reference it in the Seahorse
  # keysyncing step.
  @fetched_openpgp_keyid = keyid
  if without
    importopts = '--keyserver-options import-clean'
  else
    importopts = ''
  end
  retry_tor(Proc.new { setup_onion_keyserver }) do
    @gnupg_recv_key_res = $vm.execute_successfully(
      "timeout 120 gpg --batch #{importopts} --recv-key '#{@fetched_openpgp_keyid}'",
      :user => LIVE_USER)
    if @gnupg_recv_key_res.failure?
      raise "Fetching keys with the GnuPG CLI failed with:\n" +
            "#{@gnupg_recv_key_res.stdout}\n" +
            "#{@gnupg_recv_key_res.stderr}"
    end
  end
end

When /^the GnuPG fetch is successful$/ do
  assert(@gnupg_recv_key_res.success?,
         "gpg keyserver fetch failed:\n#{@gnupg_recv_key_res.stderr}")
end

When /^the Seahorse operation is successful$/ do
  !@screen.exists('GnomeCloseButton.png')
  $vm.has_process?('seahorse')
end

When /^the "([^"]+)" key is in the live user's public keyring(?: after at most (\d) seconds)?$/ do |keyid, delay|
  delay = 10 unless delay
  try_for(delay.to_i, :msg => "The '#{keyid}' key is not in the live user's public keyring") {
    $vm.execute("gpg --batch --list-keys '#{keyid}'",
                :user => LIVE_USER).success?
  }
end

When /^I start Seahorse( via the OpenPGP Applet)?$/ do |withgpgapplet|
  @withgpgapplet = !!withgpgapplet
  start_or_restart_seahorse
end

Then /^Seahorse has opened$/ do
  @screen.wait('SeahorseWindow.png', 20)
end

Then /^I enable key synchronization in Seahorse$/ do
  step 'process "seahorse" is running'
  @screen.wait_and_click("SeahorseWindow.png", 10)
  seahorse_menu_click_helper('GnomeEditMenu.png', 'SeahorseEditPreferences.png', 'seahorse')
  @screen.wait('SeahorsePreferences.png', 20)
  @screen.type("p", Sikuli::KeyModifier.ALT) # Option: "Publish keys to...".
  @screen.type(Sikuli::Key.DOWN) # select HKP server
  @screen.type("c", Sikuli::KeyModifier.ALT) # Button: "Close"
end

Then /^I synchronize keys in Seahorse$/ do
  recovery_proc = Proc.new do
    setup_onion_keyserver
    # The version of Seahorse in Jessie will abort with a
    # segmentation fault whenever there's any sort of network error while
    # syncing keys. This will usually happens after clicking away the error
    # message. This does not appear to be a problem in Stretch.
    #
    # We'll kill the Seahorse process to avoid waiting for the inevitable
    # segfault. We'll also make sure the process is still running (=  hasn't
    # yet segfaulted) before terminating it.
    if @screen.exists('GnomeCloseButton.png') || !$vm.has_process?('seahorse')
      step 'I kill the process "seahorse"' if $vm.has_process?('seahorse')
      debug_log('Restarting Seahorse.')
      start_or_restart_seahorse
    end
  end

  def change_of_status?
    # Due to a lack of visual feedback in Seahorse we'll break out of the
    # try_for loop below by returning "true" when there's something we can act
    # upon.
    if count_gpg_signatures(@fetched_openpgp_keyid) > 42 || \
      @screen.exists('GnomeCloseButton.png')  || \
      !$vm.has_process?('seahorse')
        true
    end
  end

  retry_tor(recovery_proc) do
    @screen.wait_and_click("SeahorseWindow.png", 10)
    seahorse_menu_click_helper('SeahorseRemoteMenu.png',
                               'SeahorseRemoteMenuSync.png',
                               'seahorse')
    @screen.wait('SeahorseSyncKeys.png', 20)
    @screen.type("s", Sikuli::KeyModifier.ALT) # Button: Sync
    # There's no visual feedback of Seahorse in Tails/Jessie, except on error.
    try_for(120) {
      change_of_status?
    }
    check_for_seahorse_error
    raise OpenPGPKeyserverCommunicationError.new(
      'Seahorse crashed with a segfault.') unless $vm.has_process?('seahorse')
   end
end

When /^I fetch the "([^"]+)" OpenPGP key using Seahorse( via the OpenPGP Applet)?$/ do |keyid, withgpgapplet|
  step "I start Seahorse#{withgpgapplet}"

  def change_of_status?(keyid)
    # Due to a lack of visual feedback in Seahorse we'll break out of the
    # try_for loop below by returning "true" when there's something we can act
    # upon.
    if $vm.execute_successfully(
      "gpg --batch --list-keys '#{keyid}'", :user => LIVE_USER) ||
      @screen.exists('GnomeCloseButton.png')
      true
    end
  end

  recovery_proc = Proc.new do
    setup_onion_keyserver
    @screen.click('GnomeCloseButton.png') if @screen.exists('GnomeCloseButton.png')
    @screen.type("w", Sikuli::KeyModifier.CTRL)
  end
  retry_tor(recovery_proc) do
    @screen.wait_and_click("SeahorseWindow.png", 10)
    seahorse_menu_click_helper('SeahorseRemoteMenu.png',
                               'SeahorseRemoteMenuFind.png',
                               'seahorse')
    @screen.wait('SeahorseFindKeysWindow.png', 10)
    # Seahorse doesn't seem to support searching for fingerprints
    # (https://gitlab.gnome.org/GNOME/seahorse/issues/177)
    @screen.type(keyid + Sikuli::Key.ENTER)
    begin
      @screen.waitAny(['SeahorseFoundKeyResult.png',
                       'GnomeCloseButton.png'], 120)
    rescue FindAnyFailed
      # We may end up here if Seahorse appears to be "frozen".
      # Sometimes--but not always--if we click another window
      # the main Seahorse window will unfreeze, allowing us
      # to continue normally.
      @screen.click("SeahorseSearch.png")
    end
    check_for_seahorse_error
    @screen.click("SeahorseKeyResultWindow.png")
    @screen.click("SeahorseFoundKeyResult.png")
    @screen.click("SeahorseImport.png")
    try_for(120) do
      change_of_status?(keyid)
    end
    check_for_seahorse_error
  end
end

Given /^(GnuPG|Seahorse) is configured to use Chutney's onion keyserver$/ do |app|
  setup_onion_keyserver unless @onion_keyserver_job
  _, _, onion_address, onion_port = chutney_onionservice_info
  case app
  when 'GnuPG'
    # Validate the shipped configuration ...
    server = /keyserver\s+(\S+)$/.match($vm.file_content("/home/#{LIVE_USER}/.gnupg/dirmngr.conf"))[1]
    assert_equal(
      "hkp://#{CONFIGURED_KEYSERVER_HOSTNAME}", server,
      "GnuPG's dirmngr does not use the correct keyserver"
    )
    # ... before replacing it
    $vm.execute_successfully(
      "sed -i 's/#{CONFIGURED_KEYSERVER_HOSTNAME}/#{onion_address}:#{onion_port}/' " +
      "'/home/#{LIVE_USER}/.gnupg/dirmngr.conf'"
    )
  when 'Seahorse'
    # Validate the shipped configuration ...
    @gnome_keyservers = YAML.load(
      $vm.execute_successfully(
        'gsettings get org.gnome.crypto.pgp keyservers',
        user: LIVE_USER
      ).stdout
    )
    assert_equal(1, @gnome_keyservers.count,
                 'Seahorse should only have one keyserver configured.')
    assert_equal(
      'hkp://' + CONFIGURED_KEYSERVER_HOSTNAME, @gnome_keyservers[0],
      "GnuPG's dirmngr does not use the correct keyserver"
    )
    # ... before replacing it
    $vm.execute_successfully(
      "gsettings set org.gnome.crypto.pgp keyservers \"['hkp://#{onion_address}:#{onion_port}']\"",
      user: LIVE_USER
    )
  end
end

Then /^GnuPG's dirmngr uses the configured keyserver$/ do
  _, _, onion_keyserver_address, _ = chutney_onionservice_info
  dirmngr_request = $vm.execute_successfully(
    'gpg-connect-agent --dirmngr "keyserver --hosttable" /bye', user: LIVE_USER
  )
  server = dirmngr_request.stdout.chomp.lines[1].split[4]
  server = /keyserver\s+(\S+)$/.match(
    $vm.file_content("/home/#{LIVE_USER}/.gnupg/dirmngr.conf")
  )[1]
  assert_equal(
    "hkp://#{onion_keyserver_address}:5858", server,
    "GnuPG's dirmngr does not use the correct keyserver"
  )
end
