def shared_video_dir_on_guest
  "/tmp/shared_video_dir"
end

Given /^I create a sample MP4 video$/ do
  next if @skip_steps_while_restoring_background
  fatal_system("ffmpeg -loop 1 -t 30 -f image2 " +
               "-i 'features/images/TailsBootSplash.png' " +
               "-an -vcodec libx264 -y " +
               "'#{$misc_files_dir}/video.mp4' >/dev/null 2>&1")
end

Given /^I setup a filesystem share containing sample videos$/ do
  next if @skip_steps_while_restoring_background
  @vm.add_share($misc_files_dir, shared_video_dir_on_guest)
end

Given /^I copy the sample videos to "([^"]+)" as user "([^"]+)"$/ do |destination, user|
  next if @skip_steps_while_restoring_background
  for video_on_host in Dir.glob("#{$misc_files_dir}/*.mp4") do
    video_name = File.basename(video_on_host)
    video_on_guest = "/home/#{$live_user}/#{video_name}"
    step "I copy \"#{shared_video_dir_on_guest}/#{video_name}\" to \"#{video_on_guest}\" as user \"amnesia\""
  end
end

When /^I(?:| try to) open "([^"]+)" with Totem$/ do |filename|
  next if @skip_steps_while_restoring_background
  puts @vm.execute("ls -l /home/amnesia").stdout
  step "I run \"totem #{filename}\" in GNOME Terminal"
end
