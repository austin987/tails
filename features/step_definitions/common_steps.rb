require 'fileutils'

def post_vm_start_hook
  # Sometimes the first click is lost (presumably it's used to give
  # focus to virt-viewer or similar) so we do that now rather than
  # having an important click lost. The point we click should be
  # somewhere where no clickable elements generally reside.
  @screen.click_point(@screen.w, @screen.h/2)
end

def activate_filesystem_shares
  # XXX-9p: First of all, filesystem shares cannot be mounted while we
  # do a snapshot save+restore, so unmounting+remounting them seems
  # like a good idea. However, the 9p modules get into a broken state
  # during the save+restore, so we also would like to unload+reload
  # them, but loading of 9pnet_virtio fails after a restore with
  # "probe of virtio2 failed with error -2" (in dmesg) which makes the
  # shares unavailable. Hence we leave this code commented for now.
  #for mod in ["9pnet_virtio", "9p"] do
  #  $vm.execute("modprobe #{mod}")
  #end

  $vm.list_shares.each do |share|
    $vm.execute("mkdir -p #{share}")
    $vm.execute("mount -t 9p -o trans=virtio #{share} #{share}")
  end
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

def deactivate_filesystem_shares
  $vm.list_shares.each do |share|
    $vm.execute("umount #{share}")
  end

  # XXX-9p: See XXX-9p above
  #for mod in ["9p", "9pnet_virtio"] do
  #  $vm.execute("modprobe -r #{mod}")
  #end
end

# This helper requires that the notification image is the one shown in
# the notification applet's list, not the notification pop-up.
def robust_notification_wait(notification_image, time_to_wait)
  error_msg = "Didn't not manage to open the notification applet"
  wait_start = Time.now
  try_for(time_to_wait, :delay => 0, :msg => error_msg) do
    @screen.hide_cursor
    @screen.click("GnomeNotificationApplet.png")
    @screen.wait("GnomeNotificationAppletOpened.png", 10)
  end

  error_msg = "Didn't not see notification '#{notification_image}'"
  time_to_wait -= (Time.now - wait_start).ceil
  try_for(time_to_wait, :delay => 0, :msg => error_msg) do
    found = false
    entries = @screen.findAll("GnomeNotificationEntry.png")
    while(entries.hasNext) do
      entry = entries.next
      @screen.hide_cursor
      @screen.click(entry)
      close_entry = @screen.wait("GnomeNotificationEntryClose.png", 10)
      if @screen.exists(notification_image)
        found = true
        @screen.click(close_entry)
        break
      else
        @screen.click(entry)
      end
    end
    found
  end

  # Close the notification applet
  @screen.type(Sikuli::Key.ESC)
end

def post_snapshot_restore_hook
  $vm.wait_until_remote_shell_is_up
  post_vm_start_hook

  # XXX-9p: See XXX-9p above
  #activate_filesystem_shares

  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  if $vm.has_network?
    if $vm.execute("systemctl --quiet is-active tor@default.service").success?
      $vm.execute("systemctl stop tor@default.service")
      $vm.execute("rm -f /var/log/tor/log")
      $vm.execute("systemctl --no-block restart tails-tor-has-bootstrapped.target")
      $vm.host_to_guest_time_sync
      $vm.spawn("restart-tor")
      wait_until_tor_is_working
      if $vm.file_content('/proc/cmdline').include?(' i2p')
        $vm.execute_successfully('/usr/local/sbin/tails-i2p stop')
        # we "killall tails-i2p" to prevent multiple
        # copies of the script from running
        $vm.execute_successfully('killall tails-i2p')
        $vm.spawn('/usr/local/sbin/tails-i2p start')
      end
    end
  else
    $vm.host_to_guest_time_sync
  end
end

Given /^a computer$/ do
  $vm.destroy_and_undefine if $vm
  $vm = VM.new($virt, VM_XML_PATH, $vmnet, $vmstorage, DISPLAY)
end

Given /^the computer has (\d+) ([[:alpha:]]+) of RAM$/ do |size, unit|
  $vm.set_ram_size(size, unit)
end

Given /^the computer is set to boot from the Tails DVD$/ do
  $vm.set_cdrom_boot(TAILS_ISO)
end

Given /^the computer is set to boot from (.+?) drive "(.+?)"$/ do |type, name|
  $vm.set_disk_boot(name, type.downcase)
end

