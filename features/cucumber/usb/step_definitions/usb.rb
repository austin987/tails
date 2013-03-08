def persistent_dirs
  ['/etc/ssh',
   '/home/amnesia/.claws-mail',
   '/home/amnesia/.gconf/system/networking/connections',
   '/home/amnesia/.gnome2/keyrings',
   '/home/amnesia/.gnupg',
   '/home/amnesia/.mozilla/firefox/bookmarks',
   '/home/amnesia/.purple',
   '/home/amnesia/.ssh',
   '/home/amnesia/Persistent',
   '/home/amnesia/custom_persistence',
   '/var/cache/apt/archives',
   '/var/lib/apt/lists']
end

Given /^I create a new (\d+) GiB USB drive named "([^"]+)"$/ do |size, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.create_new_usb_drive(name, size)
end

Given /^I clone USB drive "([^"]+)" to a new USB drive "([^"]+)"$/ do |from, to|
  next if @skip_steps_while_restoring_background
  @vm.storage.clone_to_new_usb_drive(from, to)
end

Given /^I plug USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  @vm.plug_usb_drive(name)
  dev = @vm.usb_drive_dev(name)
  try_for(20, :msg => "The USB drive was not detected by Tails") {
    @vm.execute("test -b #{dev}").success?
  }
end

Given /^I unplug USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  @vm.unplug_usb_drive(name)
end

def usb_install_helper(name)
  @screen.wait('USBCreateLiveUSB.png', 10)

  # FIXME: here we should select USB drive using #{name}
#  @screen.wait('USBTargetDevice.png', 10)
#  match = @screen.find('USBTargetDevice.png')
#  region_x = match.x
#  region_y = match.y + match.height
#  region_w = match.width*3
#  region_h = match.height*2
#  ocr = Sikuli::Region.new(region_x, region_y, region_w, region_h).text
#  STDERR.puts ocr
#  # Unfortunately this results in almost garbage, like "|]dev/sdm"
#  # when it should be /dev/sda1

  @screen.wait_and_click('USBCreateLiveUSB.png', 10)
#  @screen.hide_cursor
  @screen.wait_and_click('USBCreateLiveUSBNext.png', 10)
#  @screen.hide_cursor
  @screen.wait('USBInstallationComplete.png', 60*60)
  @screen.type(Sikuli::KEY_RETURN)
  @screen.type(Sikuli::KEY_F4, Sikuli::KEY_ALT)
end

When /^I "Clone & Install" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBCloneAndInstall.png', 10)
  usb_install_helper(name)
end

When /^I "Clone & Upgrade" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBCloneAndUpgrade.png', 10)
  usb_install_helper(name)
end

def shared_iso_dir_on_guest
  "/tmp/shared_dir"
end

Given /^I setup a filesystem share containing the Tails ISO$/ do
  next if @skip_steps_while_restoring_background
  @vm.add_share(File.dirname($tails_iso), shared_iso_dir_on_guest)
end

When /^I do a "Upgrade from ISO" on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I run \"liveusb-creator-launcher\""
  @screen.wait_and_click('USBUpgradeFromISO.png', 10)
  @screen.wait('USBUseLiveSystemISO.png', 10)
  match = @screen.find('USBUseLiveSystemISO.png')
  pos_x = match.x + match.width/2
  pos_y = match.y + match.height*2
  @screen.click(pos_x, pos_y)
  @screen.wait('USBSelectISO.png', 10)
  @screen.wait_and_click('GnomeFileDiagTypeFilename.png', 10)
  iso = "#{shared_iso_dir_on_guest}/#{File.basename($tails_iso)}"
  @screen.type(iso + Sikuli::KEY_RETURN)
  usb_install_helper(name)
end

Given /^I enable all persistence presets$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('PersistenceWizardPresets.png', 20)
  # Mark first non-default persistence preset
  @screen.type("\t\t")
  # Check all non-default persistence presets
  10.times do
    @screen.type(" \t")
  end
  # Now we'll have the custom persistence field selected
  @screen.type('/home/amnesia/custom_persistence')
  @screen.type('a', Sikuli::KEY_ALT)
  @screen.type('/etc/ssh')
  @screen.type('a', Sikuli::KEY_ALT)
  @screen.wait_and_click('PersistenceWizardSave.png', 10)
  @screen.wait('PersistenceWizardDone.png', 20)
  @screen.type(Sikuli::KEY_F4, Sikuli::KEY_ALT)
end

Given /^I create a persistent partition with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  step "I run \"tails-persistence-setup\""
  @screen.wait('PersistenceWizardWindow.png', 20)
  @screen.wait('PersistenceWizardStart.png', 20)
  @screen.type(pwd + "\t" + pwd + Sikuli::KEY_RETURN)
  @screen.wait('PersistenceWizardPresets.png', 120)
  step "I enable all persistence presets"
end

Then /^a Tails persistence partition exists on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  dev = @vm.usb_drive_dev(name)
  data_partition_dev = dev + "2"
  info = @vm.execute("udisks --show-info #{data_partition_dev}").stdout
  info_split = info.split("\n  partition:\n")
  dev_info = info_split[0]
  part_info = info_split[1]
  assert(dev_info.match("^  usage: +crypto$"),
         "Unexpected device field 'usage' on USB drive \"#{name}\"")
  assert(dev_info.match("^  type: +crypto_LUKS$"),
         "Unexpected device field 'type' on USB drive \"#{name}\"")
  assert(part_info.match("^    scheme: +gpt$"),
         "Unexpected partition scheme on USB drive \"#{name}\"")
  assert(part_info.match("^    label: +TailsData$"),
         "Unexpected partition label on USB drive \"#{name}\"")
end

Given /^I enable persistence with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  match = @screen.find('TailsGreeterPersistence.png')
  pos_x = match.x + match.width/2
  # height*2 may seem odd, but we want to click the button below the
  # match. This may even work accross different screen resolutions.
  pos_y = match.y + match.height*2
  @screen.click(pos_x, pos_y)
  @screen.wait('TailsGreeterPersistencePassphrase.png', 10)
  match = @screen.find('TailsGreeterPersistencePassphrase.png')
  pos_x = match.x + match.width*2
  pos_y = match.y + match.height/2
  @screen.click(pos_x, pos_y)
  @screen.type(pwd)
end

Given /^I enable read-only persistence with password "([^"]+)"$/ do |pwd|
  step "I enable persistence with password \"#{pwd}\""
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('TailsGreeterPersistenceReadOnly.png', 10)
end

