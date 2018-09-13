require 'expect'
require 'pty'
require 'tempfile'

$veracrypt_passphrase = 'asdf'
$veracrypt_hidden_passphrase = 'fdsa'

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
  step "I temporarily create a 100 MiB raw disk named \"veracrypt\""
  disk_path = $vm.storage.disk_path('veracrypt')
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
  step 'I plug USB drive "veracrypt"'
end

When /^I plug and mount a USB drive containing a (.+) VeraCrypt file container( with a keyfile)?$/ do |type, with_keyfile|
  create_veracrypt_volume(type, with_keyfile)
  @veracrypt_shared_dir_in_guest = share_host_files($vm.storage.disk_path('veracrypt'))
  $vm.execute_successfully(
    "chown #{LIVE_USER}:#{LIVE_USER} '#{@veracrypt_shared_dir_in_guest}/veracrypt'"
  )
end

When /^I unlock and mount this VeraCrypt (volume|file container) with Unlock VeraCrypt Volumes$/ do |support|
  @veracrypt_tool = 'Unlock VeraCrypt Volumes'
  step 'I start "Unlock VeraCrypt Volumes" via GNOME Activities Overview'
  case support
  when 'volume'
    @screen.wait_and_click('UnlockVeraCryptVolumesUnlockButton.png', 10)
  when 'file container'
    @screen.wait_and_click('UnlockVeraCryptVolumesAddButton.png', 10)
    @screen.wait('Gtk3FileChooserDesktopButton.png', 10)
    @screen.type(@veracrypt_shared_dir_in_guest + '/veracrypt' + Sikuli::Key.ENTER)
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
  @veracrypt_tool = 'GNOME Disks'
  pending # express the regexp above with the code you wish you had
end

When /^I open this VeraCrypt volume in GNOME Files$/ do
  case @veracrypt_tool
  when 'Unlock VeraCrypt Volumes'
    # XXX: isn't this supposed to happen automatically? (#15951)
    $vm.spawn('nautilus /media/amnesia/*', user: LIVE_USER)
  when 'GNOME Disks'
    pending
  else
    raise "Unsupported tool: '#{@veracrypt_tool}'"
  end
  Dogtail::Application.new('nautilus').window(
    veracrypt_volume_size_in_GNOME(@veracrypt_is_hidden) + ' Volume'
  )
end

When /^I lock the currently opened VeraCrypt (?:volume|file container)$/ do
  # notifications sometimes interfere with mouse focus
  step "all notifications have disappeared"
  @screen.click('NautilusFocusedEjectButton.png')
  try_for(10) do
    ! $vm.execute('ls /media/amnesia/*/SecretFile').success?
  end
end

Then /^I am told the VeraCrypt (volume|file container) has been unmounted$/ do |support|
  case support
  when 'volume'
    notification_text = "You can now unplug QEMU QEMU HARDDISK"
  when 'file container'
    volume_name = "#{veracrypt_volume_size_in_GNOME(@veracrypt_is_hidden)} Volume"
    notification_text = "#{volume_name} has been unmounted"
  end
  step "I see the \"#{notification_text}\"" \
       + " notification after at most 30 seconds"
end
