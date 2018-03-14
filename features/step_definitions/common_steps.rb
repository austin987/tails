require 'fileutils'

def post_vm_start_hook
  # Sometimes the first click is lost (presumably it's used to give
  # focus to virt-viewer or similar) so we do that now rather than
  # having an important click lost. The point we click should be
  # somewhere where no clickable elements generally reside.
  @screen.click_point(@screen.w - 1, @screen.h/2)
end

def context_menu_helper(top, bottom, menu_item)
  try_for(60) do
    t = @screen.wait(top, 10)
    b = @screen.wait(bottom, 10)
    # In Sikuli, lower x == closer to the left, lower y == closer to the top
    assert(t.y < b.y)
    center = Sikuli::Location.new(((t.x + t.w) + b.x)/2,
                                  ((t.y + t.h) + b.y)/2)
    @screen.right_click(center)
    @screen.hide_cursor
    @screen.wait_and_click(menu_item, 10)
    return
  end
end

def post_snapshot_restore_hook
  $vm.wait_until_remote_shell_is_up
  post_vm_start_hook

  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  if $vm.has_network?
    if $vm.execute("systemctl --quiet is-active tor@default.service").success?
      $vm.execute("systemctl stop tor@default.service")
      $vm.execute("systemctl --no-block restart tails-tor-has-bootstrapped.target")
      $vm.host_to_guest_time_sync
      $vm.execute("systemctl start tor@default.service")
      wait_until_tor_is_working
    end
  else
    $vm.host_to_guest_time_sync
  end
end

Given /^a computer$/ do
  $vm.destroy_and_undefine if $vm
  $vm = VM.new($virt, VM_XML_PATH, $vmnet, $vmstorage, DISPLAY)
end

Given /^the computer is set to boot from the Tails DVD$/ do
  $vm.set_cdrom_boot(TAILS_ISO)
end

Given /^the computer is set to boot from (.+?) drive "(.+?)"$/ do |type, name|
  $vm.set_disk_boot(name, type.downcase)
end

Given /^I (temporarily )?create an? (\d+) ([[:alpha:]]+) disk named "([^"]+)"$/ do |temporary, size, unit, name|
  $vm.storage.create_new_disk(name, {:size => size, :unit => unit,
                                     :type => "qcow2"})
  add_after_scenario_hook { $vm.storage.delete_volume(name) } if temporary
end

Given /^I plug (.+) drive "([^"]+)"$/ do |bus, name|
  $vm.plug_drive(name, bus.downcase)
  if $vm.is_running?
    step "drive \"#{name}\" is detected by Tails"
  end
end

Then /^drive "([^"]+)" is detected by Tails$/ do |name|
  raise "Tails is not running" unless $vm.is_running?
  try_for(10, :msg => "Drive '#{name}' is not detected by Tails") do
    $vm.disk_detected?(name)
  end
end

Given /^the network is plugged$/ do
  $vm.plug_network
end

Given /^the network is unplugged$/ do
  $vm.unplug_network
end

Given /^the network connection is ready(?: within (\d+) seconds)?$/ do |timeout|
  timeout ||= 30
  try_for(timeout.to_i) { $vm.has_network? }
end

Given /^the hardware clock is set to "([^"]*)"$/ do |time|
  $vm.set_hardware_clock(DateTime.parse(time).to_time)
end

Given /^I capture all network traffic$/ do
  @sniffer = Sniffer.new("sniffer", $vmnet)
  @sniffer.capture
  add_after_scenario_hook do
    @sniffer.stop
    @sniffer.clear
  end
end

Given /^I set Tails to boot with options "([^"]*)"$/ do |options|
  @boot_options = options
end

When /^I start the computer$/ do
  assert(!$vm.is_running?,
         "Trying to start a VM that is already running")
  $vm.start
  post_vm_start_hook
end

Given /^I start Tails( from DVD)?( with network unplugged)?( and I login)?$/ do |dvd_boot, network_unplugged, do_login|
  step "the computer is set to boot from the Tails DVD" if dvd_boot
  if network_unplugged
    step "the network is unplugged"
  else
    step "the network is plugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
  if do_login
    step "I log in to a new session"
    if network_unplugged
      step "all notifications have disappeared"
    else
      step "Tor is ready"
      step "all notifications have disappeared"
      step "available upgrades have been checked"
    end
  end
end

Given /^I start Tails from (.+?) drive "(.+?)"( with network unplugged)?( and I login( with persistence enabled)?)?$/ do |drive_type, drive_name, network_unplugged, do_login, persistence_on|
  step "the computer is set to boot from #{drive_type} drive \"#{drive_name}\""
  if network_unplugged
    step "the network is unplugged"
  else
    step "the network is plugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
  if do_login
    step "I enable persistence" if persistence_on
    step "I log in to a new session"
    if network_unplugged
      step "all notifications have disappeared"
    else
      step "Tor is ready"
      step "all notifications have disappeared"
      step "available upgrades have been checked"
    end
  end
end