Given /^persistence has been enabled$/ do
  next if @skip_steps_while_restoring_background
  try_for(60, :msg => "Some persistent dir was not mounted") {
    mount = @vm.execute("mount").stdout.chomp
    persistent_dirs.each do |dir|
      if ! mount.include? "on #{dir} "
        raise "persistent dir #{dir} missing"
      end
    end
  }
end

Given /^the computer is setup up to boot from USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  @vm.set_usb_boot(name)
end

Then /^Tails seems to have booted normally$/ do
  next if @skip_steps_while_restoring_background
  # FIXME: Something more we should check for?
  step "GNOME has started"
end

Then /^Tails is running from a USB drive$/ do
  next if @skip_steps_while_restoring_background
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_id = @vm.execute("udevadm info --device-id-of-file=/live/image").stdout.chomp
  boot_dev = @vm.execute("readlink -f /dev/block/'#{boot_dev_id}'").stdout.chomp
  boot_dev_info = @vm.execute("udevadm info --query=property --name='#{boot_dev}'").stdout.chomp
  boot_dev_type = (boot_dev_info.split("\n").select { |x| x.start_with? "ID_BUS=" })[0].split("=")[1]
  assert(boot_dev_type == "usb",
         "Got device type '#{boot_dev_type}' while expecting 'usb'")
end

When /^I write some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_persist", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

When /^I remove some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    assert(@vm.execute("rm #{dir}/XXX_persist").success?,
           "Could not remove file in persistent directory #{dir}")
  end
end

When /^I write some files not expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_dirs.each do |dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_gone", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

Then /^only the expected files should persist on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "a computer"
  step "the computer is setup up to boot from USB drive \"#{name}\""
  step "the network is unplugged"
  step "I start the computer"
  step "the computer boots Tails"
  step "I enable read-only persistence with password \"asdf\""
  step "I log in to a new session"
  step "persistence has been enabled"
  persistent_dirs.each do |dir|
    assert(@vm.execute("test -e #{dir}/XXX_persist").success?,
           "Could not find expected file in persistent directory #{dir}")
    assert(!@vm.execute("test -e #{dir}/XXX_gone").success?,
           "Found file that should not have persisted in persistent directory #{dir}")
  end
  step "I shutdown Tails"
end
