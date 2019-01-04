When /^I(?:| try to) open "([^"]+)" with Evince$/ do |filename|
  step "I run \"evince #{filename}\" in GNOME Terminal"
end

Then /^I can print the current document to "([^"]+)"$/ do |output_file|
  @screen.type("p", Sikuli::KeyModifier.CTRL)
  @screen.wait("EvincePrintDialog.png", 10)
  @screen.wait_and_click("EvincePrintToFile.png", 10)
  @screen.wait_and_click("EvincePrintOutputFileButton.png", 10)
  @screen.wait("Gtk3PrintFileDialog.png", 10)
  # Only the file's basename is selected by double-clicking,
  # so we type only the desired file's basename to replace it
  $vm.set_clipboard(output_file.sub(/[.]pdf$/, ''))
  @screen.type('v', Sikuli::KeyModifier.CTRL)
  @screen.type(Sikuli::Key.ENTER)
  @screen.wait_and_click("Gtk3PrintButton.png", 10)
  try_for(10, :msg => "The document was not printed to #{output_file}") {
    $vm.file_exist?(output_file)
  }
end

When /^I close Evince$/ do
  @screen.type("w", Sikuli::KeyModifier.CTRL)
  step 'process "evince" has stopped running after at most 20 seconds'
end