When /^I power off the computer$/ do
  assert($vm.is_running?,
         "Trying to power off an already powered off VM")
  $vm.power_off
end

When /^I cold reboot the computer$/ do
  step "I power off the computer"
  step "I start the computer"
end

When /^I destroy the computer$/ do
  $vm.destroy_and_undefine
end

def boot_menu_cmdline_image
  case @os_loader
  when "UEFI"
    'TailsBootMenuKernelCmdlineUEFI.png'
  else
    'TailsBootMenuKernelCmdline.png'
  end
end

def boot_menu_tab_msg_image
  case @os_loader
  when "UEFI"
    'TailsBootSplashTabMsgUEFI.png'
  else
    'TailsBootSplashTabMsg.png'
  end
end

Given /^Tails is at the boot menu's cmdline( after rebooting)?$/ do |reboot|
  boot_timeout = 3*60
  # Simply looking for the boot splash image is not robust; sometimes
  # sikuli is not fast enough to see it. Here we hope that spamming
  # TAB, which will halt the boot process by showing the prompt for
  # the kernel cmdline, will make this a bit more robust. We want this
  # spamming to happen in parallel with Sikuli waiting for the image,
  # but multi-threading etc is working extremely poor in our Ruby +
  # jrb environment when Sikuli is involved. Hence we run the spamming
  # from a separate process.
  tab_spammer_code = <<-EOF
    require 'libvirt'
    tab_key_code = 0xf
    virt = Libvirt::open("qemu:///system")
    begin
      domain = virt.lookup_domain_by_name('#{$vm.domain_name}')
      loop do
        domain.send_key(Libvirt::Domain::KEYCODE_SET_LINUX, 0, [tab_key_code])
        sleep 0.1
      end
    ensure
      virt.close
    end
  EOF
  # Our UEFI firmware (OVMF) has the interesting "feature" that pressing
  # any button will open its setup menu, so we have to exit the setup,
  # and to not have the TAB spammer potentially interfering we pause
  # it meanwhile.
  dealt_with_uefi_setup = false
  # The below code is not completely reliable, so we might have to
  # retry by rebooting.
  try_for(boot_timeout) do
    begin
      tab_spammer = IO.popen(['ruby', '-e', tab_spammer_code])
      if not(dealt_with_uefi_setup) && @os_loader == 'UEFI'
        @screen.wait('UEFIFirmwareSetup.png', 30)
        Process.kill("TSTP", tab_spammer.pid)
        @screen.type(Sikuli::Key.ENTER)
        Process.kill("CONT", tab_spammer.pid)
        dealt_with_uefi_setup = true
      end
      @screen.wait(boot_menu_cmdline_image, 15)
    rescue FindFailed => e
      debug_log('We missed the boot menu before we could deal with it, ' +
                'resetting...')
      dealt_with_uefi_setup = false
      $vm.reset
      raise e
    ensure
      Process.kill("TERM", tab_spammer.pid)
      tab_spammer.close
    end
    true
  end
end

Given /^the computer (re)?boots Tails$/ do |reboot|
  step "Tails is at the boot menu's cmdline" + (reboot ? ' after rebooting' : '')
  @screen.type(" autotest_never_use_this_option blacklist=psmouse #{@boot_options}" +
               Sikuli::Key.ENTER)
  @screen.wait('TailsGreeter.png', 5*60)
  $vm.wait_until_remote_shell_is_up
  step 'I configure Tails to use a simulated Tor network'
end

Given /^I log in to a new session(?: in )?(|German)$/ do |lang|
  case lang
  when 'German'
    @language = "German"
    @screen.wait_and_click('TailsGreeterLanguage.png', 10)
    @screen.wait('TailsGreeterLanguagePopover.png', 10)
    @screen.type(@language)
    sleep(2) # Gtk needs some time to filter the results
    @screen.type(Sikuli::Key.ENTER)
    @screen.wait_and_click("TailsGreeterLoginButton#{@language}.png", 10)
  when ''
    @screen.wait_and_click('TailsGreeterLoginButton.png', 10)
  else
    raise "Unsupported language: #{lang}"
  end
  step 'Tails Greeter has applied all settings'
  step 'the Tails desktop is ready'
end

def open_greeter_additional_settings
  @screen.click('TailsGreeterAddMoreOptions.png')
  @screen.wait('TailsGreeterAdditionalSettingsDialog.png', 10)
end

Given /^I open Tails Greeter additional settings dialog$/ do
  open_greeter_additional_settings()
end

Given /^I enable the specific Tor configuration option$/ do
  open_greeter_additional_settings()
  @screen.wait_and_click('TailsGreeterNetworkConnection.png', 30)
  @screen.wait_and_click("TailsGreeterSpecificTorConfiguration.png", 10)
  @screen.wait_and_click("TailsGreeterAdditionalSettingsAdd.png", 10)
end

Given /^I set an administration password$/ do
  open_greeter_additional_settings()
  @screen.wait_and_click("TailsGreeterAdminPassword.png", 20)
  @screen.type(@sudo_password)
  @screen.type(Sikuli::Key.TAB)
  @screen.type(@sudo_password)
  @screen.type(Sikuli::Key.ENTER)
