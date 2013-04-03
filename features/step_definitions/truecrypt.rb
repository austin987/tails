When /^I start TrueCrypt through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("GnomeApplicationsMenu.png", 10)
  @screen.wait_and_click("GnomeApplicationsAccessories.png", 10)
  @screen.wait_and_click("GnomeApplicationsTrueCrypt.png", 10)
end
