When /^I(?:| try to) open "([^"]+)" with Evince$/ do |filename|
  step "I run \"evince #{filename}\" in GNOME Terminal"
end

Then /^I can print the current document to "([^"]+)"$/ do |output_file|
  @screen.press('ctrl', 'p')
  @screen.wait('EvincePrintDialog.png', 10)
  @screen.wait('EvincePrintToFile.png', 10).click
  @screen.wait('EvincePrintOutputFileButton.png', 10).click
  @screen.wait('Gtk3PrintFileDialog.png', 10)
  # Only the file's basename is selected by double-clicking,
  # so we type only the desired file's basename to replace it
  $vm.set_clipboard(output_file.sub(/[.]pdf$/, ''))
  @screen.press('ctrl', 'v')
  @screen.press('Return')
  @screen.wait('Gtk3PrintButton.png', 10).click
  try_for(10, msg: "The document was not printed to #{output_file}") do
    $vm.file_exist?(output_file)
  end
end

When /^I close Evince$/ do
  @screen.press('ctrl', 'w')
  step 'process "evince" has stopped running after at most 20 seconds'
end
