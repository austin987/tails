# coding: utf-8
# Returns a hash that for each persistence preset the running Tails is aware of,
# for each of the corresponding configuration lines,
# maps the source to the destination.
def get_persistence_presets_config(skip_links = false)
  # Perl script that prints all persistence configuration lines (one per line)
  # in the form: <mount_point>:<comma-separated-list-of-options>
  script = <<-EOF
  use strict;
  use warnings FATAL => "all";
  use Tails::Persistence::Configuration::Presets;
  foreach my $atom (Tails::Persistence::Configuration::Presets->new()->atoms) {
    say $atom->destination, ":", join(",", @{$atom->options});
  }
EOF
  # VMCommand:s cannot handle newlines, and they're irrelevant in the
  # above perl script any way
  script.delete!("\n")
  presets_configs = $vm.execute_successfully("perl -E '#{script}'")
                       .stdout.chomp.split("\n")
  assert presets_configs.size >= 10,
         "Got #{presets_configs.size} persistence preset configuration lines, " +
         "which is too few"
  persistence_mapping = Hash.new
  for line in presets_configs
    destination, options_str = line.split(":")
    options = options_str.split(",")
    is_link = options.include? "link"
    next if is_link and skip_links
    source_str = options.find { |option| /^source=/.match option }
    # If no source is given as an option, live-boot's persistence
    # feature defaults to the destination minus the initial "/".
    if source_str.nil?
      source = destination.partition("/").last
    else
      source = source_str.split("=")[1]
    end
    persistence_mapping[source] = destination
  end
  return persistence_mapping
end

def persistent_dirs
  get_persistence_presets_config
end

def persistent_mounts
  get_persistence_presets_config(true)
end

def persistent_volumes_mountpoints
  $vm.execute("ls -1 -d /live/persistence/*_unlocked/").stdout.chomp.split
end

# Returns an array that for each persistence preset the running Tails is aware of,
# contains a hash with the following keys: id, enabled, has_configuration_button.
def persistent_presets_ui_settings
  # Perl script that prints all persistence presets
  # in the form: <id>:<enabled>:<has_configuration_button>
  script = <<-EOF
  use strict;
  use warnings FATAL => "all";
  use Tails::Persistence::Configuration::Presets;
  foreach my $preset (Tails::Persistence::Configuration::Presets->new()->all) {
    say(sprintf(
      "%s:%s:%s",
      $preset->{id},
      ($preset->{enabled} ? 1 : 0),
      (exists($preset->{configuration_app_desktop_id}) && defined($preset->{configuration_app_desktop_id})
         ? 1
         : 0
      ),
    ));
  }
EOF
  # VMCommand:s cannot handle newlines, and they're irrelevant in the
  # above perl script any way
  script.delete!("\n")
  presets = $vm.execute_successfully("perl -E '#{script}'")
               .stdout.chomp.split("\n")
  assert presets.size >= 10,
         "Got #{presets.size} persistence presets, " +
         "which is too few"
  presets_ui_settings = Array.new
  for line in presets
    id, enabled, has_configuration_button = line.split(":")
    presets_ui_settings += [{
      'id'                       => id,
      'enabled'                  => (enabled == '1'),
      'has_configuration_button' => (has_configuration_button == '1'),
    }]
  end
  return presets_ui_settings
end


def recover_from_upgrader_failure
  $vm.execute('pkill --full tails-upgrade-frontend-wrapper')
  $vm.execute('killall tails-upgrade-frontend zenity')
  # Do not sleep when retrying
  $vm.spawn('tails-upgrade-frontend-wrapper --no-wait', user: LIVE_USER)
end

Given /^I clone USB drive "([^"]+)" to a (new|temporary) USB drive "([^"]+)"$/ do |from, mode, to|
  $vm.storage.clone_to_new_disk(from, to)
  if mode == 'temporary'
    add_after_scenario_hook { $vm.storage.delete_volume(to) }
  end
end

Given /^I unplug USB drive "([^"]+)"$/ do |name|
  $vm.unplug_drive(name)
end

Given /^the computer is set to boot from the old Tails DVD$/ do
  $vm.set_cdrom_boot(OLD_TAILS_ISO)
end

Given /^the computer is set to boot in UEFI mode$/ do
  $vm.set_os_loader('UEFI')
  @os_loader = 'UEFI'
end

def tails_installer_selected_device
  @installer.child('Target USB stick:', roleName: 'label').parent
    .child('', roleName: 'combo box', recursive: false).name
end

