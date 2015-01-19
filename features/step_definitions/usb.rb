def persistent_mounts
  {
    "cups-configuration" => "/etc/cups",
    "nm-system-connections" => "/etc/NetworkManager/system-connections",
    "claws-mail" => "/home/#{LIVE_USER}/.claws-mail",
    "gnome-keyrings" => "/home/#{LIVE_USER}/.gnome2/keyrings",
    "gnupg" => "/home/#{LIVE_USER}/.gnupg",
    "bookmarks" => "/home/#{LIVE_USER}/.mozilla/firefox/bookmarks",
    "pidgin" => "/home/#{LIVE_USER}/.purple",
    "openssh-client" => "/home/#{LIVE_USER}/.ssh",
    "Persistent" => "/home/#{LIVE_USER}/Persistent",
    "apt/cache" => "/var/cache/apt/archives",
    "apt/lists" => "/var/lib/apt/lists",
  }
end

def persistent_volumes_mountpoints
  @vm.execute("ls -1 -d /live/persistence/*_unlocked/").stdout.chomp.split
end

Given /^I create a new (\d+) ([[:alpha:]]+) USB drive named "([^"]+)"$/ do |size, unit, name|
  next if @skip_steps_while_restoring_background
  @vm.storage.create_new_disk(name, {:size => size, :unit => unit})
end

