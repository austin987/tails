Given /^I generate an OpenPGP key named "([^"]+)" with password "([^"]+)"$/ do |name, pwd|
  @passphrase = pwd
  @key_name = name
  next if @skip_steps_while_restoring_background
  gpg_key_recipie = <<EOF
     Key-Type: RSA
     Key-Length: 4096
     Subkey-Type: RSA
     Subkey-Length: 4096
     Name-Real: #{@key_name}
     Name-Comment: Blah
     Name-Email: #{@key_name}@test.org
     Expire-Date: 0
     Passphrase: #{pwd}
     %commit
EOF
  gpg_key_recipie.split("\n").each do |line|
    @vm.execute("echo '#{line}' >> /tmp/gpg_key_recipie", $live_user)
  end
  c = @vm.execute("gpg --batch --gen-key < /tmp/gpg_key_recipie", $live_user)
  assert(c.success?, "Failed to generate OpenPGP key:\n#{c.stderr}")
end

When /^I type a message into gedit$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "Gedit" via the GNOME "Accessories" applications menu'
  @screen.wait_and_click("GeditWindow.png", 10)
  sleep 0.5
  @screen.type("ATTACK AT DAWN")
end

def maybe_deal_with_pinentry
  begin
    @screen.wait_and_click("PinEntryPrompt.png", 3)
    sleep 1
    @screen.type(@passphrase + Sikuli::Key.ENTER)
  rescue FindFailed
    # The passphrase was cached or we wasn't prompted at all (e.g. when
    # only encrypting to a public key)
  end
end

def paste_into_a_new_tab
  @screen.click("GeditNewDocument.png")
  @screen.click("GeditPaste.png")
end

def encrypt_sign_helper
  gedit_copy_all_text
  @screen.click("GpgAppletIconNormal.png")
  @screen.wait_and_click("GpgAppletSignEncrypt.png", 10)
  @screen.wait_and_click("GpgAppletChooseKeyWindow.png", 30)
  sleep 0.5
  yield
  maybe_deal_with_pinentry
  paste_into_a_new_tab
end

def gedit_copy_all_text
  @screen.click("GeditEdit.png")
  @screen.wait_and_click("GeditSelectAll.png", 10)
  @screen.click("GeditCopy.png")
end

def decrypt_verify_helper(icon)
  gedit_copy_all_text
  @screen.click(icon)
  @screen.wait_and_click("GpgAppletDecryptVerify.png", 10)
  maybe_deal_with_pinentry
  @screen.wait("GpgAppletResults.png", 10)
  @screen.wait("GpgAppletResultsMsg.png", 10)
end

When /^I encrypt the message using my OpenPGP key$/ do
  next if @skip_steps_while_restoring_background
  encrypt_sign_helper do
    @screen.type(@key_name + Sikuli::Key.ENTER + Sikuli::Key.ENTER)
  end
end

Then /^I can decrypt the encrypted message$/ do
  next if @skip_steps_while_restoring_background
  decrypt_verify_helper("GpgAppletIconEncrypted.png")
  @screen.wait("GpgAppletResultsEncrypted.png", 10)
end

When /^I sign the message using my OpenPGP key$/ do
  next if @skip_steps_while_restoring_background
  encrypt_sign_helper do
    @screen.type(Sikuli::Key.TAB + Sikuli::Key.DOWN + Sikuli::Key.ENTER)
  end
end

Then /^I can verify the message's signature$/ do
  next if @skip_steps_while_restoring_background
  decrypt_verify_helper("GpgAppletIconSigned.png")
  @screen.wait("GpgAppletResultsSigned.png", 10)
end

When /^I both encrypt and sign the message using my OpenPGP key$/ do
  next if @skip_steps_while_restoring_background
  encrypt_sign_helper do
    @screen.type(@key_name + Sikuli::Key.ENTER)
    @screen.type(Sikuli::Key.TAB + Sikuli::Key.DOWN + Sikuli::Key.ENTER)
  end
end

Then /^I can decrypt and verify the encrypted message$/ do
  next if @skip_steps_while_restoring_background
  decrypt_verify_helper("GpgAppletIconEncrypted.png")
  @screen.wait("GpgAppletResultsEncrypted.png", 10)
  @screen.wait("GpgAppletResultsSigned.png", 10)
end

When /^I symmetrically encrypt the message with password "([^"]+)"$/ do |pwd|
  @passphrase = pwd
  next if @skip_steps_while_restoring_background
  gedit_copy_all_text
  @screen.click("GpgAppletIconNormal.png")
  @screen.wait_and_click("GpgAppletEncryptPassphrase.png", 10)
  maybe_deal_with_pinentry # enter password
  maybe_deal_with_pinentry # confirm password
  paste_into_a_new_tab
end
