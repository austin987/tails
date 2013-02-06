Given /^I log in to a new session with Microsoft Windows XP camouflage$/ do
  @theme = "winxp"
  next if @skip_steps_while_restoring_background
  @screen.wait('TailsGreeter.png', 10)
  @screen.type(" " + Sikuli::KEY_RETURN)
  @screen.wait("TailsGreeterWinXPCamouflage.png", 10)
  @screen.click("TailsGreeterWinXPCamouflage.png")
  @screen.click('TailsGreeterLoginButton.png')
end

When /^I click the start menu$/ do
  @screen.click("WinXPStartButton.png")
end
