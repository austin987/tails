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
  #  @vm.execute("modprobe #{mod}")
  #end

  @vm.list_shares.each do |share|
    @vm.execute("mkdir -p #{share}")
    @vm.execute("mount -t 9p -o trans=virtio #{share} #{share}")
  end
end

def deactivate_filesystem_shares
  @vm.list_shares.each do |share|
    @vm.execute("umount #{share}")
  end

  # XXX-9p: See XXX-9p above
  #for mod in ["9p", "9pnet_virtio"] do
  #  @vm.execute("modprobe -r #{mod}")
  #end
end

def restore_background
  @vm.restore_snapshot($background_snapshot)
  @vm.wait_until_remote_shell_is_up
  post_vm_start_hook

  # XXX-9p: See XXX-9p above
  #activate_filesystem_shares

  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  if @vm.has_network?
    if @vm.execute("service tor status").success?
      @vm.execute("service tor stop")
      @vm.execute("rm -f /var/log/tor/log")
      @vm.execute("killall vidalia")
      @vm.host_to_guest_time_sync
      @vm.execute("service tor start")
      wait_until_tor_is_working
      @vm.spawn("/usr/local/sbin/restart-vidalia")
    end
  end
end

Given /^a computer$/ do
  @vm.destroy if @vm
  @vm = VM.new($vm_xml_path, $x_display)
end

Given /^the computer has (\d+) ([[:alpha:]]+) of RAM$/ do |size, unit|
  next if @skip_steps_while_restoring_background
  @vm.set_ram_size(size, unit)
end

Given /^the computer is set to boot from the Tails DVD$/ do
  next if @skip_steps_while_restoring_background
  @vm.set_cdrom_boot($tails_iso)
end

Given /^the computer is set to boot from (.+?) drive "(.+?)"$/ do |type, name|
  next if @skip_steps_while_restoring_background
  @vm.set_disk_boot(name, type.downcase)
end

Given /^I plug ([[:alpha:]]+) drive "([^"]+)"$/ do |bus, name|
  next if @skip_steps_while_restoring_background
  @vm.plug_drive(name, bus.downcase)
  if @vm.is_running?
    step "drive \"#{name}\" is detected by Tails"
  end
end

Then /^drive "([^"]+)" is detected by Tails$/ do |name|
  next if @skip_steps_while_restoring_background
  if @vm.is_running?
    try_for(10, :msg => "Drive '#{name}' is not detected by Tails") {
      @vm.disk_detected?(name)
    }
  else
    STDERR.puts "Cannot tell if drive '#{name}' is detected by Tails: " +
                "Tails is not running"
  end
end

Given /^the network is plugged$/ do
  next if @skip_steps_while_restoring_background
  @vm.plug_network
end

Given /^the network is unplugged$/ do
  next if @skip_steps_while_restoring_background
  @vm.unplug_network
end

Given /^I capture all network traffic$/ do
  # Note: We don't want skip this particular stpe if
  # @skip_steps_while_restoring_background is set since it starts
  # something external to the VM state.
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name)
  @sniffer.capture
end

Given /^I set Tails to boot with options "([^"]*)"$/ do |options|
  next if @skip_steps_while_restoring_background
  @boot_options = options
end

When /^I start the computer$/ do
  next if @skip_steps_while_restoring_background
  assert(!@vm.is_running?,
         "Trying to start a VM that is already running")
  @vm.start
  post_vm_start_hook
end

Given /^I start Tails from DVD(| with network unplugged) and I login$/ do |network_unplugged|
  # we don't @skip_steps_while_restoring_background as we're only running
  # other steps, that are taking care of it *if* they have to
  step "the computer is set to boot from the Tails DVD"
  if network_unplugged.empty?
    step "the network is plugged"
  else
    step "the network is unplugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
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

Given /^I start Tails from (.+?) drive "(.+?)"(| with network unplugged) and I login(| with(| read-only) persistence password "([^"]+)")$/ do |drive_type, drive_name, network_unplugged, persistence_on, persistence_ro, persistence_pwd|
  # we don't @skip_steps_while_restoring_background as we're only running
  # other steps, that are taking care of it *if* they have to
  step "the computer is set to boot from #{drive_type} drive \"#{drive_name}\""
  if network_unplugged.empty?
    step "the network is plugged"
  else
    step "the network is unplugged"
  end
  step "I start the computer"
  step "the computer boots Tails"
  if ! persistence_on.empty?
    assert(! persistence_pwd.empty?, "A password must be provided when enabling persistence")
    if persistence_ro.empty?
      step "I enable persistence with password \"#{persistence_pwd}\""
    else
      step "I enable read-only persistence with password \"#{persistence_pwd}\""
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