end

Given /^Tails Greeter has applied all settings$/ do
  # I.e. it is done with PostLogin, which is ensured to happen before
  # a logind session is opened for LIVE_USER.
  try_for(120) {
    $vm.execute_successfully("loginctl").stdout
      .match(/^\s*\S+\s+\d+\s+#{LIVE_USER}\s+seat\d+\s+\S+\s*$/) != nil
  }
end

Given /^the Tails desktop is ready$/ do
  desktop_started_picture = "GnomeApplicationsMenu#{@language}.png"
  @screen.wait(desktop_started_picture, 180)
  # Workaround #13461 by restarting nautilus-desktop
  # if Desktop icons are not visible
  begin
    @screen.wait("DesktopTailsDocumentation.png", 30)
  rescue FindFailed
    step 'I kill the process "nautilus-desktop"'
    $vm.spawn('nautilus-desktop', user: LIVE_USER)
    @screen.wait("DesktopTailsDocumentation.png", 30)
  end
  # Disable screen blanking since we sometimes need to wait long
  # enough for it to activate, which can mess with Sikuli wait():ing
  # for some image.
  $vm.execute_successfully(
    'gsettings set org.gnome.desktop.session idle-delay 0',
    :user => LIVE_USER
  )
  # We need to enable the accessibility toolkit for dogtail.
  $vm.execute_successfully(
    'gsettings set org.gnome.desktop.interface toolkit-accessibility true',
    :user => LIVE_USER,
  )
end

When /^I see the "(.+)" notification(?: after at most (\d+) seconds)?$/ do |title, timeout|
  timeout = timeout ? timeout.to_i : nil
  gnome_shell = Dogtail::Application.new('gnome-shell')
  notification_list = gnome_shell.child(
    'No Notifications', roleName: 'label', showingOnly: false
  ).parent.parent
  try_for(timeout) do
    notification_list.child?(title, roleName: 'label', showingOnly: false)
  end
end

Given /^Tor is ready$/ do
  step "Tor has built a circuit"
  step "the time has synced"
  begin
    try_for(30) { $vm.execute('systemctl is-system-running').success? }
  rescue Timeout::Error
    jobs = $vm.execute('systemctl list-jobs').stdout
    units_status = $vm.execute('systemctl').stdout
    raise "The system is not fully running yet:\n#{jobs}\n#{units_status}"
  end
end

Given /^Tor has built a circuit$/ do
  wait_until_tor_is_working
end

class TimeSyncingError < StandardError
end

Given /^the time has synced$/ do
  begin
    ["/run/tordate/done", "/run/htpdate/success"].each do |file|
      try_for(300) { $vm.execute("test -e #{file}").success? }
    end
  rescue
    File.open("#{$config["TMPDIR"]}/log.htpdate", 'w') do |file|
      file.write($vm.execute('cat /var/log/htpdate.log').stdout)
    end
    raise TimeSyncingError.new("Time syncing failed")
  end
end

Given /^available upgrades have been checked$/ do
  try_for(300) {
    $vm.execute("test -e '/run/tails-upgrader/checked_upgrades'").success?
  }
end

When /^I start the Tor Browser( in offline mode)?$/ do |offline|
  step 'I start "Tor Browser" via GNOME Activities Overview'
  if offline
    offline_prompt = Dogtail::Application.new('zenity')
                     .dialog('Tor is not ready')
    offline_prompt.button('Start Tor Browser').click
  end
  step "the Tor Browser has started#{offline}"
  if offline
    step 'the Tor Browser shows the "The proxy server is refusing connections" error'
  end
end

Given /^the Tor Browser (?:has started|starts)( in offline mode)?$/ do |offline|
  try_for(60) do
    @torbrowser = Dogtail::Application.new('Firefox')
    @torbrowser.child?(roleName: 'frame', recursive: false)
  end
end

Given /^the Tor Browser loads the (startup page|Tails roadmap)$/ do |page|
  case page
  when "startup page"
    title = 'Tails - News'
  when "Tails roadmap"
    title = 'Roadmap - Tails - RiseupLabs Code Repository'
  else
    raise "Unsupported page: #{page}"
  end
  step "\"#{title}\" has loaded in the Tor Browser"
end

When /^I request a new identity using Torbutton$/ do
  @screen.wait_and_click('TorButtonIcon.png', 30)
  @screen.wait_and_click('TorButtonNewIdentity.png', 30)
end

When /^I acknowledge Torbutton's New Identity confirmation prompt$/ do
  @screen.wait('GnomeQuestionDialogIcon.png', 30)
  step 'I type "y"'
end

Given /^I add a bookmark to eff.org in the Tor Browser$/ do
  url = "https://www.eff.org"
  step "I open the address \"#{url}\" in the Tor Browser"
  step 'the Tor Browser shows the "The proxy server is refusing connections" error'
  @screen.type("d", Sikuli::KeyModifier.CTRL)
  @screen.wait("TorBrowserBookmarkPrompt.png", 10)
  @screen.type(url + Sikuli::Key.ENTER)
end

Given /^the Tor Browser has a bookmark to eff.org$/ do
  @screen.type("b", Sikuli::KeyModifier.ALT)
  @screen.wait("TorBrowserEFFBookmark.png", 10)
end

Given /^all notifications have disappeared$/ do
  # These magic coordinates always locates GNOME's clock in the top
  # bar, which when clicked opens the calendar.
  x, y = 512, 10
  gnome_shell = Dogtail::Application.new('gnome-shell')
  retry_action(10, recovery_proc: Proc.new { @screen.type(Sikuli::Key.ESC) }) do
    @screen.click_point(x, y)
    unless gnome_shell.child?('No Notifications', roleName: 'label')
      @screen.click('GnomeCloseAllNotificationsButton.png')
    end
    gnome_shell.child?('No Notifications', roleName: 'label')
  end
  @screen.type(Sikuli::Key.ESC)
end

Then /^I (do not )?see "([^"]*)" after at most (\d+) seconds$/ do |negation, image, time|
  if negation
    @screen.waitVanish(image, time.to_i)
  else
    @screen.wait(image, time.to_i)
  end