Given /^I (temporarily )?create a (\d+) ([[:alpha:]]+) disk named "([^"]+)"$/ do |temporary, size, unit, name|
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
  if network_unplugged.nil?
    step "the network is plugged"
  else
    step "the network is unplugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
  if do_login
    step "I log in to a new session"
    step "Tails seems to have booted normally"
    if network_unplugged.nil?
      step "Tor is ready"
      step "all notifications have disappeared"
      step "available upgrades have been checked"
    else
      step "all notifications have disappeared"
    end
  end
end

Given /^I start Tails from (.+?) drive "(.+?)"(| with network unplugged)( and I login(| with(| read-only) persistence enabled))?$/ do |drive_type, drive_name, network_unplugged, do_login, persistence_on, persistence_ro|
  step "the computer is set to boot from #{drive_type} drive \"#{drive_name}\""
  if network_unplugged.empty?
    step "the network is plugged"
  else
    step "the network is unplugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
  if do_login
    if ! persistence_on.empty?
      if persistence_ro.empty?
        step "I enable persistence"
      else
        step "I enable read-only persistence"
      end
    end
    step "I log in to a new session"
    step "Tails seems to have booted normally"
    if network_unplugged.empty?
      step "Tor is ready"
      step "all notifications have disappeared"
      step "available upgrades have been checked"
    else
      step "all notifications have disappeared"
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

def bootsplash
  case @os_loader
  when "UEFI"
    'TailsBootSplashUEFI.png'
  else
    'TailsBootSplash.png'
  end
end

def bootsplash_tab_msg
  case @os_loader
  when "UEFI"
    'TailsBootSplashTabMsgUEFI.png'
  else
    'TailsBootSplashTabMsg.png'
  end
end

Given /^the computer (re)?boots Tails$/ do |reboot|

  boot_timeout = 30
  # We need some extra time for memory wiping if rebooting
  boot_timeout += 90 if reboot

  @screen.wait(bootsplash, boot_timeout)
  @screen.wait(bootsplash_tab_msg, 10)
  @screen.type(Sikuli::Key.TAB)
  @screen.waitVanish(bootsplash_tab_msg, 1)

  @screen.type(" autotest_never_use_this_option blacklist=psmouse #{@boot_options}" +
               Sikuli::Key.ENTER)
  @screen.wait('TailsGreeter.png', 30*60)
  $vm.wait_until_remote_shell_is_up
  activate_filesystem_shares
  step 'I configure Tails to use a simulated Tor network'
end

Given /^I log in to a new session(?: in )?(|German)$/ do |lang|
  case lang
  when 'German'
    @language = "German"
    @screen.wait_and_click('TailsGreeterLanguage.png', 10)
    @screen.wait_and_click("TailsGreeterLanguage#{@language}.png", 10)
    @screen.wait_and_click("TailsGreeterLoginButton#{@language}.png", 10)
  when ''
    @screen.wait_and_click('TailsGreeterLoginButton.png', 10)
  else
    raise "Unsupported language: #{lang}"
  end
  step 'Tails Greeter has dealt with the sudo password'
  step 'the Tails desktop is ready'
end

Given /^I enable more Tails Greeter options$/ do
  match = @screen.find('TailsGreeterMoreOptions.png')
  @screen.click(match.getCenter.offset(match.w/2, match.h*2))
  @screen.wait_and_click('TailsGreeterForward.png', 10)
  @screen.wait('TailsGreeterLoginButton.png', 20)
end

Given /^I enable the specific Tor configuration option$/ do
  @screen.click('TailsGreeterTorConf.png')
end

Given /^I set an administration password$/ do
  @screen.wait("TailsGreeterAdminPassword.png", 20)
  @screen.type(@sudo_password)
  @screen.type(Sikuli::Key.TAB)
  @screen.type(@sudo_password)
end

Given /^Tails Greeter has dealt with the sudo password$/ do
  f1 = "/etc/sudoers.d/tails-greeter"
  f2 = "#{f1}-no-password-lecture"
  try_for(20) {
    $vm.execute("test -e '#{f1}' -o -e '#{f2}'").success?
  }
end

def florence_keyboard_is_visible
  $vm.execute(
    "xdotool search --all --onlyvisible --maxdepth 1 --classname 'Florence'",
    :user => LIVE_USER,
  ).success?
end