When /^I power off the computer$/ do
  next if @skip_steps_while_restoring_background
  assert(@vm.is_running?,
         "Trying to power off an already powered off VM")
  @vm.power_off
end

When /^I cold reboot the computer$/ do
  next if @skip_steps_while_restoring_background
  step "I power off the computer"
  step "I start the computer"
end

When /^I destroy the computer$/ do
  next if @skip_steps_while_restoring_background
  @vm.destroy
end

Given /^the computer (re)?boots Tails$/ do |reboot|
  next if @skip_steps_while_restoring_background

  case @os_loader
  when "UEFI"
    assert(!reboot, "Testing of reboot with UEFI enabled is not implemented")
    bootsplash = 'TailsBootSplashUEFI.png'
    bootsplash_tab_msg = 'TailsBootSplashTabMsgUEFI.png'
    boot_timeout = 30
  else
    if reboot
      bootsplash = 'TailsBootSplashPostReset.png'
      bootsplash_tab_msg = 'TailsBootSplashTabMsgPostReset.png'
      boot_timeout = 120
    else
      bootsplash = 'TailsBootSplash.png'
      bootsplash_tab_msg = 'TailsBootSplashTabMsg.png'
      boot_timeout = 30
    end
  end

  @screen.wait(bootsplash, boot_timeout)
  @screen.wait(bootsplash_tab_msg, 10)
  @screen.type(Sikuli::Key.TAB)
  @screen.waitVanish(bootsplash_tab_msg, 1)

  @screen.type(" autotest_never_use_this_option #{@boot_options}" +
               Sikuli::Key.ENTER)
  @screen.wait('TailsGreeter.png', 30*60)
  @vm.wait_until_remote_shell_is_up
  activate_filesystem_shares
end

Given /^I log in to a new session$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('TailsGreeterLoginButton.png', 10)
end

Given /^I enable more Tails Greeter options$/ do
  next if @skip_steps_while_restoring_background
  match = @screen.find('TailsGreeterMoreOptions.png')
  @screen.click(match.getCenter.offset(match.w/2, match.h*2))
  @screen.wait_and_click('TailsGreeterForward.png', 10)
  @screen.wait('TailsGreeterLoginButton.png', 20)
end

Given /^I set sudo password "([^"]*)"$/ do |password|
  @sudo_password = password
  next if @skip_steps_while_restoring_background
  @screen.wait("TailsGreeterAdminPassword.png", 20)
  @screen.type(@sudo_password)
  @screen.type(Sikuli::Key.TAB)
  @screen.type(@sudo_password)
end

Given /^Tails Greeter has dealt with the sudo password$/ do
  next if @skip_steps_while_restoring_background
  f1 = "/etc/sudoers.d/tails-greeter"
  f2 = "#{f1}-no-password-lecture"
  try_for(20) {
    @vm.execute("test -e '#{f1}' -o -e '#{f2}'").success?
  }
end

Given /^GNOME has started$/ do
  next if @skip_steps_while_restoring_background
  case @theme
  when "windows"
    desktop_started_picture = 'WindowsStartButton.png'
  else
    desktop_started_picture = 'GnomeApplicationsMenu.png'
  end
  @screen.wait(desktop_started_picture, 180)
end

Then /^Tails seems to have booted normally$/ do
  next if @skip_steps_while_restoring_background
  step "GNOME has started"
end

When /^I see the 'Tor is ready' notification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("GnomeTorIsReady.png", 300)
  @screen.waitVanish("GnomeTorIsReady.png", 15)
end

Given /^Tor is ready$/ do
  next if @skip_steps_while_restoring_background
  step "Tor has built a circuit"
  step "the time has synced"
end

Given /^Tor has built a circuit$/ do
  next if @skip_steps_while_restoring_background
  wait_until_tor_is_working
end

