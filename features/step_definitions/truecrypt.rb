When /^I start TrueCrypt through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "TrueCrypt" via the GNOME "Accessories" applications menu'
end

When /^I deal with the removal warning prompt$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("TrueCryptRemovalWarning.png", 60)
  @screen.type(Sikuli::Key.ENTER)
end