def tails_installer_is_device_selected?(name)
  device = $vm.disk_dev(name)
  tails_installer_selected_device[/\(#{device}\d*\)$/]
end

def tails_installer_match_status(pattern)
  @installer.child('', roleName: 'text').text[pattern]
end

When /^I start Tails Installer$/ do
  @installer_log_path = '/tmp/tails-installer.log'
  step "I run \"/usr/bin/tails-installer --verbose > #{@installer_log_path} 2>&1\" in GNOME Terminal"
  @installer = Dogtail::Application.new('tails-installer')
  @installer.child('Tails Installer', roleName: 'frame')
  # Sometimes Dogtail will find the Installer and click its window
  # before it is shown (searchShowingOnly is not perfect) which
  # generally means clicking somewhere on the Terminal => the click is
  # lost *and* the installer does not go to the foreground. So let's
  # wait a bit extra.
  sleep 3
  $vm.focus_window('Tails Installer')
end

When /^I am told by Tails Installer that.*"([^"]+)".*$/ do |status|
  try_for(10) do
    tails_installer_match_status(status)
  end
end

Then /^a suitable USB device is (?:still )?not found$/ do
  @installer.child(
    'No device suitable to install Tails could be found', roleName: 'label'
  )
end

Then /^(no|the "([^"]+)") USB drive is selected$/ do |mode, name|
  try_for(30) do
    if mode == 'no'
      tails_installer_selected_device == ''
    else
      tails_installer_is_device_selected?(name)
    end
  end
end

When /^I (install|reinstall|upgrade) Tails (?:to|on) USB drive "([^"]+)" by cloning$/ do |action, name|
  step "I start Tails Installer"
  # If the device was plugged *just* before this step, it might not be
  # completely ready (so it's shown) at this stage.
  try_for(10) { tails_installer_is_device_selected?(name) }
  begin
    if action == 'reinstall'
      label = 'Reinstall (delete all data)'
    else
      label = action.capitalize
    end
    @installer.button(label).click
    if action == 'upgrade'
      confirmation_label = 'Upgrade'
    else
      confirmation_label = 'Install'
    end
    @installer.child('Question', roleName: 'alert').button(confirmation_label).click
    try_for(15*60, { :delay => 10 }) do
      @installer
        .child('Information', roleName: 'alert')
        .child('Installation complete!', roleName: 'label')
      true
    end
  rescue Exception => e
    debug_log("Tails Installer debug log:\n" +
              $vm.file_content(@installer_log_path))
    raise e
  end
end

Given(/^I plug and mount a USB drive containing a Tails USB image$/) do
  usb_image_dir = share_host_files(TAILS_IMG)
  @usb_image_path = "#{usb_image_dir}/#{File.basename(TAILS_IMG)}"
end

Given /^I enable all persistence presets$/ do
  @screen.wait('PersistenceWizardPresets.png', 20)
  presets = persistent_presets_ui_settings
  presets[0]['is_first'] = true
  debug_log("presets: #{presets}")
  for setting in presets
    debug_log("on preset: #{setting}")
    tabs_to_select_switch  = 3 # previous switch -> separator -> row -> switch
    tabs_to_select_switch -= 1 if setting['is_first']
    tabs_to_select_switch += 1 if setting['has_configuration_button']
    # Select the switch
    debug_log("typing TAB #{tabs_to_select_switch} times to select the switch")
    tabs_to_select_switch.times do
      debug_log("typing TAB")
      @screen.type(Sikuli::Key.TAB)
    end
    # Activate the switch
    if ! setting['enabled']
      debug_log("pressing space")
      @screen.type(Sikuli::Key.SPACE)
    else
      debug_log("setting already enabled, skipping")
    end
  end
  save_and_exit_the_persistence_wizard
end

def save_and_exit_the_persistence_wizard
  @screen.type(Sikuli::Key.ENTER) # Press the Save button
  @screen.wait('PersistenceWizardDone.png', 60)
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
end

When /^I disable the first persistence preset$/ do
  step 'I start "Configure persistent volume" via GNOME Activities Overview'
  @screen.wait('PersistenceWizardPresets.png', 300)
  @screen.type(Sikuli::Key.TAB)
  @screen.type(Sikuli::Key.SPACE)
  @screen.type(Sikuli::Key.ENTER)
  @screen.wait('PersistenceWizardDone.png', 30)
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
end

Given /^I create a persistent partition( for Additional Software)?$/ do |asp|
  if not asp
    step 'I start "Configure persistent volume" via GNOME Activities Overview'
  end
  @screen.wait('PersistenceWizardStart.png', 60)
  @screen.type(@persistence_password + "\t" + @persistence_password + Sikuli::Key.ENTER)
  @screen.wait('PersistenceWizardPresets.png', 300)
  if not asp
    step "I enable all persistence presets"
  end
end