Given /^the time has synced$/ do
  next if @skip_steps_while_restoring_background
  ["/var/run/tordate/done", "/var/run/htpdate/success"].each do |file|
    try_for(300) { @vm.execute("test -e #{file}").success? }
  end
end

Given /^available upgrades have been checked$/ do
  next if @skip_steps_while_restoring_background
  try_for(300) {
    @vm.execute("test -e '/var/run/tails-upgrader/checked_upgrades'").success?
  }
end

Given /^the Tor Browser has started$/ do
  next if @skip_steps_while_restoring_background
  case @theme
  when "windows"
    tor_browser_picture = "WindowsTorBrowserWindow.png"
  else
    tor_browser_picture = "TorBrowserWindow.png"
  end

  @screen.wait(tor_browser_picture, 60)
end

Given /^the Tor Browser has started and loaded the startup page$/ do
  next if @skip_steps_while_restoring_background
  step "the Tor Browser has started"
  @screen.wait("TorBrowserStartupPage.png", 120)
end

Given /^the Tor Browser has started in offline mode$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("TorBrowserOffline.png", 60)
end

Given /^I add a bookmark to eff.org in the Tor Browser$/ do
  next if @skip_steps_while_restoring_background
  url = "https://www.eff.org"
  step "I open the address \"#{url}\" in the Tor Browser"
  @screen.wait("TorBrowserOffline.png", 5)
  @screen.type("d", Sikuli::KeyModifier.CTRL)
  @screen.wait("TorBrowserBookmarkPrompt.png", 10)
  @screen.type(url + Sikuli::Key.ENTER)
end

Given /^the Tor Browser has a bookmark to eff.org$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("b", Sikuli::KeyModifier.ALT)
  @screen.wait("TorBrowserEFFBookmark.png", 10)
end

Given /^all notifications have disappeared$/ do
  next if @skip_steps_while_restoring_background
  case @theme
  when "windows"
    notification_picture = "WindowsNotificationX.png"
  else
    notification_picture = "GnomeNotificationX.png"
  end
  @screen.waitVanish(notification_picture, 60)
end

Given /^I save the state so the background can be restored next scenario$/ do
  if @skip_steps_while_restoring_background
    assert(File.size?($background_snapshot),
           "We have been skipping steps but there is no snapshot to restore")
  else
    # To be sure we run the feature from scratch we remove any
    # leftover snapshot that wasn't removed.
    if File.exist?($background_snapshot)
      File.delete($background_snapshot)
    end
    # Workaround: when libvirt takes ownership of the snapshot it may
    # become unwritable for the user running this script so it cannot
    # be removed during clean up.
    FileUtils.touch($background_snapshot)
    FileUtils.chmod(0666, $background_snapshot)

    # Snapshots cannot be saved while filesystem shares are mounted
    # XXX-9p: See XXX-9p above.
    #deactivate_filesystem_shares

    @vm.save_snapshot($background_snapshot)
  end
  restore_background
  # Now we stop skipping steps from the snapshot restore.
  @skip_steps_while_restoring_background = false
end

Then /^I see "([^"]*)" after at most (\d+) seconds$/ do |image, time|
  next if @skip_steps_while_restoring_background
  @screen.wait(image, time.to_i)
end

Then /^all Internet traffic has only flowed through Tor$/ do
  next if @skip_steps_while_restoring_background
  leaks = FirewallLeakCheck.new(@sniffer.pcap_file, get_tor_relays)
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
    if !leaks.nonip_leaks.empty?
      puts "Some non-IP packets were sent\n"
    end
    save_pcap_file
    raise "There were network leaks!"
  end
end

Given /^I enter the sudo password in the gksu prompt$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('GksuAuthPrompt.png', 60)
  sleep 1 # wait for weird fade-in to unblock the "Ok" button
  @screen.type(@sudo_password)
  @screen.type(Sikuli::Key.ENTER)
  @screen.waitVanish('GksuAuthPrompt.png', 10)
end

Given /^I enter the sudo password in the pkexec prompt$/ do
  next if @skip_steps_while_restoring_background
  step "I enter the \"#{@sudo_password}\" password in the pkexec prompt"
end

def deal_with_polkit_prompt (image, password)
  @screen.wait(image, 60)
  sleep 1 # wait for weird fade-in to unblock the "Ok" button
  @screen.type(password)
  @screen.type(Sikuli::Key.ENTER)
  @screen.waitVanish(image, 10)
