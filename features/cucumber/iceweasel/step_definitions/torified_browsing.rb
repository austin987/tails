Given /^a freshly started Tails$/ do
  @vm.start
  @screen.wait('WelcometoTai-1.png', 500)
end

When /^I log in a new session$/ do
  @screen.click('Logln.png')
end

Then /^I should see YourbrowserT\.png$/ do
  @screen.wait('YourbrowserT.png', 300)
end
