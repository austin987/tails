# coding: utf-8
require 'expect'
require 'pty'
require 'tempfile'

$veracrypt_passphrase = 'asdf'
$veracrypt_hidden_passphrase = 'fdsa'
$veracrypt_volume_name = 'veracrypt'

def veracrypt_volume_size_in_GNOME(is_hidden)
  is_hidden ? '52 MB' : '105 MB'
end

def create_veracrypt_keyfile()
  keyfile = Tempfile.new('veracrypt-keyfile', $config["TMPDIR"])
  keyfile << 'asdf'
  keyfile.close
  return keyfile.path
end

def reply_prompt(r_f, w_f, prompt_re, answer)
  r_f.expect(prompt_re) do
    debug_log "got prompt, typing #{answer}"
    sleep 1 # tcplay takes some time before it's ready to read our input
    w_f.puts "#{answer}"
  end
end

def create_veracrypt_volume(type, with_keyfile)
  @veracrypt_is_hidden = (type == 'hidden')
  @veracrypt_needs_keyfile = with_keyfile
  step "I temporarily create a 100 MiB raw disk named \"#{$veracrypt_volume_name}\""
  disk_path = $vm.storage.disk_path($veracrypt_volume_name)
  keyfile = create_veracrypt_keyfile()
  fatal_system "losetup -f '#{disk_path}'"
  loop_dev = `losetup -j '#{disk_path}'`.split(':').first
  tcplay_create_cmd = "tcplay --create --device='#{loop_dev}'" \
                    + " --weak-keys --insecure-erase"
  tcplay_create_cmd += " --hidden" if @veracrypt_is_hidden
  tcplay_create_cmd += " --keyfile='#{keyfile}'" if @veracrypt_needs_keyfile
  debug_log "tcplay create command: #{tcplay_create_cmd}"
  PTY.spawn(tcplay_create_cmd) do |r_f, w_f, pid|
    begin
      w_f.sync = true
      reply_prompt(r_f, w_f, /^Passphrase:\s/, $veracrypt_passphrase)
      reply_prompt(r_f, w_f, /^Repeat passphrase:\s/, $veracrypt_passphrase)
      if @veracrypt_is_hidden
        reply_prompt(r_f, w_f, /^Passphrase for hidden volume:\s/,
                     $veracrypt_hidden_passphrase)
        reply_prompt(r_f, w_f, /^Repeat passphrase:\s/,
                     $veracrypt_hidden_passphrase)
        reply_prompt(r_f, w_f, /^Size of hidden volume.*:\s/, '50M')
      end
      reply_prompt(r_f, w_f, /^\s*Are you sure you want to proceed/, 'y')
      r_f.expect(/^All done!/)
    rescue Errno::EIO
    ensure
      Process.wait pid
    end
    $?.exitstatus == 0 or raise "#{tcplay_create_cmd} exited with #{$?.exitstatus}"
  end
  tcplay_map_cmd = "tcplay --map=veracrypt --device='#{loop_dev}'"
  tcplay_map_cmd += " --keyfile='#{keyfile}'" if @veracrypt_needs_keyfile
  debug_log "tcplay map command: #{tcplay_map_cmd}"
  PTY.spawn(tcplay_map_cmd) do |r_f, w_f, pid|
    begin
      w_f.sync = true
      reply_prompt(r_f, w_f, /^Passphrase:\s/,
                   @veracrypt_is_hidden ? $veracrypt_hidden_passphrase : $veracrypt_passphrase)
      r_f.expect(/^All ok!/)
    rescue Errno::EIO
    ensure
      Process.wait pid
    end
    $?.exitstatus == 0 or raise "#{tcplay_map_cmd} exited with #{$?.exitstatus}"
  end
  fatal_system "mkfs.vfat '/dev/mapper/veracrypt' >/dev/null"
  Dir.mktmpdir('veracrypt-mountpoint', $config["TMPDIR"]) { |mountpoint|
    fatal_system "mount -t vfat '/dev/mapper/veracrypt' '#{mountpoint}'"
    # must match SecretFileOnVeraCryptVolume.png when displayed in GNOME Files
    FileUtils.cp('/usr/share/common-licenses/GPL-3', "#{mountpoint}/SecretFile")
    fatal_system "umount '#{mountpoint}'"
  }
  fatal_system "tcplay --unmap=veracrypt"
  fatal_system "losetup -d '#{loop_dev}'"
  File.delete(keyfile)
