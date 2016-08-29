When /^the "(.+)" notification is sent$/ do |title|
  $vm.execute_successfully("notify-send '#{title}'", user: LIVE_USER)
end

Then /^the "(.+)" notification is shown to the user$/ do |title|
  Dogtail::Application.new('gnome-shell').child(title).wait
end