end

Given /^I enter the "([^"]*)" password in the pkexec prompt$/ do |password|
  next if @skip_steps_while_restoring_background
  deal_with_polkit_prompt('PolicyKitAuthPrompt.png', password)
end

Given /^process "([^"]+)" is running$/ do |process|
  next if @skip_steps_while_restoring_background
  assert(@vm.has_process?(process),
         "Process '#{process}' is not running")
end

Given /^process "([^"]+)" is running within (\d+) seconds$/ do |process, time|
  next if @skip_steps_while_restoring_background
  try_for(time.to_i, :msg => "Process '#{process}' is not running after " +
                             "waiting for #{time} seconds") do
    @vm.has_process?(process)
  end
end

Given /^process "([^"]+)" is not running$/ do |process|
  next if @skip_steps_while_restoring_background
  assert(!@vm.has_process?(process),
         "Process '#{process}' is running")
end

Given /^I kill the process "([^"]+)"$/ do |process|
  next if @skip_steps_while_restoring_background
  @vm.execute("killall #{process}")
  try_for(10, :msg => "Process '#{process}' could not be killed") {
    !@vm.has_process?(process)
  }
end

Then /^Tails eventually shuts down$/ do
  next if @skip_steps_while_restoring_background
  nr_gibs_of_ram = (detected_ram_in_MiB.to_f/(2**10)).ceil
  timeout = nr_gibs_of_ram*5*60
  try_for(timeout, :msg => "VM is still running after #{timeout} seconds") do
    ! @vm.is_running?
  end
end

Then /^Tails eventually restarts$/ do
  next if @skip_steps_while_restoring_background
  nr_gibs_of_ram = (detected_ram_in_MiB.to_f/(2**10)).ceil
  @screen.wait('TailsBootSplashPostReset.png', nr_gibs_of_ram*5*60)
end

Given /^I shutdown Tails and wait for the computer to power off$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute("poweroff")
  step 'Tails eventually shuts down'
end

When /^I request a shutdown using the emergency shutdown applet$/ do
  next if @skip_steps_while_restoring_background
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownHalt.png', 10)
end

When /^I warm reboot the computer$/ do
  next if @skip_steps_while_restoring_background
  @vm.execute("reboot")
end

When /^I request a reboot using the emergency shutdown applet$/ do
  next if @skip_steps_while_restoring_background
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownButton.png', 10)
  @screen.hide_cursor
  @screen.wait_and_click('TailsEmergencyShutdownReboot.png', 10)
end

Given /^package "([^"]+)" is installed$/ do |package|
  next if @skip_steps_while_restoring_background
  assert(@vm.execute("dpkg -s '#{package}' 2>/dev/null | grep -qs '^Status:.*installed$'").success?,
         "Package '#{package}' is not installed")
end

When /^I start the Tor Browser$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "TorBrowser" via the GNOME "Internet" applications menu'
end

When /^I start the Tor Browser in offline mode$/ do
  next if @skip_steps_while_restoring_background
  step "I start the Tor Browser"
  case @theme
  when "windows"
    @screen.wait_and_click("WindowsTorBrowserOfflinePrompt.png", 10)
    @screen.click("WindowsTorBrowserOfflinePromptStart.png")
  else
    @screen.wait_and_click("TorBrowserOfflinePrompt.png", 10)
    @screen.click("TorBrowserOfflinePromptStart.png")
  end
end

