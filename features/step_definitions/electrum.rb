Then /^I start Electrum through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  step "I start \"Electrum\" via the GNOME \"Internet\" applications menu"
end
