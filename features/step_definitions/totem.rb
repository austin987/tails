require 'resolv'
require 'uri'

Given /^I create sample videos$/ do
  @video_dir_on_host = "#{$config["TMPDIR"]}/video_dir"
  FileUtils.mkdir_p(@video_dir_on_host)
  add_after_scenario_hook { FileUtils.rm_r(@video_dir_on_host) }
  fatal_system("avconv -loop 1 -t 30 -f image2 " +
               "-i 'features/images/USBTailsLogo.png' " +
               "-an -vcodec libx264 -y " +
               '-filter:v "crop=in_w-mod(in_w\,2):in_h-mod(in_h\,2)" ' +
               "'#{@video_dir_on_host}/video.mp4' >/dev/null 2>&1")
end

Given /^I plug and mount a USB drive containing sample videos$/ do
  @video_dir_on_guest = share_host_files(
    Dir.glob("#{@video_dir_on_host}/*")
  )
end

Given /^I copy the sample videos to "([^"]+)" as user "([^"]+)"$/ do |destination, user|
  for video_on_host in Dir.glob("#{@video_dir_on_host}/*.mp4") do
    video_name = File.basename(video_on_host)
    src_on_guest = "#{@video_dir_on_guest}/#{video_name}"
    dst_on_guest = "#{destination}/#{video_name}"
    step "I copy \"#{src_on_guest}\" to \"#{dst_on_guest}\" as user \"amnesia\""
  end
end

When /^I(?:| try to) open "([^"]+)" with Totem$/ do |filename|
  step "I run \"totem #{filename}\" in GNOME Terminal"
end

When /^I close Totem$/ do
  step 'I kill the process "totem"'
end

def disable_tor_reject_internal_addresses
  client_torrc_lines = [
    'ClientDNSRejectInternalAddresses 0',
    'ClientRejectInternalAddresses 0',
  ]
  $vm.file_append('/etc/tor/torrc', client_torrc_lines)
  $vm.execute("systemctl stop tor@default.service")
  $vm.execute("systemctl --no-block restart tails-tor-has-bootstrapped.target")
  $vm.execute("systemctl start tor@default.service")
  wait_until_tor_is_working
end

Then /^I can watch a WebM video over HTTPs$/ do
  test_url = WEBM_VIDEO_URL
  host = URI(test_url).host

  # These tricks are needed because on Jenkins, tails.boum.org
  # resolves to a RFC 1918 address (#10442), which tor would not allow
  # connecting to, and the firewall leak checker would make a fuss
  # out of it.
  resolver = Resolv::DNS.new
  rfc1918_ips = resolver.getaddresses(host).select do |addr|
    # This crude "is it a RFC 1918 IP address?" check is just accurate enough
    # for our current needs. We'll improve it if/as needed.
    addr.class == Resolv::IPv4 && addr.to_s.start_with?('192.168.')
  end
  if rfc1918_ips.count > 0
    disable_tor_reject_internal_addresses
  end
  rfc1918_ips.each do |ip|
    add_extra_allowed_host(ip.to_s, 443)
  end

  recovery_on_failure = Proc.new do
    step 'I close Totem'
  end
  retry_tor(recovery_on_failure) do
    step "I open \"#{test_url}\" with Totem"
    @screen.wait("SampleRemoteWebMVideoFrame.png", 120)
  end
end
