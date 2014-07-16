Given /^I enable Microsoft Windows camouflage$/ do
  @theme = "windows"
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("TailsGreeterWindowsCamouflage.png", 10)
end

When /^I click the start menu$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("WindowsStartButton.png", 10)
end
