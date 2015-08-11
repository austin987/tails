Given /^I enable Microsoft Windows camouflage$/ do
  @theme = "windows"
  @screen.wait_and_click("TailsGreeterWindowsCamouflage.png", 10)
end

When /^I click the start menu$/ do
  @screen.wait_and_click("WindowsStartButton.png", 10)
end
