Given /^I create sample videos$/ do
  @shared_video_dir_on_host = "#{$config["TMPDIR"]}/shared_video_dir"
  @shared_video_dir_on_guest = "/tmp/shared_video_dir"
  FileUtils.mkdir_p(@shared_video_dir_on_host)
  add_after_scenario_hook { FileUtils.rm_r(@shared_video_dir_on_host) }
  fatal_system("avconv -loop 1 -t 30 -f image2 " +
               "-i 'features/images/TailsBootSplash.png' " +
               "-an -vcodec libx264 -y " +
               '-filter:v "crop=in_w-mod(in_w\,2):in_h-mod(in_h\,2)" ' +
               "'#{@shared_video_dir_on_host}/video.mp4' >/dev/null 2>&1")
end

Given /^I setup a filesystem share containing sample videos$/ do
  $vm.add_share(@shared_video_dir_on_host, @shared_video_dir_on_guest)
end

Given /^I copy the sample videos to "([^"]+)" as user "([^"]+)"$/ do |destination, user|
  for video_on_host in Dir.glob("#{@shared_video_dir_on_host}/*.mp4") do
    video_name = File.basename(video_on_host)
    src_on_guest = "#{@shared_video_dir_on_guest}/#{video_name}"
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

Then /^I can watch a WebM video over HTTPs$/ do
  test_url = 'https://tails.boum.org/lib/test_suite/test.webm'
  recovery_on_failure = Proc.new do
    step 'I close Totem'
  end
  retry_tor(recovery_on_failure) do
    step "I open \"#{test_url}\" with Totem"
    @screen.wait("SampleRemoteWebMVideoFrame.png", 120)
  end
end