Given /^I clone USB drive "([^"]+)" to a new USB drive "([^"]+)"$/ do |from, to|
  next if @skip_steps_while_restoring_background
  @vm.storage.clone_to_new_disk(from, to)
end

Given /^I unplug USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  @vm.unplug_drive(name)
end

Given /^the computer is set to boot from the old Tails DVD$/ do
  next if @skip_steps_while_restoring_background
  @vm.set_cdrom_boot(OLD_TAILS_ISO)
end

Given /^the computer is set to boot in UEFI mode$/ do
  next if @skip_steps_while_restoring_background
  @vm.set_os_loader('UEFI')
  @os_loader = 'UEFI'
end

class ISOHybridUpgradeNotSupported < StandardError
end

def usb_install_helper(name)
  @screen.wait('USBCreateLiveUSB.png', 10)

  # Here we'd like to select USB drive using #{name}, but Sikuli's
  # OCR seems to be too unreliable.
#  @screen.wait('USBTargetDevice.png', 10)
#  match = @screen.find('USBTargetDevice.png')
#  region_x = match.x
#  region_y = match.y + match.h
#  region_w = match.w*3
#  region_h = match.h*2
#  ocr = Sikuli::Region.new(region_x, region_y, region_w, region_h).text
#  STDERR.puts ocr
#  # Unfortunately this results in almost garbage, like "|]dev/sdm"
#  # when it should be /dev/sda1

  @screen.wait_and_click('USBCreateLiveUSB.png', 10)
  if @screen.exists("USBSuggestsInstall.png")
    raise ISOHybridUpgradeNotSupported
  end
  @screen.wait('USBCreateLiveUSBConfirmWindow.png', 10)
  @screen.wait_and_click('USBCreateLiveUSBConfirmYes.png', 10)
  @screen.wait('USBInstallationComplete.png', 60*60)
end

When /^I start Tails Installer$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "TailsInstaller" via the GNOME "Tails" applications menu'
end

When /^I "Clone & Install" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I start Tails Installer"
  @screen.wait_and_click('USBCloneAndInstall.png', 30)
  usb_install_helper(name)
end

When /^I "Clone & Upgrade" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I start Tails Installer"
  @screen.wait_and_click('USBCloneAndUpgrade.png', 30)
  usb_install_helper(name)
end

When /^I try a "Clone & Upgrade" Tails to USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  begin
    step "I \"Clone & Upgrade\" Tails to USB drive \"#{name}\""
  rescue ISOHybridUpgradeNotSupported
    # this is what we expect
  else
    raise "The USB installer should not succeed"
  end
end

When /^I am suggested to do a "Clone & Install"$/ do
  next if @skip_steps_while_restoring_background
  @screen.find("USBSuggestsInstall.png")
end

def shared_iso_dir_on_guest
  "/tmp/shared_iso_dir"
end

Given /^I setup a filesystem share containing the Tails ISO$/ do
  next if @skip_steps_while_restoring_background
  @vm.add_share(File.dirname(TAILS_ISO), shared_iso_dir_on_guest)
end

When /^I do a "Upgrade from ISO" on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "I start Tails Installer"
  @screen.wait_and_click('USBUpgradeFromISO.png', 10)
  @screen.wait('USBUseLiveSystemISO.png', 10)
  match = @screen.find('USBUseLiveSystemISO.png')
  @screen.click(match.getCenter.offset(0, match.h*2))
  @screen.wait('USBSelectISO.png', 10)
  @screen.wait_and_click('GnomeFileDiagTypeFilename.png', 10)
  iso = "#{shared_iso_dir_on_guest}/#{File.basename(TAILS_ISO)}"
  @screen.type(iso + Sikuli::Key.ENTER)
  usb_install_helper(name)
end

Given /^I enable all persistence presets$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('PersistenceWizardPresets.png', 20)
  # Mark first non-default persistence preset
  @screen.type(Sikuli::Key.TAB*2)
  # Check all non-default persistence presets
  12.times do
    @screen.type(Sikuli::Key.SPACE + Sikuli::Key.TAB)
  end
  @screen.wait_and_click('PersistenceWizardSave.png', 10)
  @screen.wait('PersistenceWizardDone.png', 20)
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
end

Given /^I create a persistent partition with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  step 'I start "ConfigurePersistentVolume" via the GNOME "Tails" applications menu'
  @screen.wait('PersistenceWizardWindow.png', 40)
  @screen.wait('PersistenceWizardStart.png', 20)
  @screen.type(pwd + "\t" + pwd + Sikuli::Key.ENTER)
  @screen.wait('PersistenceWizardPresets.png', 300)
  step "I enable all persistence presets"
end

def check_part_integrity(name, dev, usage, type, scheme, label)
  info = @vm.execute("udisks --show-info #{dev}").stdout
  info_split = info.split("\n  partition:\n")
  dev_info = info_split[0]
  part_info = info_split[1]
  assert(dev_info.match("^  usage: +#{usage}$"),
         "Unexpected device field 'usage' on USB drive '#{name}', '#{dev}'")
  assert(dev_info.match("^  type: +#{type}$"),
         "Unexpected device field 'type' on USB drive '#{name}', '#{dev}'")
  assert(part_info.match("^    scheme: +#{scheme}$"),
         "Unexpected partition scheme on USB drive '#{name}', '#{dev}'")
  assert(part_info.match("^    label: +#{label}$"),
         "Unexpected partition label on USB drive '#{name}', '#{dev}'")
end

def tails_is_installed_helper(name, tails_root, loader)
  dev = @vm.disk_dev(name) + "1"
  check_part_integrity(name, dev, "filesystem", "vfat", "gpt", "Tails")

  target_root = "/mnt/new"
  @vm.execute("mkdir -p #{target_root}")
  @vm.execute("mount #{dev} #{target_root}")

  c = @vm.execute("diff -qr '#{tails_root}/live' '#{target_root}/live'")
  assert(c.success?,
         "USB drive '#{name}' has differences in /live:\n#{c.stdout}")

  syslinux_files = @vm.execute("ls -1 #{target_root}/syslinux").stdout.chomp.split
  # We deal with these files separately
  ignores = ["syslinux.cfg", "exithelp.cfg", "ldlinux.sys"]
  for f in syslinux_files - ignores do
    c = @vm.execute("diff -q '#{tails_root}/#{loader}/#{f}' " +
                    "'#{target_root}/syslinux/#{f}'")
    assert(c.success?, "USB drive '#{name}' has differences in " +
           "'/syslinux/#{f}'")
  end

  # The main .cfg is named differently vs isolinux
  c = @vm.execute("diff -q '#{tails_root}/#{loader}/#{loader}.cfg' " +
                  "'#{target_root}/syslinux/syslinux.cfg'")
  assert(c.success?, "USB drive '#{name}' has differences in " +
         "'/syslinux/syslinux.cfg'")

  @vm.execute("umount #{target_root}")
  @vm.execute("sync")
end

Then /^the running Tails is installed on USB drive "([^"]+)"$/ do |target_name|
  next if @skip_steps_while_restoring_background
  loader = boot_device_type == "usb" ? "syslinux" : "isolinux"
  tails_is_installed_helper(target_name, "/lib/live/mount/medium", loader)
