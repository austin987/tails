When /^I(?:| try to) open "([^"]+)" with Evince$/ do |filename|
  next if @skip_steps_while_restoring_background
  step "I run \"evince #{filename}\" in GNOME Terminal"
end

Then /^I can print the current document to "([^"]+)"$/ do |output_file|
  next if @skip_steps_while_restoring_background
  @screen.type("p", Sikuli::KeyModifier.CTRL)
  @screen.wait("EvincePrintDialog.png", 10)
  @screen.wait_and_click("PrintToFile.png", 10)
  @screen.wait_and_double_click("EvincePrintOutputFile.png", 10)
  @screen.hide_cursor
  @screen.wait("EvincePrintOutputFileSelected.png", 10)
  # Only the file's basename is selected by double-clicking,
  # so we type only the desired file's basename to replace it
  @screen.type(output_file.sub(/[.]pdf$/, '') + Sikuli::Key.ENTER)
  try_for(10, :msg => "The document was not printed to #{output_file}") {
    @vm.file_exist?(output_file)
  }
end