Given /^the Tails desktop is ready$/ do
  desktop_started_picture = "GnomeApplicationsMenu#{@language}.png"
  # We wait for the Florence icon to be displayed to ensure reliable systray icon clicking.
  @screen.wait("GnomeSystrayFlorence.png", 180)
  @screen.wait(desktop_started_picture, 180)
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
  # Sometimes the Florence window is not hidden on startup (#11398).
  # Whenever that's the case, hide it ourselves and verify that it vanishes.
  # I could not find that window using Accerciser, so I'm not using dogtail;
  # and it doesn't feel worth it to add an image and use Sikuli, since we can
  # instead do this programmatically with xdotool.
  if florence_keyboard_is_visible
    @screen.click("GnomeSystrayFlorence.png")
    try_for(2) { ! florence_keyboard_is_visible }
  end
end

Then /^Tails seems to have booted normally$/ do
  step "the Tails desktop is ready"
end

When /^I see the 'Tor is ready' notification$/ do
  robust_notification_wait('TorIsReadyNotification.png', 300)
end

Given /^Tor is ready$/ do
  step "Tor has built a circuit"
  step "the time has synced"
  if $vm.execute('systemctl is-system-running').failure?
    units_status = $vm.execute('systemctl').stdout
    raise "At least one system service failed to start:\n#{units_status}"
  end
end

Given /^Tor has built a circuit$/ do
  wait_until_tor_is_working
end

Given /^the time has synced$/ do
  ["/var/run/tordate/done", "/var/run/htpdate/success"].each do |file|
    try_for(300) { $vm.execute("test -e #{file}").success? }
  end
end

Given /^available upgrades have been checked$/ do
  try_for(300) {
    $vm.execute("test -e '/var/run/tails-upgrader/checked_upgrades'").success?
  }
end

Given /^the Tor Browser has started$/ do
  tor_browser_picture = "TorBrowserWindow.png"
  @screen.wait(tor_browser_picture, 60)
end

Given /^the Tor Browser (?:has started and )?load(?:ed|s) the (startup page|Tails roadmap)$/ do |page|
  case page
  when "startup page"
    picture = "TorBrowserStartupPage.png"
  when "Tails roadmap"
    picture = "TorBrowserTailsRoadmap.png"
  else
    raise "Unsupported page: #{page}"
  end
  step "the Tor Browser has started"
  @screen.wait(picture, 120)
end

Given /^the Tor Browser has started in offline mode$/ do
  @screen.wait("TorBrowserOffline.png", 60)
end

Given /^I add a bookmark to eff.org in the Tor Browser$/ do
  url = "https://www.eff.org"
  step "I open the address \"#{url}\" in the Tor Browser"
  @screen.wait("TorBrowserOffline.png", 5)
  @screen.type("d", Sikuli::KeyModifier.CTRL)
  @screen.wait("TorBrowserBookmarkPrompt.png", 10)
  @screen.type(url + Sikuli::Key.ENTER)
end

Given /^the Tor Browser has a bookmark to eff.org$/ do
  @screen.type("b", Sikuli::KeyModifier.ALT)
  @screen.wait("TorBrowserEFFBookmark.png", 10)
end

Given /^all notifications have disappeared$/ do
  next if not(@screen.exists("GnomeNotificationApplet.png"))
  @screen.click("GnomeNotificationApplet.png")
  @screen.wait("GnomeNotificationAppletOpened.png", 10)
  begin
    entries = @screen.findAll("GnomeNotificationEntry.png")
    while(entries.hasNext) do
      entry = entries.next
      @screen.hide_cursor
      @screen.click(entry)
      @screen.wait_and_click("GnomeNotificationEntryClose.png", 10)
    end
  rescue FindFailed
    # No notifications, so we're good to go.
  end
  @screen.hide_cursor
  # Click anywhere to close the notification applet
  @screen.click("GnomeApplicationsMenu.png")
  @screen.hide_cursor
end

Then /^I (do not )?see "([^"]*)" after at most (\d+) seconds$/ do |negation, image, time|
  begin
    @screen.wait(image, time.to_i)
    raise "found '#{image}' while expecting not to" if negation
  rescue FindFailed => e
    raise e if not(negation)
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

def deal_with_polkit_prompt (image, password)
  @screen.wait(image, 60)
  @screen.type(password)
  @screen.type(Sikuli::Key.ENTER)
  @screen.waitVanish(image, 10)
end

Given /^I enter the "([^"]*)" password in the pkexec prompt$/ do |password|
  deal_with_polkit_prompt('PolicyKitAuthPrompt.png', password)
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

Then /^Tails eventually shuts down$/ do
  nr_gibs_of_ram = convert_from_bytes($vm.get_ram_size_in_bytes, 'GiB').ceil
  timeout = nr_gibs_of_ram*5*60
  try_for(timeout, :msg => "VM is still running after #{timeout} seconds") do
    ! $vm.is_running?
  end