end

Then /^the ISO's Tails is installed on USB drive "([^"]+)"$/ do |target_name|
  next if @skip_steps_while_restoring_background
  iso = "#{shared_iso_dir_on_guest}/#{File.basename(TAILS_ISO)}"
  iso_root = "/mnt/iso"
  @vm.execute("mkdir -p #{iso_root}")
  @vm.execute("mount -o loop #{iso} #{iso_root}")
  tails_is_installed_helper(target_name, iso_root, "isolinux")
  @vm.execute("umount #{iso_root}")
end

Then /^there is no persistence partition on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  data_part_dev = @vm.disk_dev(name) + "2"
  assert(!@vm.execute("test -b #{data_part_dev}").success?,
         "USB drive #{name} has a partition '#{data_part_dev}'")
end

Then /^a Tails persistence partition with password "([^"]+)" exists on USB drive "([^"]+)"$/ do |pwd, name|
  next if @skip_steps_while_restoring_background
  dev = @vm.disk_dev(name) + "2"
  check_part_integrity(name, dev, "crypto", "crypto_LUKS", "gpt", "TailsData")

  # The LUKS container may already be opened, e.g. by udisks after
  # we've run tails-persistence-setup.
  c = @vm.execute("ls -1 /dev/mapper/")
  if c.success?
    for candidate in c.stdout.split("\n")
      luks_info = @vm.execute("cryptsetup status #{candidate}")
      if luks_info.success? and luks_info.stdout.match("^\s+device:\s+#{dev}$")
        luks_dev = "/dev/mapper/#{candidate}"
        break
      end
    end
  end
  if luks_dev.nil?
    c = @vm.execute("echo #{pwd} | cryptsetup luksOpen #{dev} #{name}")
    assert(c.success?, "Couldn't open LUKS device '#{dev}' on  drive '#{name}'")
    luks_dev = "/dev/mapper/#{name}"
  end

  # Adapting check_part_integrity() seems like a bad idea so here goes
  info = @vm.execute("udisks --show-info #{luks_dev}").stdout
  assert info.match("^  cleartext luks device:$")
  assert info.match("^  usage: +filesystem$")
  assert info.match("^  type: +ext[34]$")
  assert info.match("^  label: +TailsData$")

  mount_dir = "/mnt/#{name}"
  @vm.execute("mkdir -p #{mount_dir}")
  c = @vm.execute("mount #{luks_dev} #{mount_dir}")
  assert(c.success?,
         "Couldn't mount opened LUKS device '#{dev}' on drive '#{name}'")

  @vm.execute("umount #{mount_dir}")
  @vm.execute("sync")
  @vm.execute("cryptsetup luksClose #{name}")
end

Given /^I enable persistence with password "([^"]+)"$/ do |pwd|
  next if @skip_steps_while_restoring_background
  @screen.wait('TailsGreeterPersistence.png', 10)
  @screen.type(Sikuli::Key.SPACE)
  @screen.wait('TailsGreeterPersistencePassphrase.png', 10)
  match = @screen.find('TailsGreeterPersistencePassphrase.png')
  @screen.click(match.getCenter.offset(match.w*2, match.h/2))
  @screen.type(pwd)
end

def tails_persistence_enabled?
  persistence_state_file = "/var/lib/live/config/tails.persistence"
  return @vm.execute("test -e '#{persistence_state_file}'").success? &&
         @vm.execute('. #{persistence_state_file} && ' +
                     'test "$TAILS_PERSISTENCE_ENABLED" = true').success?
end