def check_disk_integrity(name, dev, scheme)
  info = $vm.execute("udisksctl info --block-device '#{dev}'").stdout
  info_split = info.split("\n  org\.freedesktop\.UDisks2\.PartitionTable:\n")
  dev_info = info_split[0]
  part_table_info = info_split[1]
  assert(part_table_info.match("^    Type: +#{scheme}$"),
         "Unexpected partition scheme on USB drive '#{name}', '#{dev}'")
end

def check_part_integrity(name, dev, usage, fs_type, part_label = nil, part_type = nil)
  info = $vm.execute("udisksctl info --block-device '#{dev}'").stdout
  info_split = info.split("\n  org\.freedesktop\.UDisks2\.Partition:\n")
  dev_info = info_split[0]
  part_info = info_split[1]
  assert(dev_info.match("^    IdUsage: +#{usage}$"),
         "Unexpected device field 'usage' on USB drive '#{name}', '#{dev}'")
  assert(dev_info.match("^    IdType: +#{fs_type}$"),
         "Unexpected device field 'IdType' on USB drive '#{name}', '#{dev}'")
  if part_label
    assert(part_info.match("^    Name: +#{part_label}$"),
           "Unexpected partition label on USB drive '#{name}', '#{dev}'")
  end
  if part_type
    assert(part_info.match("^    Type: +#{part_type}$"),
           "Unexpected partition type on USB drive '#{name}', '#{dev}'")
  end
end

def tails_is_installed_helper(name, tails_root, loader)
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"
  check_disk_integrity(name, disk_dev, "gpt")
  check_part_integrity(name, part_dev, "filesystem", "vfat", "Tails",
                       # EFI System Partition
                       'c12a7328-f81f-11d2-ba4b-00a0c93ec93b')

  target_root = "/mnt/new"
  $vm.execute("mkdir -p #{target_root}")
  $vm.execute("mount #{part_dev} #{target_root}")

  c = $vm.execute("diff -qr '#{tails_root}/live' '#{target_root}/live'")
  assert(c.success?,
         "USB drive '#{name}' has differences in /live:\n#{c.stdout}\n#{c.stderr}")

  syslinux_files = $vm.execute("ls -1 #{target_root}/syslinux").stdout.chomp.split
  # We deal with these files separately
  ignores = ["syslinux.cfg", "exithelp.cfg", "ldlinux.c32", "ldlinux.sys"]
  for f in syslinux_files - ignores do
    c = $vm.execute("diff -q '#{tails_root}/#{loader}/#{f}' " +
                    "'#{target_root}/syslinux/#{f}'")
    assert(c.success?, "USB drive '#{name}' has differences in " +
           "'/syslinux/#{f}'")
  end

  # The main .cfg is named differently vs isolinux
  c = $vm.execute("diff -q '#{tails_root}/#{loader}/#{loader}.cfg' " +
                  "'#{target_root}/syslinux/syslinux.cfg'")
  assert(c.success?, "USB drive '#{name}' has differences in " +
         "'/syslinux/syslinux.cfg'")

  $vm.execute("umount #{target_root}")
  $vm.execute("sync")
end

Then /^the running Tails is installed on USB drive "([^"]+)"$/ do |target_name|
  loader = boot_device_type == "usb" ? "syslinux" : "isolinux"
  tails_is_installed_helper(target_name, "/lib/live/mount/medium", loader)
end

Then /^there is no persistence partition on USB drive "([^"]+)"$/ do |name|
  data_part_dev = $vm.disk_dev(name) + "2"
  assert(!$vm.execute("test -b #{data_part_dev}").success?,
         "USB drive #{name} has a partition '#{data_part_dev}'")
end

Then /^a Tails persistence partition exists on USB drive "([^"]+)"$/ do |name|
  dev = $vm.disk_dev(name) + "2"
  check_part_integrity(name, dev, "crypto", "crypto_LUKS", "TailsData")

  # The LUKS container may already be opened, e.g. by udisks after
  # we've run tails-persistence-setup.
  c = $vm.execute("ls -1 --hide 'control' /dev/mapper/")
  if c.success?
    for candidate in c.stdout.split("\n")
      luks_info = $vm.execute("cryptsetup status '#{candidate}'")
      if luks_info.success? and luks_info.stdout.match("^\s+device:\s+#{dev}$")
        luks_dev = "/dev/mapper/#{candidate}"
        break
      end
    end
  end
  if luks_dev.nil?
    c = $vm.execute("echo #{@persistence_password} | " +
                    "cryptsetup luksOpen #{dev} #{name}")
    assert(c.success?, "Couldn't open LUKS device '#{dev}' on  drive '#{name}'")
    luks_dev = "/dev/mapper/#{name}"
  end

  # Adapting check_part_integrity() seems like a bad idea so here goes
  info = $vm.execute("udisksctl info --block-device '#{luks_dev}'").stdout
  assert info.match("^    CryptoBackingDevice: +'/[a-zA-Z0-9_/]+'$")
  assert info.match("^    IdUsage: +filesystem$")
  assert info.match("^    IdType: +ext[34]$")
  assert info.match("^    IdLabel: +TailsData$")

  mount_dir = "/mnt/#{name}"
  $vm.execute("mkdir -p #{mount_dir}")
  c = $vm.execute("mount '#{luks_dev}' #{mount_dir}")
  assert(c.success?,
         "Couldn't mount opened LUKS device '#{dev}' on drive '#{name}'")

  $vm.execute("umount #{mount_dir}")
  $vm.execute("sync")
  $vm.execute("cryptsetup luksClose #{name}")