end

Then /^Tails eventually restarts$/ do
  nr_gibs_of_ram = convert_from_bytes($vm.get_ram_size_in_bytes, 'GiB').ceil
  @screen.wait('TailsBootSplash.png', nr_gibs_of_ram*5*60)
end

Given /^I shutdown Tails and wait for the computer to power off$/ do
  $vm.spawn("poweroff")
  step 'Tails eventually shuts down'
end

When /^I request a shutdown using the emergency shutdown applet$/ do
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  @screen.wait_and_click('TailsEmergencyShutdownHalt.png', 10)
end

When /^I warm reboot the computer$/ do
  $vm.spawn("reboot")
end

When /^I request a reboot using the emergency shutdown applet$/ do
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  @screen.wait_and_click('TailsEmergencyShutdownReboot.png', 10)
end

Given /^package "([^"]+)" is installed$/ do |package|
  assert($vm.execute("dpkg -s '#{package}' 2>/dev/null | grep -qs '^Status:.*installed$'").success?,
         "Package '#{package}' is not installed")
end

When /^I start the Tor Browser$/ do
  step 'I start "Tor Browser" via the GNOME "Internet" applications menu'
end

When /^I request a new identity using Torbutton$/ do
  @screen.wait_and_click('TorButtonIcon.png', 30)
  @screen.wait_and_click('TorButtonNewIdentity.png', 30)
end

When /^I acknowledge Torbutton's New Identity confirmation prompt$/ do
  @screen.wait('GnomeQuestionDialogIcon.png', 30)
  step 'I type "y"'
end

When /^I start the Tor Browser in offline mode$/ do
  step "I start the Tor Browser"
  @screen.wait_and_click("TorBrowserOfflinePrompt.png", 10)
  @screen.click("TorBrowserOfflinePromptStart.png")
end

Given /^I add a wired DHCP NetworkManager connection called "([^"]+)"$/ do |con_name|
  con_content = <<EOF
[802-3-ethernet]
duplex=full

[connection]
id=#{con_name}
uuid=bbc60668-1be0-11e4-a9c6-2f1ce0e75bf1
type=802-3-ethernet
timestamp=1395406011

[ipv6]
method=auto

[ipv4]
method=auto
EOF
  con_content.split("\n").each do |line|
    $vm.execute("echo '#{line}' >> /tmp/NM.#{con_name}")
  end
  con_file = "/etc/NetworkManager/system-connections/#{con_name}"
  $vm.execute("install -m 0600 '/tmp/NM.#{con_name}' '#{con_file}'")
  $vm.execute_successfully("nmcli connection load '#{con_file}'")
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
  step 'I start "Terminal" via the GNOME "Utilities" applications menu'
  @screen.wait('GnomeTerminalWindow.png', 20)
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

Given /^I start "([^"]+)" via the GNOME "([^"]+)" applications menu$/ do |app_name, submenu|
  app = Dogtail::Application.new('gnome-shell')
  for element in ['Applications', submenu, app_name] do
    app.child(element, roleName: 'label').click
  end
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

When /^I double-click on the "Tails documentation" link on the Desktop$/ do
  @screen.wait_and_double_click("DesktopTailsDocumentationIcon.png", 10)
end

When /^I click the blocked video icon$/ do
  @screen.wait_and_click("TorBrowserBlockedVideo.png", 30)
end

When /^I accept to temporarily allow playing this video$/ do
  @screen.wait_and_click("TorBrowserOkButton.png", 10)
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
    try_for(10, :msg => "The page was not saved to #{output_dir}/#{output_file}") {
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
  @screen.wait("TorBrowserPrintDialog.png", 20)
  @screen.wait_and_click("BrowserPrintToFile.png", 10)
  @screen.wait_and_double_click("TorBrowserPrintOutputFile.png", 10)
  @screen.hide_cursor
  @screen.wait("TorBrowserPrintOutputFileSelected.png", 10)
  # Only the file's basename is selected by double-clicking,
  # so we type only the desired file's basename to replace it
  @screen.type(output_dir + '/' + output_file.sub(/[.]pdf$/, '') + Sikuli::Key.ENTER)
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
    $vm.remove_cdrom
  when 'disk'
    boot_disk_name = $vm.disk_name(dev)
    $vm.unplug_drive(boot_disk_name)
  else
    raise "Unsupported medium type '#{dev_type}' for boot device '#{dev}'"
  end
end
