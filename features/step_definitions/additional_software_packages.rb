When /^I configure additional software packages to install "(.+?)"$/ do |package|
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/live-additional-software.conf',
    package + "\n"
  )
end

When /^I make my current APT sources persistence$/ do
  $vm.execute("install -d -m 755 /live/persistence/TailsData_unlocked/apt-sources.list.d")
  $vm.file_append(
    '/live/persistence/TailsData_unlocked/persistence.conf',
    "/etc/apt/sources.list.d  source=apt-sources.list.d,link\n"
  )
  $vm.file_overwrite(
    '/live/persistence/TailsData_unlocked/apt-sources.list.d/persistent.list',
    $vm.file_content($vm.file_glob('/etc/apt/**/*.list'))
  )
end

Then /^the additional software package installation service is run$/ do
  try_for(300) do
    $vm.file_exist?('/run/live-additional-software/installed')
  end
end
