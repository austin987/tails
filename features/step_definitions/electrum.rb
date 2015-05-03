Then /^I start Electrum through the GNOME menu$/ do
  next if @skip_steps_while_restoring_background
  step "I start \"Electrum\" via the GNOME \"Internet\" applications menu"
end

When /^a bitcoin wallet is (|not )present$/ do |existing|
  next if @skip_steps_while_restoring_background
  wallet = "/home/#{LIVE_USER}/.electrum/wallets/default_wallet"
  case existing
  when ""
    step "the file \"#{wallet}\" exists after at most 10 seconds"
  when "not "
    step "the file \"#{wallet}\" does not exist"
  else
    raise "Unknown value specified for #{existing}"
  end
end
