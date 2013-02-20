require 'fileutils'

def post_vm_start_hook
  # Sometimes the first click is lost (presumably it's used to give
  # focus to virt-viewer or similar) so we do that now rather than
  # having an important click lost. The point we click should be
  # somewhere where no clickable elements generally reside.
  @screen.click(@screen.width, @screen.height/2)
end

def restore_background
#  @vm.restore_snapshot(@background_snapshot)
#  wait_until_remote_shell_is_up
  # FIXME: Uncomment above and remove workaround below once the
  # remote shell reliably runs all the time.
  # Start of workaround:
  @vm.restore_snapshot(@background_snapshot)
  while true
    begin
      wait_until_remote_shell_is_up(3, 1)
    rescue
      STDERR.puts "*********************************************"
      STDERR.puts "Restored Tails but no remote shell. Retrying."
      STDERR.puts "*********************************************"
      @vm.restore_snapshot(@background_snapshot)
    else
      break
    end
  end
  # End of workaround.
  post_vm_start_hook
  # The guest's Tor's circuits' states are likely to get out of sync
  # with the other relays, so we ensure that we have fresh circuits.
  # Time jumps and incorrect clocks also confuses Tor in many ways.
  if guest_has_network?
    if @vm.execute("service tor status").success?
      @vm.execute("service tor stop")
      @vm.execute("killall vidalia")
      @vm.host_to_guest_time_sync
      @vm.execute("service tor start")
      wait_until_tor_is_working
    end
  end
end

Given /^I restore the background snapshot if it exists$/ do
  if File.exists?(@background_snapshot)
    restore_background
    # From now on all steps will be skipped (and pass) until we reach
    # the step which saved the snapshot.
    @skip_steps_while_restoring_background = true
  end
end

Given /^a freshly started Tails$/ do
  next if @skip_steps_while_restoring_background
  step "a freshly started Tails with boot options \"\""
end

Given /^a freshly started Tails with boot options "([^"]*)"$/ do |options|
  next if @skip_steps_while_restoring_background
  @vm.start
  post_vm_start_hook
  @screen.wait('TailsBootSplash.png', 30)
  @screen.wait('TailsBootSplashTabMsg.png', 10)
  @screen.type("\t")
  # Start the VM remote shell
  @screen.type(" autotest_never_use_this_option " + options +
               Sikuli::KEY_RETURN)
  @screen.wait('TailsGreeter.png', 120)
#  wait_until_remote_shell_is_up
  # FIXME: Uncomment above and remove workaround below once the
  # remote shell reliably runs all the time.
  # Start of workaround:
  begin
    wait_until_remote_shell_is_up
  rescue
    STDERR.puts "*************************************************"
    STDERR.puts "Fresh Tails boot but no remote shell. Restarting."
    STDERR.puts "*************************************************"
    @vm.domain.destroy
    @vm.display.stop
    @vm.start
    step "a freshly started Tails with boot options \"#{options}\""
  end
  # End of workaround.
end

Given /^the network is plugged$/ do
  next if @skip_steps_while_restoring_background
  @vm.plug_network
end

Given /^the network is unplugged$/ do
  next if @skip_steps_while_restoring_background
  @vm.unplug_network
end

Given /^I log in to a new session$/ do
  next if @skip_steps_while_restoring_background
  @screen.click('TailsGreeterLoginButton.png')
  # FIXME: Here we should do something which waits for all Tails
  # Greeter post-hooks to finish so we can rid ourselves of steps like
  # "Tails Greeter has dealt with the sudo password"
end

Given /^I enable more Tails Greeter options$/ do
  next if @skip_steps_while_restoring_background
  match = @screen.find('TailsGreeterMoreOptions.png')
  pos_x = match.x + match.width/2
  # height*2 may seem odd, but we want to click the button below the
  # match. This may even work accross different screen resolutions.
  pos_y = match.y + match.height*2
  @screen.click(pos_x, pos_y)
  @screen.wait('TailsGreeterForward.png', 10)
  @screen.click('TailsGreeterForward.png')
  @screen.wait('TailsGreeterLoginButton.png', 20)
end

Given /^I set sudo password "([^"]*)"$/ do |password|
  @sudo_password = password
  next if @skip_steps_while_restoring_background
  @screen.wait("TailsGreeterAdminPassword.png", 20)
  match = @screen.find('TailsGreeterPassword.png')
  # width*3 may seem odd, but we want to click the field right of the
  # match. This may even work accross different screen resolutions.
  pos_x = match.x + match.width*3
  pos_y = match.y + match.height/2
  @screen.click(pos_x, pos_y)
  @screen.type(@sudo_password + "\t" + @sudo_password)
end

Given /^Tails Greeter has dealt with the sudo password$/ do
  f1 = "/etc/sudoers.d/tails-greeter"
  f2 = "#{f1}-no-password-lecture"
  try_for(20) {
    @vm.execute("test -e '#{f1}' -o -e '#{f2}'").success?
  }