end

Given /^I enable persistence$/ do
  @screen.wait_and_click('TailsGreeterPersistencePassphrase.png', 60)
  @screen.type(@persistence_password + Sikuli::Key.ENTER)
  @screen.wait('TailsGreeterPersistenceUnlocked.png', 30)
end

def tails_persistence_enabled?
  persistence_state_file = "/var/lib/live/config/tails.persistence"
  return $vm.execute("test -e '#{persistence_state_file}'").success? &&
         $vm.execute(". '#{persistence_state_file}' && " +
                     'test "$TAILS_PERSISTENCE_ENABLED" = true').success?
end

Given /^all persistence presets(| from the old Tails version)(| but the first one) are enabled$/ do |old_tails, except_first|
  assert(old_tails.empty? || except_first.empty?, "Unsupported case.")
  try_for(120, :msg => "Persistence is disabled") do
    tails_persistence_enabled?
  end
  unexpected_mounts = Array.new
  # Check that all persistent directories are mounted
  if old_tails.empty?
    expected_mounts = persistent_mounts
    if ! except_first.empty?
      first_expected_mount_source      = expected_mounts.keys[0]
      first_expected_mount_destination = expected_mounts[first_expected_mount_source]
      expected_mounts.delete(first_expected_mount_source)
      unexpected_mounts = [first_expected_mount_destination]
    end
  else
    assert_not_nil($remembered_persistence_mounts)
    expected_mounts = $remembered_persistence_mounts
  end
  mount = $vm.execute("mount").stdout.chomp
  for _, dir in expected_mounts do
    assert(mount.include?("on #{dir} "),
           "Persistent directory '#{dir}' is not mounted")
  end
  for dir in unexpected_mounts do
    assert(! mount.include?("on #{dir} "),
           "Persistent directory '#{dir}' is mounted")
  end
end

Given /^persistence is disabled$/ do
  assert(!tails_persistence_enabled?, "Persistence is enabled")
end

def boot_device
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  boot_dev_id = $vm.execute("udevadm info --device-id-of-file=/lib/live/mount/medium").stdout.chomp
  boot_dev = $vm.execute("readlink -f /dev/block/'#{boot_dev_id}'").stdout.chomp
  return boot_dev
end

def device_info(dev)
  # Approach borrowed from
  # config/chroot_local_includes/lib/live/config/998-permissions
  info = $vm.execute("udevadm info --query=property --name='#{dev}'").stdout.chomp
  info.split("\n").map { |e| e.split('=') } .to_h
end

def boot_device_type
  device_info(boot_device)['ID_BUS']
end

# Turn udisksctl info output into something more manipulable:
def parse_udisksctl_info(input)
  tree = {}
  section = nil
  key = nil
  input.chomp.split("\n").each { |line|
    case line
    when /^\/org\/freedesktop\/UDisks2\/block_devices\//
      # no-op, ignore first line = device
    when /^  (org\.freedesktop\.UDisks2\..+):$/
      section = $1
      tree[section] = {}
    when /^\s+(.+?):\s+(.+)$/
      key = $1
      value = $2
      tree[section][key] = value
    else
      # XXX: Best effort = consider this a continuation from previous
      # line (e.g. Symlinks), and add the whole line, without
      # stripping anything (e.g. leading whitespaces)
      tree[section][key] += line
    end
  }
  return tree
end

Then /^Tails is running from (.*) drive "([^"]+)"$/ do |bus, name|
  bus = bus.downcase
  case bus
  when "sata"
    expected_bus = "ata"
  else
    expected_bus = bus
  end
  assert_equal(expected_bus, boot_device_type)
  actual_dev = boot_device
  # The boot partition differs between an using Tails installer and
  # isohybrids. There's also a strange case isohybrids are thought to
  # be booting from the "raw" device, and not a partition of it
  # (#10504).
  expected_devs = ['', '1', '4'].map { |e| $vm.disk_dev(name) + e }
  assert(expected_devs.include?(actual_dev),
         "We are running from device #{actual_dev}, but for #{bus} drive " +
         "'#{name}' we expected to run from one of #{expected_devs}")