end

Then /^all Internet traffic has only flowed through Tor$/ do
  allowed_hosts = allowed_hosts_under_tor_enforcement
  assert_all_connections(@sniffer.pcap_file) do |c|
    allowed_hosts.include?({ address: c.daddr, port: c.dport })
  end
end

Given /^I enter the sudo password in the pkexec prompt$/ do
  step "I enter the \"#{@sudo_password}\" password in the pkexec prompt"
end

def deal_with_polkit_prompt(password, opts = {})
  opts[:expect_success] ||= true
  image = 'PolicyKitAuthPrompt.png'
  @screen.wait(image, 60)
  @screen.type(password)
  @screen.type(Sikuli::Key.ENTER)
  if opts[:expect_success]
    @screen.waitVanish(image, 20)
  else
    @screen.wait('PolicyKitAuthFailure.png', 20)
  end
end

Given /^I enter the "([^"]*)" password in the pkexec prompt$/ do |password|
  deal_with_polkit_prompt(password)
end

Given /^process "([^"]+)" is (not )?running$/ do |process, not_running|
  if not_running
    assert(!$vm.has_process?(process), "Process '#{process}' is running")
  else
    assert($vm.has_process?(process), "Process '#{process}' is not running")
  end
end

Given /^process "([^"]+)" is running within (\d+) seconds$/ do |process, time|
  try_for(time.to_i, :msg => "Process '#{process}' is not running after " +
                             "waiting for #{time} seconds") do
    $vm.has_process?(process)
  end
end

Given /^process "([^"]+)" has stopped running after at most (\d+) seconds$/ do |process, time|
  try_for(time.to_i, :msg => "Process '#{process}' is still running after " +
                             "waiting for #{time} seconds") do
    not $vm.has_process?(process)
  end
end

Given /^I kill the process "([^"]+)"$/ do |process|
  $vm.execute("killall #{process}")
  try_for(10, :msg => "Process '#{process}' could not be killed") {
    !$vm.has_process?(process)
  }
end

Then /^Tails eventually (shuts down|restarts)$/ do |mode|
  try_for(3*60) do
    if mode == 'restarts'
      @screen.find('TailsGreeter.png')
      true
    else
      ! $vm.is_running?
    end
  end
end

Given /^I shutdown Tails and wait for the computer to power off$/ do
  $vm.spawn("poweroff")
  step 'Tails eventually shuts down'
end

When /^I request a shutdown using the emergency shutdown applet$/ do
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  # Sometimes the next button too fast, before the menu has settled
  # down to its final size and the icon we want to click is in its
  # final position. dogtail might allow us to fix that, but given how
  # rare this problem is, it's not worth the effort.
  step 'I wait 5 seconds'
  @screen.wait_and_click('TailsEmergencyShutdownHalt.png', 10)
end

When /^I warm reboot the computer$/ do
  $vm.spawn("reboot")
end

When /^I request a reboot using the emergency shutdown applet$/ do
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  # See comment on /^I request a shutdown using the emergency shutdown applet$/
  # that explains why we need to wait.
  step 'I wait 5 seconds'
  @screen.wait_and_click('TailsEmergencyShutdownReboot.png', 10)
end

Given /^the package "([^"]+)" is installed$/ do |package|
  assert($vm.execute("dpkg -s '#{package}' 2>/dev/null | grep -qs '^Status:.*installed$'").success?,
         "Package '#{package}' is not installed")
end

Given /^I add a ([a-z0-9.]+ |)wired DHCP NetworkManager connection called "([^"]+)"$/ do |version, con_name|
  if version and version == '2.x'
    con_content = <<EOF