end

When /^I plug a USB drive containing a (.+) VeraCrypt volume( with a keyfile)?$/ do |type, with_keyfile|
  create_veracrypt_volume(type, with_keyfile)
  step "I plug USB drive \"#{$veracrypt_volume_name}\""
end

When /^I plug and mount a USB drive containing a (.+) VeraCrypt file container( with a keyfile)?$/ do |type, with_keyfile|
  create_veracrypt_volume(type, with_keyfile)
  @veracrypt_shared_dir_in_guest = share_host_files($vm.storage.disk_path($veracrypt_volume_name))
  $vm.execute_successfully(
    "chown #{LIVE_USER}:#{LIVE_USER} '#{@veracrypt_shared_dir_in_guest}/#{$veracrypt_volume_name}'"
  )
end

When /^I unlock and mount this VeraCrypt (volume|file container) with Unlock VeraCrypt Volumes$/ do |support|
  step 'I start "Unlock VeraCrypt Volumes" via GNOME Activities Overview'
  case support
  when 'volume'
    @screen.wait_and_click('Gtk3UnlockButton.png', 10)
  when 'file container'
    @screen.wait_and_click('UnlockVeraCryptVolumesAddButton.png', 10)
    @screen.wait('Gtk3FileChooserDesktopButton.png', 10)
    @screen.type(@veracrypt_shared_dir_in_guest + '/' + $veracrypt_volume_name + Sikuli::Key.ENTER)
  end
  @screen.wait('VeraCryptUnlockDialog.png', 10)
  @screen.type(
    @veracrypt_is_hidden ? $veracrypt_hidden_passphrase : $veracrypt_passphrase
  )
  @screen.click('VeraCryptUnlockDialogHiddenVolumeLabel.png') if @veracrypt_is_hidden
  @screen.type(Sikuli::Key.ENTER)
  @screen.waitVanish('VeraCryptUnlockDialog.png', 10)
  try_for(30) do
      $vm.execute_successfully('ls /media/amnesia/*/SecretFile')
  end
end

