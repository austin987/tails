Given /^a freshly started Tails$/ do
  @vm.start
  @screen.wait('WelcometoTai-1.png', 500)
end

Given /^the network traffic is sniffed$/ do
  @sniffer = Sniffer.new("TestSniffer", @vm.net.bridge_name, @vm.ip)
  @sniffer.capture
end

When /^I log in a new session$/ do
  @screen.click('Logln.png')
end

Then /^I should see YourbrowserT\.png$/ do
  @screen.wait('YourbrowserT.png', 300)
end

Then /^the network traffic should flow only through Tor$/ do
  @sniffer.stop
  puts "Got #{@sniffer.packets.count} packets"
end
