require 'expect'
require 'pty'
require 'tempfile'

@veracrypt_passphrase = 'asdf'
@veracrypt_hidden_passphrase = 'fdsa'

def create_veracrypt_keyfile(name)
  keyfile = Tempfile.new("#{name}.keyfile", $config["TMPDIR"])
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

Given(/^USB drive "([^"]+)" has a (.+) VeraCrypt volume( with a keyfile)?$/) do |name, type, with_keyfile|
  step "I temporarily create a 100 MiB raw disk named \"#{name}\""
  disk_path = $vm.storage.disk_path(name)
  keyfile = create_veracrypt_keyfile(name)
  fatal_system "losetup -f '#{disk_path}'"
  loop_dev = `losetup -j '#{disk_path}'`.split(':').first
  tcplay_create_cmd = "tcplay --create --device='#{loop_dev}'"
                    + " --weak-keys --insecure-erase"
  tcplay_create_cmd += " --hidden" if type == 'hidden'
  tcplay_create_cmd += " --keyfile='#{keyfile}'" if with_keyfile
  PTY.spawn(tcplay_create_cmd) do |r_f, w_f, pid|
    begin
      w_f.sync = true
      reply_prompt(r_f, w_f, /^Passphrase:\s/, @veracrypt_passphrase)
      reply_prompt(r_f, w_f, /^Repeat passphrase:\s/, @veracrypt_passphrase)
      if type == 'hidden'
        reply_prompt(r_f, w_f, /^Passphrase for hidden volume:\s/,
                     @veracrypt_hidden_passphrase)
        reply_prompt(r_f, w_f, /^Repeat passphrase:\s/,
                     @veracrypt_hidden_passphrase)
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
  tcplay_map_cmd = "tcplay --map='#{name}' --device='#{loop_dev}'"
  tcplay_map_cmd += " --keyfile='#{keyfile}'" if with_keyfile
  PTY.spawn(tcplay_map_cmd) do |r_f, w_f, pid|
    begin
      w_f.sync = true
      reply_prompt(r_f, w_f, /^Passphrase:\s/,
                   type == 'hidden' ? @veracrypt_hidden_passphrase : @veracrypt_passphrase)
      r_f.expect(/^All ok!/)
    rescue Errno::EIO
    ensure
      Process.wait pid
    end
    $?.exitstatus == 0 or raise "#{tcplay_map_cmd} exited with #{$?.exitstatus}"
  end
  fatal_system "mkfs.vfat '/dev/mapper/#{name}' >/dev/null"
  Dir.mktmpdir(name, $config["TMPDIR"]) { |mountpoint|
    fatal_system "mount -t vfat '/dev/mapper/#{name}' '#{mountpoint}'"
    # must match SecretFileOnVeraCryptVolume.png when displayed in GNOME Files
    FileUtils.cp('/usr/share/common-licenses/GPL-3', "#{mountpoint}/SecretFile")
    fatal_system "umount '#{mountpoint}'"
  }
  fatal_system "tcplay --unmap='#{name}'"
  fatal_system "losetup -d '#{loop_dev}'"
  File.delete(keyfile)
end

When(/^I unlock and mount the VeraCrypt volume on drive "([^"]+)" with Unlock VeraCrypt Volumes$/) do |name|
  pending # express the regexp above with the code you wish you had
end

When(/^I unlock and mount the VeraCrypt volume on drive "([^"]+)" with GNOME Disks$/) do |name|
  pending # express the regexp above with the code you wish you had
end

When(/^I open the USB drive "([^"]+)" in GNOME Files$/) do |name|
  pending # express the regexp above with the code you wish you had
end

When(/^I lock USB drive "([^"]+)"$/) do |name|
  pending # express the regexp above with the code you wish you had
end

Then(/^I am told I can unplug the USB drive$/) do
  pending # express the regexp above with the code you wish you had
end
