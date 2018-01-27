When /^I configure additional software packages to install "(.+?)"$/ do |package|
  $vm.execute("echo #{package} > /live/persistence/TailsData_unlocked/live-additional-software.conf")
end

# We have to save the non-onion APT sources in persistence, so that on
# next boot the additional software packages service has the right APT
# indexes to install the package we want.
When /^I add non-onion APT sources to persistence$/ do
  $vm.execute("install -d -m 755 /live/persistence/TailsData_unlocked/apt-sources.list.d")
  $vm.execute("echo '/etc/apt/sources.list.d  source=apt-sources.list.d,link' >> /live/persistence/TailsData_unlocked/persistence.conf")
  $vm.execute("cat /etc/apt/sources.list /etc/apt/sources.list.d/* > /live/persistence/TailsData_unlocked/apt-sources.list.d/non-onion.list")
end

Then /^the additional software package installation service is run$/ do
  try_for(300) {
    $vm.execute("test -e '/run/live-additional-software/installed'").success?
  }
end