end

Then /^the boot device has safe access rights$/ do

  super_boot_dev = boot_device.sub(/[[:digit:]]+$/, "")
  devs = $vm.execute("ls -1 #{super_boot_dev}*").stdout.chomp.split
  assert(devs.size > 0, "Could not determine boot device")
  all_users = $vm.execute("cut -d':' -f1 /etc/passwd").stdout.chomp.split
  all_users_with_groups = all_users.collect do |user|
    groups = $vm.execute("groups #{user}").stdout.chomp.sub(/^#{user} : /, "").split(" ")
    [user, groups]
  end
  for dev in devs do
    dev_owner = $vm.execute("stat -c %U #{dev}").stdout.chomp
    dev_group = $vm.execute("stat -c %G #{dev}").stdout.chomp
    dev_perms = $vm.execute("stat -c %a #{dev}").stdout.chomp
    assert_equal("root", dev_owner)
    assert(dev_group == "disk" || dev_group == "root",
           "Boot device '#{dev}' owned by group '#{dev_group}', expected " +
           "'disk' or 'root'.")
    assert_equal("660", dev_perms)
    for user, groups in all_users_with_groups do
      next if user == "root"
      assert(!(groups.include?(dev_group)),
             "Unprivileged user '#{user}' is in group '#{dev_group}' which " +
             "owns boot device '#{dev}'")
    end
  end

  info = $vm.execute("udisksctl info --block-device '#{super_boot_dev}'").stdout
  assert(info.match("^    HintSystem: +true$"),
         "Boot device '#{super_boot_dev}' is not system internal for udisks")
end

Then /^all persistent filesystems have safe access rights$/ do
  persistent_volumes_mountpoints.each do |mountpoint|
    fs_owner = $vm.execute("stat -c %U #{mountpoint}").stdout.chomp
    fs_group = $vm.execute("stat -c %G #{mountpoint}").stdout.chomp
    fs_perms = $vm.execute("stat -c %a #{mountpoint}").stdout.chomp
    assert_equal("root", fs_owner)
    assert_equal("root", fs_group)
    assert_equal('775', fs_perms)
  end
end

Then /^all persistence configuration files have safe access rights$/ do
  persistent_volumes_mountpoints.each do |mountpoint|
    assert($vm.execute("test -e #{mountpoint}/persistence.conf").success?,
           "#{mountpoint}/persistence.conf does not exist, while it should")
    assert($vm.execute("test -e #{mountpoint}/persistence.conf.bak").success?,
           "#{mountpoint}/persistence.conf.bak does not exist, while it should")
    assert($vm.execute("test ! -e #{mountpoint}/live-persistence.conf").success?,
           "#{mountpoint}/live-persistence.conf does exist, while it should not")
    $vm.execute(
      "ls -1 #{mountpoint}/persistence.conf* #{mountpoint}/live-*.conf"
    ).stdout.chomp.split.each do |f|
      file_owner = $vm.execute("stat -c %U '#{f}'").stdout.chomp
      file_group = $vm.execute("stat -c %G '#{f}'").stdout.chomp
      file_perms = $vm.execute("stat -c %a '#{f}'").stdout.chomp
      assert_equal("tails-persistence-setup", file_owner)
      assert_equal("tails-persistence-setup", file_group)
      case f
      when /.*\/live-additional-software.conf$/
        assert_equal("644", file_perms)
      else
        assert_equal("600", file_perms)
      end
    end
  end
end

Then /^all persistent directories(| from the old Tails version) have safe access rights$/ do |old_tails|
  if old_tails.empty?
    expected_dirs = persistent_dirs
  else
    assert_not_nil($remembered_persistence_dirs)
    expected_dirs = $remembered_persistence_dirs
  end
  persistent_volumes_mountpoints.each do |mountpoint|
    expected_dirs.each do |src, dest|
      full_src = "#{mountpoint}/#{src}"
      assert_vmcommand_success $vm.execute("test -d #{full_src}")
      dir_perms = $vm.execute_successfully("stat -c %a '#{full_src}'").stdout.chomp
      dir_owner = $vm.execute_successfully("stat -c %U '#{full_src}'").stdout.chomp
      if dest.start_with?("/home/#{LIVE_USER}")
        expected_perms = "700"
        expected_owner = LIVE_USER
      else
        expected_perms = "755"
        expected_owner = "root"
      end
      assert_equal(expected_perms, dir_perms,
                   "Persistent source #{full_src} has permission " \
                   "#{dir_perms}, expected #{expected_perms}")
      assert_equal(expected_owner, dir_owner,
                   "Persistent source #{full_src} has owner " \
                   "#{dir_owner}, expected #{expected_owner}")
    end
  end
end

When /^I write some files expected to persist$/ do
  persistent_mounts.each do |_, dir|
    owner = $vm.execute("stat -c %U #{dir}").stdout.chomp
    assert($vm.execute("touch #{dir}/XXX_persist", :user => owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

When /^I write some dotfile expected to persist$/ do
  assert($vm.execute("touch /live/persistence/TailsData_unlocked/dotfiles/.XXX_persist",
                     :user => LIVE_USER).success?,
         "Could not create a file in the dotfiles persistence.")
end

When /^I remove some files expected to persist$/ do
  persistent_mounts.each do |_, dir|
    owner = $vm.execute("stat -c %U #{dir}").stdout.chomp
    assert($vm.execute("rm #{dir}/XXX_persist", :user => owner).success?,
           "Could not remove file in persistent directory #{dir}")
  end
end

When /^I write some files not expected to persist$/ do
  persistent_mounts.each do |_, dir|
    owner = $vm.execute("stat -c %U #{dir}").stdout.chomp
    assert($vm.execute("touch #{dir}/XXX_gone", :user => owner).success?,
           "Could not create file in persistent directory #{dir}")
  end
end

When /^I take note of which persistence presets are available$/ do
  $remembered_persistence_mounts = persistent_mounts
  $remembered_persistence_dirs = persistent_dirs
end

Then /^the expected persistent files(| created with the old Tails version) are present in the filesystem$/ do |old_tails|
  if old_tails.empty?
    expected_mounts = persistent_mounts
  else
    assert_not_nil($remembered_persistence_mounts)
    expected_mounts = $remembered_persistence_mounts
  end
  expected_mounts.each do |_, dir|
    assert($vm.execute("test -e #{dir}/XXX_persist").success?,
           "Could not find expected file in persistent directory #{dir}")
    assert(!$vm.execute("test -e #{dir}/XXX_gone").success?,
           "Found file that should not have persisted in persistent directory #{dir}")
  end
end

Then /^the expected persistent dotfile is present in the filesystem$/ do
  expected_dirs = persistent_dirs
  assert($vm.execute("test -L #{expected_dirs['dotfiles']}/.XXX_persist").success?,
         "Could not find expected persistent dotfile link.")
  assert($vm.execute("test -e $(readlink -f #{expected_dirs['dotfiles']}/.XXX_persist)").success?,
           "Could not find expected persistent dotfile link target.")
end

Then /^only the expected files are present on the persistence partition on USB drive "([^"]+)"$/ do |name|
  assert(!$vm.is_running?)
  disk = {
    :path => $vm.storage.disk_path(name),
    :opts => {
      :format => $vm.storage.disk_format(name),
      :readonly => true
    }
  }
  $vm.storage.guestfs_disk_helper(disk) do |g, disk_handle|
    partitions = g.part_list(disk_handle).map do |part_desc|
      disk_handle + part_desc["part_num"].to_s
    end
    partition = partitions.find do |part|
      g.blkid(part)["PART_ENTRY_NAME"] == "TailsData"
    end
    assert_not_nil(partition, "Could not find the 'TailsData' partition " \
                              "on disk '#{disk_handle}'")
    luks_mapping = File.basename(partition) + "_unlocked"
    g.luks_open(partition, @persistence_password, luks_mapping)
    luks_dev = "/dev/mapper/#{luks_mapping}"
    mount_point = "/"
    g.mount(luks_dev, mount_point)
    assert_not_nil($remembered_persistence_mounts)
    $remembered_persistence_mounts.each do |dir, _|
      # Guestfs::exists may have a bug; if the file exists, 1 is
      # returned, but if it doesn't exist false is returned. It seems
      # the translation of C types into Ruby types is glitchy.
      assert(g.exists("/#{dir}/XXX_persist") == 1,
             "Could not find expected file in persistent directory #{dir}")
      assert(g.exists("/#{dir}/XXX_gone") != 1,
             "Found file that should not have persisted in persistent directory #{dir}")
    end
    g.umount(mount_point)
    g.luks_close(luks_dev)
  end
end

When /^I delete the persistent partition$/ do
  step 'I start "Delete persistent volume" via GNOME Activities Overview'
  @screen.wait("PersistenceWizardDeletionStart.png", 120)
  @screen.type(" ")
  @screen.wait("PersistenceWizardDone.png", 120)
end

Then /^Tails has started in UEFI mode$/ do
  assert($vm.execute("test -d /sys/firmware/efi").success?,
         "/sys/firmware/efi does not exist")
 end

Given /^I create a ([[:alpha:]]+) label on disk "([^"]+)"$/ do |type, name|
  $vm.storage.disk_mklabel(name, type)