[connection]
id=#{con_name}
uuid=b04afa94-c3a1-41bf-aa12-1a743d964162
interface-name=eth0
type=ethernet
EOF
    con_file = "/etc/NetworkManager/system-connections/#{con_name}"
    $vm.file_overwrite(con_file, con_content)
    $vm.execute_successfully("chmod 600 '#{con_file}'")
    $vm.execute_successfully("nmcli connection load '#{con_file}'")
  elsif version and version == '3.x'
    raise "Unsupported version '#{version}'"
  else
    $vm.execute_successfully(
      "nmcli connection add con-name #{con_name} " + \
      "type ethernet autoconnect yes ifname eth0"
    )
  end
  try_for(10) {
    nm_con_list = $vm.execute("nmcli --terse --fields NAME connection show").stdout
    nm_con_list.split("\n").include? "#{con_name}"
  }
end

Given /^I switch to the "([^"]+)" NetworkManager connection$/ do |con_name|
  $vm.execute("nmcli connection up id #{con_name}")
  try_for(60) do
    $vm.execute("nmcli --terse --fields NAME,STATE connection show").stdout.chomp.split("\n").include?("#{con_name}:activated")
  end
end

When /^I start and focus GNOME Terminal$/ do
  step 'I start "GNOME Terminal" via GNOME Activities Overview'
  @screen.wait('GnomeTerminalWindow.png', 40)
end

When /^I run "([^"]+)" in GNOME Terminal$/ do |command|
  if !$vm.has_process?("gnome-terminal-server")
    step "I start and focus GNOME Terminal"
  else
    @screen.wait_and_click('GnomeTerminalWindow.png', 20)
  end
  @screen.type(command + Sikuli::Key.ENTER)
end

When /^the file "([^"]+)" exists(?:| after at most (\d+) seconds)$/ do |file, timeout|
  timeout = 0 if timeout.nil?
  try_for(
    timeout.to_i,
    :msg => "The file #{file} does not exist after #{timeout} seconds"
  ) {
    $vm.file_exist?(file)
  }
end

When /^the file "([^"]+)" does not exist$/ do |file|
  assert(! ($vm.file_exist?(file)))
end

When /^the directory "([^"]+)" exists$/ do |directory|
  assert($vm.directory_exist?(directory))
end

When /^the directory "([^"]+)" does not exist$/ do |directory|
  assert(! ($vm.directory_exist?(directory)))
end

When /^I copy "([^"]+)" to "([^"]+)" as user "([^"]+)"$/ do |source, destination, user|
  c = $vm.execute("cp \"#{source}\" \"#{destination}\"", :user => LIVE_USER)
  assert(c.success?, "Failed to copy file:\n#{c.stdout}\n#{c.stderr}")
end

def is_persistent?(app)
  conf = get_persistence_presets(true)["#{app}"]
  c = $vm.execute("findmnt --noheadings --output SOURCE --target '#{conf}'")
  # This check assumes that we haven't enabled read-only persistence.
  c.success? and c.stdout.chomp != "aufs"
end

Then /^persistence for "([^"]+)" is (|not )enabled$/ do |app, enabled|
  case enabled
  when ''
    assert(is_persistent?(app), "Persistence should be enabled.")
  when 'not '
    assert(!is_persistent?(app), "Persistence should not be enabled.")
  end
end

Given /^I start "([^"]+)" via GNOME Activities Overview$/ do |app_name|
  # Search disambiguations: below we assume that there is only one
  # result, since multiple results introduces a race that leads to a
  # non-deterministic choice (at least under load). To make the life
  # easier for users of this step, let's collect workarounds here.
  case app_name
  when 'GNOME Terminal'
    # "GNOME Terminal" and "Terminal" shows both the (non-Root)
    # "Terminal" and "Root Terminal" search results, so let's use a
    # keyword only found in the former's .desktop file.
    app_name = 'commandline'
  end
  @screen.wait('GnomeApplicationsMenu.png', 10)
  $vm.execute_successfully('xdotool key Super', user: LIVE_USER)
  @screen.wait('GnomeActivitiesOverview.png', 10)
  @screen.type(app_name)
  @screen.type(Sikuli::Key.ENTER, Sikuli::KeyModifier.CTRL)
end

When /^I type "([^"]+)"$/ do |string|
  @screen.type(string)
end

When /^I press the "([^"]+)" key$/ do |key|
  begin
    @screen.type(eval("Sikuli::Key.#{key}"))
  rescue RuntimeError
    raise "unsupported key #{key}"
  end
end

Then /^the (amnesiac|persistent) Tor Browser directory (exists|does not exist)$/ do |persistent_or_not, mode|
  case persistent_or_not
  when "amnesiac"
    dir = "/home/#{LIVE_USER}/Tor Browser"
  when "persistent"
    dir = "/home/#{LIVE_USER}/Persistent/Tor Browser"
  end
  step "the directory \"#{dir}\" #{mode}"
end