def xul_application_info(application)
  binary = @vm.execute_successfully(
                '. /usr/local/lib/tails-shell-library/tor-browser.sh; ' +
                'echo ${TBB_INSTALL}/firefox'
                                    ).stdout.chomp
  case application
  when "Tor Browser"
    user = $live_user
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.tor-browser/profile\.default"
    chroot = ""
    new_tab_button_image = "TorBrowserNewTabButton.png"
    address_bar_image = "TorBrowserAddressBar.png"
  when "Unsafe Browser"
    user = "clearnet"
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.unsafe-browser/profile\.default"
    chroot = "/var/lib/unsafe-browser/chroot"
    new_tab_button_image = "UnsafeBrowserNewTabButton.png"
    address_bar_image = "UnsafeBrowserAddressBar.png"
  when "I2P Browser"
    user = "i2pbrowser"
    cmd_regex = "#{binary} .* -profile /home/#{user}/\.i2p-browser/profile\.default"
    chroot = "/var/lib/i2p-browser/chroot"
    new_tab_button_image = nil
    address_bar_image = nil
  when "Tor Launcher"
    user = "tor-launcher"
    cmd_regex = "#{binary} -app /home/#{user}/\.tor-launcher/tor-launcher-standalone/application\.ini"
    chroot = ""
    new_tab_button_image = nil
    address_bar_image = nil
  else
    raise "Invalid browser or XUL application: #{application}"
  end
  return {
    :user => user,
    :cmd_regex => cmd_regex,
    :chroot => chroot,
    :new_tab_button_image => new_tab_button_image,
    :address_bar_image => address_bar_image,
  }
end

When /^I open a new tab in the (.*)$/ do |browser|
  next if @skip_steps_while_restoring_background
  info = xul_application_info(browser)
  @screen.click(info[:new_tab_button_image])
  @screen.wait(info[:address_bar_image], 10)
end

When /^I open the address "([^"]*)" in the (.*)$/ do |address, browser|
  next if @skip_steps_while_restoring_background
  step "I open a new tab in the #{browser}"
  info = xul_application_info(browser)
  @screen.click(info[:address_bar_image])
  sleep 0.5
  @screen.type(address + Sikuli::Key.ENTER)
end

Then /^the (.*) has no plugins installed$/ do |browser|
  next if @skip_steps_while_restoring_background
  step "I open the address \"about:plugins\" in the #{browser}"
  step "I see \"TorBrowserNoPlugins.png\" after at most 30 seconds"
end

def xul_app_shared_lib_check(pid, chroot)
  expected_absent_tbb_libs = ['libnssdbm3.so']
  absent_tbb_libs = []
  unwanted_native_libs = []
  tbb_libs = @vm.execute_successfully(
                 ". /usr/local/lib/tails-shell-library/tor-browser.sh; " +
                 "ls -1 #{chroot}${TBB_INSTALL}/*.so"
                                      ).stdout.split
  firefox_pmap_info = @vm.execute("pmap #{pid}").stdout
  for lib in tbb_libs do
    lib_name = File.basename lib
    if not /\W#{lib}$/.match firefox_pmap_info
      absent_tbb_libs << lib_name
    end
    native_libs = @vm.execute_successfully(
                       "find /usr/lib /lib -name \"#{lib_name}\""
                                           ).stdout.split
    for native_lib in native_libs do
      if /\W#{native_lib}$"/.match firefox_pmap_info
        unwanted_native_libs << lib_name
      end
    end
  end
  absent_tbb_libs -= expected_absent_tbb_libs
  assert(absent_tbb_libs.empty? && unwanted_native_libs.empty?,
         "The loaded shared libraries for the firefox process are not the " +
         "way we expect them.\n" +
         "Expected TBB libs that are absent: #{absent_tbb_libs}\n" +
         "Native libs that we don't want: #{unwanted_native_libs}")
end

Then /^the (.*) uses all expected TBB shared libraries$/ do |application|
  next if @skip_steps_while_restoring_background
  info = xul_application_info(application)
  pid = @vm.execute_successfully("pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'").stdout.chomp
  assert(/\A\d+\z/.match(pid), "It seems like #{application} is not running")
  xul_app_shared_lib_check(pid, info[:chroot])
end

Then /^the (.*) chroot is torn down$/ do |browser|
  next if @skip_steps_while_restoring_background
  info = xul_application_info(browser)
  try_for(30, :msg => "The #{browser} chroot '#{info[:chroot]}' was " \
                      "not removed") do
    !@vm.execute("test -d '#{info[:chroot]}'").success?
  end
end

Then /^the (.*) runs as the expected user$/ do |browser|
  next if @skip_steps_while_restoring_background
  info = xul_application_info(browser)
  assert_vmcommand_success(@vm.execute(
    "pgrep --full --exact '#{info[:cmd_regex]}'"),
    "The #{browser} is not running")
  assert_vmcommand_success(@vm.execute(
    "pgrep --uid #{info[:user]} --full --exact '#{info[:cmd_regex]}'"),
    "The #{browser} is not running as the #{info[:user]} user")