end

Given /^the file system changes introduced in version (.+) are (not )?present(?: in the (\S+) Browser's chroot)?$/ do |version, not_present, chroot_browser|
  assert_equal('1.1~test', version)
  upgrade_applied = not_present.nil?
  chroot_browser = "#{chroot_browser.downcase}-browser" if chroot_browser
  changes = [
    {
      filesystem: :rootfs,
      path: 'some_new_file',
      status: :added,
      new_content: <<-EOF
Some content
      EOF
    },
    {
      filesystem: :rootfs,
      path: 'etc/amnesia/version',
      status: :modified,
      new_content: <<-EOF
#{version} - 20380119
ffffffffffffffffffffffffffffffffffffffff
live-build: 3.0.5+really+is+2.0.12-0.tails2
live-boot: 4.0.2-1
live-config: 4.0.4-1
      EOF
    },
    {
      filesystem: :rootfs,
      path: 'etc/os-release',
      status: :modified,
      new_content: <<-EOF
TAILS_PRODUCT_NAME="Tails"
TAILS_VERSION_ID="#{version}"
      EOF
    },
    {
      filesystem: :rootfs,
      path: 'usr/share/common-licenses/BSD',
      status: :removed
    },
    {
      filesystem: :medium,
      path: 'utils/linux/syslinux',
      status: :removed
    },
  ]
  changes.each do |change|
    case change[:filesystem]
    when :rootfs
      path = '/'
      path += "var/lib/#{chroot_browser}/chroot/" if chroot_browser
      path += change[:path]
    when :medium
      path = '/lib/live/mount/medium/' + change[:path]
    else
      raise "Unknown filesysten '#{change[:filesystem]}'"
    end
    case change[:status]
    when :removed
      assert_equal(!upgrade_applied, $vm.file_exist?(path))
    when :added
      assert_equal(upgrade_applied, $vm.file_exist?(path))
      if upgrade_applied && change[:new_content]
        assert_equal(change[:new_content], $vm.file_content(path))
      end
    when :modified
      assert($vm.file_exist?(path))
      if upgrade_applied
        assert_not_nil(change[:new_content])
        assert_equal(change[:new_content], $vm.file_content(path))
      end
    else
      raise "Unknown status '#{change[:status]}'"
    end
  end
end

Then /^I am proposed to install an incremental upgrade to version (.+)$/ do |version|
  recovery_proc = Proc.new do
    recover_from_upgrader_failure
  end
  failure_pic = 'TailsUpgraderFailure.png'
  success_pic = "TailsUpgraderUpgradeTo#{version}.png"
  retry_tor(recovery_proc) do
    match, _ = @screen.waitAny([success_pic, failure_pic], 2*60)
    assert_equal(success_pic, match)
  end
end

When /^I agree to install the incremental upgrade$/ do
  @screen.click('TailsUpgraderUpgradeNowButton.png')
end

Then /^I can successfully install the incremental upgrade to version (.+)$/ do |version|
  step 'I agree to install the incremental upgrade'
  recovery_proc = Proc.new do
    recover_from_upgrader_failure
    step "I am proposed to install an incremental upgrade to version #{version}"
    step 'I agree to install the incremental upgrade'
  end
  failure_pic = 'TailsUpgraderFailure.png'
  success_pic = 'TailsUpgraderDownloadComplete.png'
  retry_tor(recovery_proc) do
    match, _ = @screen.waitAny([success_pic, failure_pic], 2*60)
    assert_equal(success_pic, match)
  end
  @screen.click('TailsUpgraderApplyUpgradeButton.png')
  @screen.wait('TailsUpgraderDone.png', 60)
end

Then /^the label of the system partition on "([^"]+)" is "([^"]+)"$/ do |name, label|
  assert($vm.is_running?)
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"
  check_disk_integrity(name, disk_dev, "gpt")
  check_part_integrity(name, part_dev, "filesystem", "vfat", label)
end

Then /^the system partition on "([^"]+)" is an EFI system partition$/ do |name|
  assert($vm.is_running?)
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"
  check_disk_integrity(name, disk_dev, "gpt")
  check_part_integrity(name, part_dev, "filesystem", "vfat", nil,
                       # EFI System Partition
                       'c12a7328-f81f-11d2-ba4b-00a0c93ec93b')