Then /^there is a GNOME bookmark for the (amnesiac|persistent) Tor Browser directory$/ do |persistent_or_not|
  case persistent_or_not
  when "amnesiac"
    bookmark_image = 'TorBrowserAmnesicFilesBookmark.png'
  when "persistent"
    bookmark_image = 'TorBrowserPersistentFilesBookmark.png'
  end
  @screen.wait_and_click('GnomePlaces.png', 10)
  @screen.wait(bookmark_image, 40)
  @screen.type(Sikuli::Key.ESC)
end

Then /^there is no GNOME bookmark for the persistent Tor Browser directory$/ do
  try_for(65) do
    @screen.wait_and_click('GnomePlaces.png', 10)
    @screen.wait("GnomePlacesWithoutTorBrowserPersistent.png", 10)
    @screen.type(Sikuli::Key.ESC)
  end
end

def pulseaudio_sink_inputs
  pa_info = $vm.execute_successfully('pacmd info', :user => LIVE_USER).stdout
  sink_inputs_line = pa_info.match(/^\d+ sink input\(s\) available\.$/)[0]
  return sink_inputs_line.match(/^\d+/)[0].to_i
end

When /^(no|\d+) application(?:s?) (?:is|are) playing audio(?:| after (\d+) seconds)$/ do |nb, wait_time|
  nb = 0 if nb == "no"
  sleep wait_time.to_i if ! wait_time.nil?
  assert_equal(nb.to_i, pulseaudio_sink_inputs)
end

When /^I double-click on the (Tails documentation|Report an Error) launcher on the desktop$/ do |launcher|
  image = 'Desktop' + launcher.split.map { |s| s.capitalize } .join + '.png'
  # Sometimes the double-click is lost (#12131).
  retry_action(10) do
    @screen.wait_and_double_click(image, 10) if $vm.execute("pgrep --uid #{LIVE_USER} --full --full tails-documentation").failure?
  end
end

When /^I click the HTML5 play button$/ do
  @screen.wait_and_click("TorBrowserHtml5PlayButton.png", 30)
end

When /^I (can|cannot) save the current page as "([^"]+[.]html)" to the (.*) directory$/ do |should_work, output_file, output_dir|
  should_work = should_work == 'can' ? true : false
  @screen.type("s", Sikuli::KeyModifier.CTRL)
  @screen.wait("TorBrowserSaveDialog.png", 10)
  if output_dir == "persistent Tor Browser"
    output_dir = "/home/#{LIVE_USER}/Persistent/Tor Browser"
    @screen.wait_and_click("GtkTorBrowserPersistentBookmark.png", 10)
    @screen.wait("GtkTorBrowserPersistentBookmarkSelected.png", 10)
    # The output filename (without its extension) is already selected,
    # let's use the keyboard shortcut to focus its field
    @screen.type("n", Sikuli::KeyModifier.ALT)
    @screen.wait("TorBrowserSaveOutputFileSelected.png", 10)
  elsif output_dir == "default downloads"
    output_dir = "/home/#{LIVE_USER}/Tor Browser"
  else
    @screen.type(output_dir + '/')
  end
  # Only the part of the filename before the .html extension can be easily replaced
  # so we have to remove it before typing it into the arget filename entry widget.
  @screen.type(output_file.sub(/[.]html$/, ''))
  @screen.type(Sikuli::Key.ENTER)
  if should_work
    try_for(20, :msg => "The page was not saved to #{output_dir}/#{output_file}") {
      $vm.file_exist?("#{output_dir}/#{output_file}")
    }
  else
    @screen.wait("TorBrowserCannotSavePage.png", 10)
  end
end

When /^I can print the current page as "([^"]+[.]pdf)" to the (default downloads|persistent Tor Browser) directory$/ do |output_file, output_dir|
  if output_dir == "persistent Tor Browser"
    output_dir = "/home/#{LIVE_USER}/Persistent/Tor Browser"
  else
    output_dir = "/home/#{LIVE_USER}/Tor Browser"
  end
  @screen.type("p", Sikuli::KeyModifier.CTRL)
  print_dialog = @torbrowser.child('Print', roleName: 'dialog')
  print_dialog.child('Print to File', 'table cell').click
  entry = print_dialog.child(roleName: 'text')
  assert_equal('output.pdf', entry.text, "Failed to find the text entry")
  entry.text = output_dir + '/' + output_file
  print_dialog.button('Print').click
  try_for(30, :msg => "The page was not printed to #{output_dir}/#{output_file}") {
    $vm.file_exist?("#{output_dir}/#{output_file}")
  }
end

Given /^a web server is running on the LAN$/ do
  @web_server_ip_addr = $vmnet.bridge_ip_addr
  @web_server_port = 8000
  @web_server_url = "http://#{@web_server_ip_addr}:#{@web_server_port}"
  web_server_hello_msg = "Welcome to the LAN web server!"

  # I've tested ruby Thread:s, fork(), etc. but nothing works due to
  # various strange limitations in the ruby interpreter. For instance,
  # apparently concurrent IO has serious limits in the thread
  # scheduler (e.g. sikuli's wait() would block WEBrick from reading
  # from its socket), and fork():ing results in a lot of complex
  # cucumber stuff (like our hooks!) ending up in the child process,
  # breaking stuff in the parent process. After asking some supposed
  # ruby pros, I've settled on the following.
  code = <<-EOF
  require "webrick"
  STDOUT.reopen("/dev/null", "w")
  STDERR.reopen("/dev/null", "w")
  server = WEBrick::HTTPServer.new(:BindAddress => "#{@web_server_ip_addr}",
                                   :Port => #{@web_server_port},
                                   :DocumentRoot => "/dev/null")
  server.mount_proc("/") do |req, res|
    res.body = "#{web_server_hello_msg}"
  end
  server.start