Given /^persistence is enabled$/ do
  next if @skip_steps_while_restoring_background
  try_for(120, :msg => "Persistence is disabled") do
    tails_persistence_enabled?
  end
  # Check that all persistent directories are mounted
  mount = @vm.execute("mount").stdout.chomp
  for _, dir in persistent_mounts do
    assert(mount.include?("on #{dir} "),
           "Persistent directory '#{dir}' is not mounted")
  end
end

Given /^persistence is disabled$/ do
  next if @skip_steps_while_restoring_background
  assert(!tails_persistence_enabled?, "Persistence is enabled")
end

Given /^I enable read-only persistence with password "([^"]+)"$/ do |pwd|
  step "I enable persistence with password \"#{pwd}\""
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click('TailsGreeterPersistenceReadOnly.png', 10)
end

def boot_device
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_id = @vm.execute("udevadm info --device-id-of-file=/lib/live/mount/medium").stdout.chomp
  boot_dev = @vm.execute("readlink -f /dev/block/'#{boot_dev_id}'").stdout.chomp
  return boot_dev
end

def boot_device_type
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_info = @vm.execute("udevadm info --query=property --name='#{boot_device}'").stdout.chomp
  boot_dev_type = (boot_dev_info.split("\n").select { |x| x.start_with? "ID_BUS=" })[0].split("=")[1]
  return boot_dev_type
end

Then /^Tails is running from USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  assert_equal("usb", boot_device_type)
  actual_dev = boot_device
  # The boot partition differs between a "normal" install using the
  # USB installer and isohybrid installations
  expected_dev_normal = @vm.disk_dev(name) + "1"
  expected_dev_isohybrid = @vm.disk_dev(name) + "4"
  assert(actual_dev == expected_dev_normal ||
         actual_dev == expected_dev_isohybrid,
         "We are running from device #{actual_dev}, but for USB drive " +
         "'#{name}' we expected to run from either device " +
         "#{expected_dev_normal} (when installed via the USB installer) " +
         "or #{expected_dev_normal} (when installed from an isohybrid)")
end