end

Then /^the FAT filesystem on the system partition on "([^"]+)" is at least (\d+)(.+) large$/ do |name, size, unit|
  # Let's use bytes all the way:
  wanted_size = convert_to_bytes(size.to_i, unit)

  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"

  udisks_info = $vm.execute_successfully("udisksctl info --block-device #{part_dev}").stdout
  partition_size = parse_udisksctl_info(udisks_info)['org.freedesktop.UDisks2.Partition']['Size'].to_i

  # Partition size:
  assert(partition_size >= wanted_size,
         "FAT partition is too small: #{partition_size} is less than #{wanted_size}")

  # -B 1 forces size to be expressed in bytes rather than (1K) blocks:
  fs_size = $vm.execute_successfully(
    "df --output=size -B 1 '/lib/live/mount/medium'"
  ).stdout.split("\n")[1].to_i
  assert(fs_size >= wanted_size,
         "FAT filesystem is too small: #{fs_size} is less than #{wanted_size}")
end

Then /^the UUID of the FAT filesystem on the system partition on "([^"]+)" was randomized$/ do |name|
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"

  # Get the UUID from the block area:
  udisks_info = $vm.execute_successfully("udisksctl info --block-device #{part_dev}").stdout
  fs_uuid = parse_udisksctl_info(udisks_info)['org.freedesktop.UDisks2.Block']['IdUUID']

  static_uuid = 'A690-20D2'
  assert(fs_uuid != static_uuid,
         "FS UUID on #{name} wasn't randomized, it's still: #{fs_uuid}")