end

Given /^GNOME has started$/ do
  next if @skip_steps_while_restoring_background
  case @theme
  when "winxp"
    desktop_started_picture = 'WinXPStartButton.png'
  else
    desktop_started_picture = 'GnomeStarted.png'
  end
  @screen.wait(desktop_started_picture, 60)
end

Given /^I have a network connection$/ do
  next if @skip_steps_while_restoring_background
  # Wait until the VM's remote shell is available, which implies
  # that the network is up.
  try_for(120) { guest_has_network? }
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

Given /^Iceweasel has autostarted and is not loading a web page$/ do
  next if @skip_steps_while_restoring_background
#  @screen.wait("IceweaselRunning.png", 120)
  case @theme
  when "winxp"
    iceweasel_picture = "WinXPIceweaselWindow.png"
  else
    iceweasel_picture = "IceweaselRunning.png"
  end
  step "I see \"#{iceweasel_picture}\" after at most 120 seconds"

  # Stop iceweasel to load its home page. We do this to prevent Tor
  # from gerring confused in case we save and restore a snapshot in
  # the middle of loading a page.
  @screen.type("l", Sikuli::KEY_CTRL)
  @screen.type("about:blank" + Sikuli::KEY_RETURN)
end

Given /^I have closed all annoying notifications$/ do
  next if @skip_steps_while_restoring_background
  case @theme
  when "winxp"
    notification_picture = "WinXPNotificationX.png"
  else
    notification_picture = "GnomeNotificationX.png"
  end

  # First we wait a short while to give notifications a chance to show
  begin
    @screen.wait(notification_picture, 10)
  rescue
    # noop
  end

  begin
    # note that we cannot use find_all as the resulting matches will
    # have the positions from before we start closing notificatios,
    # but closing them will change the positions.
    while match = @screen.find(notification_picture)
      @screen.click(match.x + match.width/2, match.y + match.height/2)
    end
  rescue Sikuli::ImageNotFound
    # noop
  end
end

Given /^I save the background snapshot if it does not exist$/ do
  if !@skip_steps_while_restoring_background
    @vm.save_snapshot(@background_snapshot)
    restore_background
  end
  # Now we stop skipping steps from the snapshot restore.
  @skip_steps_while_restoring_background = false
end

Then /^I see "([^"]*)" after at most (\d+) seconds$/ do |image, time|
  next if @skip_steps_while_restoring_background
  @screen.wait(image, time.to_i)
end

Then /^all Internet traffic has only flowed through Tor$/ do
  next if @skip_steps_while_restoring_background
  # This command will grab all router IP addresses from the Tor
  # consensus in the VM.
  cmd = 'awk "/^r/ { print \$6 }" /var/lib/tor/cached-microdesc-consensus'
  tor_relays = @vm.execute(cmd).stdout.split("\n")
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
    pcap_copy = "#{Dir.pwd}/features/pcap_with_leaks-#{DateTime.now}"
    FileUtils.cp(@sniffer.pcap_file, pcap_copy)
    puts "Full network capture available at: #{pcap_copy}"
    raise "There were network leaks!"
  end
end

When /^I open the GNOME run dialog$/ do
  next if @skip_steps_while_restoring_background
  @screen.type(Sikuli::KEY_F2, Sikuli::KEY_ALT)
  case @theme
  when "winxp"
    run_dialog_picture = 'WinXPRunDialog.png'
  else
    run_dialog_picture = 'GnomeRunDialog.png'
  end
  @screen.wait(run_dialog_picture, 10)
end

When /^I run "([^"]*)"$/ do |program|
  next if @skip_steps_while_restoring_background
  step "I open the GNOME run dialog"
  @screen.type(program + Sikuli::KEY_RETURN)
end

Given /^I enter the sudo password in the PolicyKit prompt$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('PolicyKitAuthPrompt.png', 60)
  sleep 1 # wait for weird fade-in to unblock the "Ok" button
  @screen.type(@sudo_password)
  @screen.type(Sikuli::KEY_RETURN)
  @screen.waitVanish('PolicyKitAuthPrompt.png', 10)
end

Given /^process "([^"]+)" is running$/ do |process|
  next if @skip_steps_while_restoring_background
  assert guest_has_process?(process)
end

Given /^I have killed the process "([^"]+)"$/ do |process|
  next if @skip_steps_while_restoring_background
  assert @vm.execute("killall #{process}").success?
end

Given /^I shutdown Tails$/ do
  next if @skip_steps_while_restoring_background
  @screen.click('TailsEmergencyShutdownButton.png')
  @screen.click('TailsEmergencyShutdownHalt.png')
  try_for(120) { ! @vm.is_running? }
end

Given /^package "([^"]+)" is installed$/ do |package|
  next if @skip_steps_while_restoring_background
  assert @vm.execute("dpkg -s #{package}").success?
end
