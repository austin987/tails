Given /^I enable Microsoft Windows XP camouflage$/ do
  @theme = "winxp"
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("TailsGreeterWinXPCamouflage.png", 10)
end

When /^I click the start menu$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("WinXPStartButton.png", 10)
end