Then /^the boot device has safe access rights$/ do
  next if @skip_steps_while_restoring_background

  super_boot_dev = boot_device.sub(/[[:digit:]]+$/, "")
  devs = @vm.execute("ls -1 #{super_boot_dev}*").stdout.chomp.split
  assert(devs.size > 0, "Could not determine boot device")
  all_users = @vm.execute("cut -d':' -f1 /etc/passwd").stdout.chomp.split
  all_users_with_groups = all_users.collect do |user|
    groups = @vm.execute("groups #{user}").stdout.chomp.sub(/^#{user} : /, "").split(" ")
    [user, groups]
  end
  for dev in devs do
    dev_owner = @vm.execute("stat -c %U #{dev}").stdout.chomp
    dev_group = @vm.execute("stat -c %G #{dev}").stdout.chomp
    dev_perms = @vm.execute("stat -c %a #{dev}").stdout.chomp
    assert_equal("root", dev_owner)
    assert(dev_group == "disk" || dev_group == "root",
           "Boot device '#{dev}' owned by group '#{dev_group}', expected " +
           "'disk' or 'root'.")
    assert_equal("1660", dev_perms)
    for user, groups in all_users_with_groups do
      next if user == "root"
      assert(!(groups.include?(dev_group)),
             "Unprivileged user '#{user}' is in group '#{dev_group}' which " +
             "owns boot device '#{dev}'")
    end
  end

  info = @vm.execute("udisks --show-info #{super_boot_dev}").stdout
  assert(info.match("^  system internal: +1$"),
         "Boot device '#{super_boot_dev}' is not system internal for udisks")
end

Then /^persistent filesystems have safe access rights$/ do
  persistent_volumes_mountpoints.each do |mountpoint|
    fs_owner = @vm.execute("stat -c %U #{mountpoint}").stdout.chomp
    fs_group = @vm.execute("stat -c %G #{mountpoint}").stdout.chomp
    fs_perms = @vm.execute("stat -c %a #{mountpoint}").stdout.chomp
    assert_equal("root", fs_owner)
    assert_equal("root", fs_group)
    assert_equal('775', fs_perms)
  end
end

Then /^persistence configuration files have safe access rights$/ do
  persistent_volumes_mountpoints.each do |mountpoint|
    assert(@vm.execute("test -e #{mountpoint}/persistence.conf").success?,
           "#{mountpoint}/persistence.conf does not exist, while it should")
    assert(@vm.execute("test ! -e #{mountpoint}/live-persistence.conf").success?,
           "#{mountpoint}/live-persistence.conf does exist, while it should not")
    @vm.execute(
      "ls -1 #{mountpoint}/persistence.conf #{mountpoint}/live-*.conf"
    ).stdout.chomp.split.each do |f|
      file_owner = @vm.execute("stat -c %U '#{f}'").stdout.chomp
      file_group = @vm.execute("stat -c %G '#{f}'").stdout.chomp
      file_perms = @vm.execute("stat -c %a '#{f}'").stdout.chomp
      assert_equal("tails-persistence-setup", file_owner)
      assert_equal("tails-persistence-setup", file_group)
      assert_equal("600", file_perms)
    end
  end
end

Then /^persistent directories have safe access rights$/ do
  next if @skip_steps_while_restoring_background
  expected_perms = "700"
  persistent_volumes_mountpoints.each do |mountpoint|
    # We also want to check that dotfiles' source has safe permissions
    all_persistent_dirs = persistent_mounts.clone
    all_persistent_dirs["dotfiles"] = "/home/#{LIVE_USER}/"
    persistent_mounts.each do |src, dest|
      next unless dest.start_with?("/home/#{LIVE_USER}/")
      f = "#{mountpoint}/#{src}"
      next unless @vm.execute("test -d #{f}").success?
      file_perms = @vm.execute("stat -c %a '#{f}'").stdout.chomp
      assert_equal(expected_perms, file_perms)
    end
  end
end

When /^I write some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_mounts.each do |_, dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_persist", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

When /^I remove some files expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_mounts.each do |_, dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("rm #{dir}/XXX_persist", user=owner).success?,
           "Could not remove file in persistent directory #{dir}")
  end
end

When /^I write some files not expected to persist$/ do
  next if @skip_steps_while_restoring_background
  persistent_mounts.each do |_, dir|
    owner = @vm.execute("stat -c %U #{dir}").stdout.chomp
    assert(@vm.execute("touch #{dir}/XXX_gone", user=owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

Then /^the expected persistent files are present in the filesystem$/ do
  next if @skip_steps_while_restoring_background
  persistent_mounts.each do |_, dir|
    assert(@vm.execute("test -e #{dir}/XXX_persist").success?,
           "Could not find expected file in persistent directory #{dir}")
    assert(!@vm.execute("test -e #{dir}/XXX_gone").success?,
           "Found file that should not have persisted in persistent directory #{dir}")
  end
end

Then /^only the expected files should persist on USB drive "([^"]+)"$/ do |name|
  next if @skip_steps_while_restoring_background
  step "a computer"
  step "the computer is set to boot from USB drive \"#{name}\""
  step "the network is unplugged"
  step "I start the computer"
  step "the computer boots Tails"
  step "I enable read-only persistence with password \"asdf\""
  step "I log in to a new session"
  step "persistence is enabled"
  step "GNOME has started"
  step "all notifications have disappeared"
  step "the expected persistent files are present in the filesystem"
  step "I shutdown Tails and wait for the computer to power off"
end

When /^I delete the persistent partition$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "DeletePersistentVolume" via the GNOME "Tails" applications menu'
  @screen.wait("PersistenceWizardWindow.png", 40)
  @screen.wait("PersistenceWizardDeletionStart.png", 20)
  @screen.type(" ")
  @screen.wait("PersistenceWizardDone.png", 120)
end

Then /^Tails has started in UEFI mode$/ do
  assert(@vm.execute("test -d /sys/firmware/efi").success?,
         "/sys/firmware/efi does not exist")
 end