end

Then /^the label of the FAT filesystem on the system partition on "([^"]+)" is "([^"]+)"$/ do |name, label|
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"

  # Get FS label from the block area:
  udisks_info = $vm.execute_successfully("udisksctl info --block-device #{part_dev}").stdout
  fs_label = parse_udisksctl_info(udisks_info)['org.freedesktop.UDisks2.Block']['IdLabel']

  assert(label == fs_label,
         "FS label on #{part_dev} is #{fs_label} instead of the expected #{label}")
end

Then /^the system partition on "([^"]+)" has the expected flags$/ do |name|
  disk_dev = $vm.disk_dev(name)
  part_dev = disk_dev + "1"

  # Look at the flags from the partition area:
  udisks_info = $vm.execute_successfully("udisksctl info --block-device #{part_dev}").stdout
  flags = parse_udisksctl_info(udisks_info)['org.freedesktop.UDisks2.Partition']['Flags']

  # See SYSTEM_PARTITION_FLAGS in create-usb-image-from-iso: 0xd000000000000005,
  # displayed in decimal (14987979559889010693) in udisksctl's output:
  expected_flags = 0xd000000000000005
  assert(flags == expected_flags.to_s,
         "Got #{flags} as partition flags on #{part_dev} (for #{name}), instead of the expected #{expected_flags}")
end


Given(/^I install a Tails USB image to the (\d+) MiB disk with GNOME Disks$/) do |size_in_MiB_of_destination_disk|
  # GNOME Disks displays devices sizes in GB, with 1 decimal digit precision
  size_in_GB_of_destination_disk = convert_from_bytes(
    convert_to_bytes(size_in_MiB_of_destination_disk.to_i, 'MiB'),
    'GB'
  ).round(1).to_s
  debug_log("Expected size of destination disk: " +
            size_in_GB_of_destination_disk)

  step 'I start "Disks" via GNOME Activities Overview'
  disks = Dogtail::Application.new('gnome-disks')
  disks.children(roleName: 'table cell').find { |row|
    /^#{size_in_GB_of_destination_disk} GB Drive/.match(row.name)
  }.grabFocus
  disks.child('Menu', roleName: 'toggle button').click
  disks.child('Restore Disk Image…', roleName: 'menu item').click
  restore_dialog = disks.child('Restore Disk Image', roleName: 'dialog',
                               showingOnly: true)
  # Open the file chooser
  disks.pressKey('Enter')
  select_disk_image_dialog = disks.child('Select Disk Image to Restore',
                                         roleName: 'file chooser',
                                         showingOnly: true)
  disks.typeText(@usb_image_path)
  sleep 2 # avoid ENTER being eaten by the auto-completion system
  disks.pressKey('Enter')
  try_for(10) do
    ! select_disk_image_dialog.showing
  end
  restore_dialog.child('Start Restoring…', roleName: 'push button').click
  disks.child('Information', roleName: 'alert', showingOnly: true)
    .child('Restore', roleName: 'push button', showingOnly: true)
    .click
  # Wait until the restoration job is finished
  job = disks.child('Job', roleName: 'label', showingOnly: true)
  try_for(60) do
    ! job.showing
  end
end
