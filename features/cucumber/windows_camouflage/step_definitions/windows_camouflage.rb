Given /^I enable Microsoft Windows XP camouflage$/ do
  @theme = "winxp"
  next if @skip_steps_while_restoring_background
  @screen.wait("TailsGreeterWinXPCamouflage.png", 10)
  @screen.click("TailsGreeterWinXPCamouflage.png")
end

When /^I click the start menu$/ do
  @screen.click("WinXPStartButton.png")
end