When /^I unlock and mount this VeraCrypt (volume|file container) with GNOME Disks$/ do |support|
  step 'I start "Disks" via GNOME Activities Overview'
  disks = Dogtail::Application.new('gnome-disks')
  case support
  when 'volume'
    disks.children(roleName: 'table cell').find { |row|
      /^105 MB Drive/.match(row.name)
    }.grabFocus
  when 'file container'
    gnome_shell = Dogtail::Application.new('gnome-shell')
    menu = gnome_shell.menu('Disks')
    menu.click()
    @screen.wait_and_click('GnomeDisksAttachDiskImageMenuEntry.png', 10)
    # Once we use a more recent Dogtail that can deal with UTF-8 (#12185),
    # we can instead do:
    #   gnome_shell.child('Attach Disk Image…', roleName: 'label').click
    # Otherwise Disks is sometimes minimized, for some reason I don't understand
    sleep 2
    attach_dialog = disks.child('Select Disk Image to Attach', roleName: 'file chooser', showingOnly: true)
    attach_dialog.child('Set up read-only loop device', roleName: 'check box').click
    filter = attach_dialog.child('Disk Images (*.img, *.iso)', roleName: 'combo box')
    filter.click
    try_for(5) do
      begin
        filter.child('All Files', roleName: 'menu item').click
        true
      rescue RuntimeError
        # we probably clicked too early, which triggered an "Attempting
        # to generate a mouse event at negative coordinates" Dogtail error
        false
      end
    end
    @screen.type(@veracrypt_shared_dir_in_guest + '/' + $veracrypt_volume_name)
    sleep 2 # avoid ENTER being eaten by the auto-completion system
    @screen.type(Sikuli::Key.ENTER)
    try_for(15) do
      begin
        disks.children(roleName: 'table cell').find { |row|
          /^105 MB Loop Device/.match(row.name)
        }.grabFocus
        true
      rescue NoMethodError
        false
      end
    end
  end
  disks.child('', roleName: 'panel', description: 'Unlock selected encrypted partition').click
  unlock_dialog = disks.dialog('Set options to unlock')
  passphrase_field = unlock_dialog.child('', roleName: 'password text')
  passphrase_field.grabFocus()
  passphrase_field.typeText(
    @veracrypt_is_hidden ? $veracrypt_hidden_passphrase : $veracrypt_passphrase
  )
  if @veracrypt_needs_keyfile
    # not accessible and unreachable with the keyboard (#15952)
    @screen.click('GnomeDisksUnlockDialogKeyfileComboBox.png')
    @screen.wait('Gtk3FileChooserDesktopButton.png', 10)
    $vm.file_overwrite('/tmp/keyfile', 'asdf')
    @screen.type('/tmp/keyfile' + Sikuli::Key.ENTER)
    @screen.waitVanish('Gtk3FileChooserDesktopButton.png', 10)
  end
  @screen.wait_and_click('GnomeDisksUnlockDialogHiddenVolumeLabel.png', 10) if @veracrypt_is_hidden
  # Clicking is robust neither with Dogtail (no visible effect) nor with Sikuli
  # (that sometimes clicks just a little bit outside of the button)
  @screen.wait('Gtk3UnlockButton.png', 10)
  @screen.type('u', Sikuli::KeyModifier.ALT) # "Unlock" button
  try_for(10, :msg => "Failed to mount the unlocked volume") do
    begin
      unlocked_volume = disks.child('105 MB VeraCrypt/TrueCrypt', roleName: 'panel', showingOnly: true)
      unlocked_volume.click
      # Move the focus down to the "Filesystem\n107 MB FAT" item (that Dogtail
      # is not able to find) using the 'Down' arrow, in order to display
      # the "Mount selected partition" button.
      unlocked_volume.grabFocus()
      sleep 0.5 # otherwise the following key press is sometimes lost
      disks.pressKey('Down')
      disks.child('', roleName: 'panel', description: 'Mount selected partition', showingOnly: true).click
      true
    rescue RuntimeError
      # we probably did something too early, which triggered a Dogtail error
      # such as "Attempting to generate a mouse event at negative coordinates"
      false
    end
  end
  try_for(10, :msg => "/media/amnesia/*/SecretFile does not exist") do
    $vm.execute_successfully('ls /media/amnesia/*/SecretFile')
  end
end

When /^I open this VeraCrypt volume in GNOME Files$/ do
  $vm.spawn('nautilus /media/amnesia/*', user: LIVE_USER)
  Dogtail::Application.new('nautilus').window(
    veracrypt_volume_size_in_GNOME(@veracrypt_is_hidden) + ' Volume'
  )
end

When /^I lock the currently opened VeraCrypt (volume|file container)$/ do |support|
  $vm.execute_successfully(
    'udisksctl unmount --block-device /dev/mapper/tcrypt-*',
    :user => LIVE_USER
  )
  device = support == 'volume' ? '/dev/sda' : '/dev/loop1'
  $vm.execute_successfully(
    "udisksctl lock --block-device #{device}",
    :user => LIVE_USER
  )
end

Then /^the VeraCrypt (volume|file container) has been unmounted and locked$/ do |support|
  assert(! $vm.execute('ls /media/amnesia/*/SecretFile').success?)
  assert(! $vm.execute('ls /dev/mapper/tcrypt-*').success?)
end