EOF
  add_lan_host(@web_server_ip_addr, @web_server_port)
  proc = IO.popen(['ruby', '-e', code])
  try_for(10, :msg => "It seems the LAN web server failed to start") do
    Process.kill(0, proc.pid) == 1
  end

  add_after_scenario_hook { Process.kill("TERM", proc.pid) }

  # It seems necessary to actually check that the LAN server is
  # serving, possibly because it isn't doing so reliably when setting
  # up. If e.g. the Unsafe Browser (which *should* be able to access
  # the web server) tries to access it too early, Firefox seems to
  # take some random amount of time to retry fetching. Curl gives a
  # more consistent result, so let's rely on that instead. Note that
  # this forces us to capture traffic *after* this step in case
  # accessing this server matters, like when testing the Tor Browser..
  try_for(30, :msg => "Something is wrong with the LAN web server") do
    msg = $vm.execute_successfully("curl #{@web_server_url}",
                                   :user => LIVE_USER).stdout.chomp
    web_server_hello_msg == msg
  end
end

When /^I open a page on the LAN web server in the (.*)$/ do |browser|
  step "I open the address \"#{@web_server_url}\" in the #{browser}"
end

Given /^I wait (?:between (\d+) and )?(\d+) seconds$/ do |min, max|
  if min
    time = rand(max.to_i - min.to_i + 1) + min.to_i
  else
    time = max.to_i
  end
  puts "Slept for #{time} seconds"
  sleep(time)
end

Given /^I (?:re)?start monitoring the AppArmor log of "([^"]+)"$/ do |profile|
  # AppArmor log entries may be dropped if printk rate limiting is
  # enabled.
  $vm.execute_successfully('sysctl -w kernel.printk_ratelimit=0')
  # We will only care about entries for this profile from this time
  # and on.
  guest_time = $vm.execute_successfully(
    'date +"%Y-%m-%d %H:%M:%S"').stdout.chomp
  @apparmor_profile_monitoring_start ||= Hash.new
  @apparmor_profile_monitoring_start[profile] = guest_time
end