end

Given /^I add a wired DHCP NetworkManager connection called "([^"]+)"$/ do |con_name|
  next if @skip_steps_while_restoring_background
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
    @vm.execute("echo '#{line}' >> /tmp/NM.#{con_name}")
  end
  @vm.execute("install -m 0600 '/tmp/NM.#{con_name}' '/etc/NetworkManager/system-connections/#{con_name}'")
  try_for(10) {
    nm_con_list = @vm.execute("nmcli --terse --fields NAME con list").stdout
    nm_con_list.split("\n").include? "#{con_name}"
  }
end

Given /^I switch to the "([^"]+)" NetworkManager connection$/ do |con_name|
  next if @skip_steps_while_restoring_background
  @vm.execute("nmcli con up id #{con_name}")
  try_for(60) {
    @vm.execute("nmcli --terse --fields NAME,STATE con status").stdout.chomp == "#{con_name}:activated"
  }
end

When /^I start and focus GNOME Terminal$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "Terminal" via the GNOME "Accessories" applications menu'
  @screen.wait_and_click('GnomeTerminalWindow.png', 20)
end

When /^I run "([^"]+)" in GNOME Terminal$/ do |command|
  next if @skip_steps_while_restoring_background
  step "I start and focus GNOME Terminal"
  @screen.type(command + Sikuli::Key.ENTER)
end

When /^the file "([^"]+)" exists$/ do |file|
  next if @skip_steps_while_restoring_background
  assert(@vm.file_exist?(file))
end

When /^I copy "([^"]+)" to "([^"]+)" as user "([^"]+)"$/ do |source, destination, user|
  next if @skip_steps_while_restoring_background
  c = @vm.execute("cp \"#{source}\" \"#{destination}\"", $live_user)
  assert(c.success?, "Failed to copy file:\n#{c.stdout}\n#{c.stderr}")
end

Given /^the USB drive "([^"]+)" contains Tails with persistence configured and password "([^"]+)"$/ do |drive, password|
    step "a computer"
    step "I start Tails from DVD with network unplugged and I login"
    step "I create a new 4 GiB USB drive named \"#{drive}\""
    step "I plug USB drive \"#{drive}\""
    step "I \"Clone & Install\" Tails to USB drive \"#{drive}\""
    step "there is no persistence partition on USB drive \"#{drive}\""
    step "I shutdown Tails and wait for the computer to power off"
    step "a computer"
    step "I start Tails from USB drive \"#{drive}\" with network unplugged and I login"
    step "I create a persistent partition with password \"#{password}\""
    step "a Tails persistence partition with password \"#{password}\" exists on USB drive \"#{drive}\""
    step "I shutdown Tails and wait for the computer to power off"
end

Given /^I start "([^"]+)" via the GNOME "([^"]+)" applications menu$/ do |app, submenu|
  next if @skip_steps_while_restoring_background
  case @theme
  when "windows"
    prefix = 'Windows'
  else
    prefix = 'Gnome'
  end
  @screen.wait_and_click(prefix + "ApplicationsMenu.png", 10)
  @screen.wait_and_hover(prefix + "Applications" + submenu + ".png", 40)
  @screen.wait_and_click(prefix + "Applications" + app + ".png", 40)
end

Given /^I start "([^"]+)" via the GNOME "([^"]+)"\/"([^"]+)" applications menu$/ do |app, submenu, subsubmenu|
  next if @skip_steps_while_restoring_background
  case @theme
  when "windows"
    prefix = 'Windows'
  else
    prefix = 'Gnome'
  end
  @screen.wait_and_click(prefix + "ApplicationsMenu.png", 10)
  @screen.wait_and_hover(prefix + "Applications" + submenu + ".png", 20)
  @screen.wait_and_hover(prefix + "Applications" + subsubmenu + ".png", 20)
  @screen.wait_and_click(prefix + "Applications" + app + ".png", 20)
end

When /^I type "([^"]+)"$/ do |string|
  next if @skip_steps_while_restoring_background
  @screen.type(string)
end

When /^I press the "([^"]+)" key$/ do |key|
  next if @skip_steps_while_restoring_background
  case key
  when "ENTER"
    @screen.type(Sikuli::Key.ENTER)
  else
      raise "unsupported key #{key}"
  end
end