When /^AppArmor has (not )?denied "([^"]+)" from opening "([^"]+)"(?: after at most (\d+) seconds)?$/ do |anti_test, profile, file, time|
  assert(@apparmor_profile_monitoring_start &&
         @apparmor_profile_monitoring_start[profile],
         "It seems the profile '#{profile}' isn't being monitored by the " +
         "'I monitor the AppArmor log of ...' step")
  audit_line_regex = 'apparmor="DENIED" operation="open" profile="%s" name="%s"' % [profile, file]
  block = Proc.new do
    audit_log = $vm.execute(
      "journalctl --full --no-pager " +
      "--since='#{@apparmor_profile_monitoring_start[profile]}' " +
      "SYSLOG_IDENTIFIER=kernel | grep -w '#{audit_line_regex}'"
    ).stdout.chomp
    assert(audit_log.empty? == (anti_test ? true : false))
    true
  end
  begin
    if time
      try_for(time.to_i) { block.call }
    else
      block.call
    end
  rescue Timeout::Error, Test::Unit::AssertionFailedError => e
    raise e, "AppArmor has #{anti_test ? "" : "not "}denied the operation"
  end
end

Then /^I force Tor to use a new circuit$/ do
  force_new_tor_circuit
end

When /^I eject the boot medium$/ do
  dev = boot_device
  dev_type = device_info(dev)['ID_TYPE']
  case dev_type
  when 'cd'
    $vm.eject_cdrom
  when 'disk'
    boot_disk_name = $vm.disk_name(dev)
    $vm.unplug_drive(boot_disk_name)
  else
    raise "Unsupported medium type '#{dev_type}' for boot device '#{dev}'"
  end
end

Given /^Tails is fooled to think it is running version (.+)$/ do |version|
  $vm.execute_successfully(
    "sed -i " +
    "'s/^TAILS_VERSION_ID=.*$/TAILS_VERSION_ID=\"#{version}\"/' " +
    "/etc/os-release"
  )
end

Then /^Tails is running version (.+)$/ do |version|
  v1 = $vm.execute_successfully('tails-version').stdout.split.first
  assert_equal(version, v1, "The version doesn't match tails-version's output")
  v2 = $vm.file_content('/etc/os-release')
       .scan(/TAILS_VERSION_ID="(#{version})"/).flatten.first
  assert_equal(version, v2, "The version doesn't match /etc/os-release")
end

def share_host_files(files)
  files = [files] if files.class == String
  assert_equal(Array, files.class)
  disk_size = files.map { |f| File.new(f).size } .inject(0, :+)
  # Let's add some extra space for filesysten overhead etc.
  disk_size += [convert_to_bytes(1, 'MiB'), (disk_size * 0.10).ceil].max
  disk = random_alpha_string(10)
  step "I temporarily create an #{disk_size} bytes disk named \"#{disk}\""
  step "I create a gpt partition labeled \"#{disk}\" with an ext4 " +
       "filesystem on disk \"#{disk}\""
  $vm.storage.guestfs_disk_helper(disk) do |g, _|
    partition = g.list_partitions().first
    g.mount(partition, "/")
    files.each { |f| g.upload(f, "/" + File.basename(f)) }
  end
  step "I plug USB drive \"#{disk}\""
  mount_dir = $vm.execute_successfully('mktemp -d').stdout.chomp
  dev = $vm.disk_dev(disk)
  partition = dev + '1'
  $vm.execute_successfully("mount #{partition} #{mount_dir}")
  $vm.execute_successfully("chmod -R a+rX '#{mount_dir}'")
  return mount_dir
end

def mount_USB_drive(disk, fs_options = {})
  fs_options[:encrypted] ||= false
  @tmp_usb_drive_mount_dir = $vm.execute_successfully('mktemp -d').stdout.chomp
  dev = $vm.disk_dev(disk)
  partition = dev + '1'
  if fs_options[:encrypted]
    password = fs_options[:password]
    assert_not_nil(password)
    luks_mapping = "#{disk}_unlocked"
    $vm.execute_successfully(
      "echo #{password} | " +
      "cryptsetup luksOpen #{partition} #{luks_mapping}"
    )
    $vm.execute_successfully(
      "mount /dev/mapper/#{luks_mapping} #{@tmp_usb_drive_mount_dir}"
    )
  else
    $vm.execute_successfully("mount #{partition} #{@tmp_usb_drive_mount_dir}")
  end
  @tmp_filesystem_disk = disk
  @tmp_filesystem_options = fs_options
  @tmp_filesystem_partition = partition
  return @tmp_usb_drive_mount_dir
end

When(/^I plug and mount a (\d+) MiB USB drive with an? (.*)$/) do |size_MiB, fs|
  disk_size = convert_to_bytes(size_MiB.to_i, 'MiB')
  disk = random_alpha_string(10)
  step "I temporarily create an #{disk_size} bytes disk named \"#{disk}\""
  step "I create a gpt partition labeled \"#{disk}\" with " +
       "an #{fs} on disk \"#{disk}\""
  step "I plug USB drive \"#{disk}\""
  fs_options = {}
  fs_options[:filesystem] = /(.*) filesystem/.match(fs)[1]
  if /\bencrypted with password\b/.match(fs)
    fs_options[:encrypted] = true
    fs_options[:password] = /encrypted with password "([^"]+)"/.match(fs)[1]
  end
  mount_dir = mount_USB_drive(disk, fs_options)
  @tmp_filesystem_size_b = convert_to_bytes(
    avail_space_in_mountpoint_kB(mount_dir),
    'KB'
  )
end

When(/^I mount the USB drive again$/) do
  mount_USB_drive(@tmp_filesystem_disk, @tmp_filesystem_options)
end

When(/^I umount the USB drive$/) do
  $vm.execute_successfully("umount #{@tmp_usb_drive_mount_dir}")
  if @tmp_filesystem_options[:encrypted]
    $vm.execute_successfully("cryptsetup luksClose #{@tmp_filesystem_disk}_unlocked")
  end
end

When /^Tails system time is magically synchronized$/ do
  $vm.host_to_guest_time_sync
end

# Useful for debugging scenarios: e.g. inject this step in a scenario
# at some point when you want to investigate the state.
When /^I pause$/ do
  pause
end

# Useful for debugging Tails features: let's say you want to fix a bug
# exposed by $SCENARIO, and is working on a fix in $FILE locally. To
# immediately test your fix, simply inject this step into $SCENARIO,
# so that $FILE is put in place (obviously this depends on that no
# extra steps are needed to make $FILE's changes go "live").
When /^I upload "([^"]*)" to "([^"]*)"$/ do |source, destination|
  [source, destination].each { |s| s.sub!(/\/*$/, '') }
  Dir.glob(source).each do |path|
    if File.directory?(path)
      new_destination = "#{destination}/#{File.basename(path)}"
      $vm.execute_successfully("mkdir -p '#{new_destination}'")
      Dir.new(path).each do |child|
        next if child == '.' or child == '..'
        step "I upload \"#{path}/#{child}\" to \"#{new_destination}\""
      end
    else
      File.open(path) do |f|
        final_destination = destination
        if $vm.directory_exist?(final_destination)
          final_destination += "/#{File.basename(path)}"
        end
        $vm.file_overwrite(final_destination, f.read)
      end
    end
  end
end
