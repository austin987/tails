# Sadly Dogtail is not useful here as long as the notification area
# icon is provided for by the TopIcons extension since it doesn't set
# any useful fields (like name) for the accessibility API.
def seahorse_menu_click_helper(main, sub, verify = nil)
  try_for(60) do
    step "process \"#{verify}\" is running" if verify
    @screen.hide_cursor
    @screen.wait_and_click(main, 10)
    @screen.wait_and_click(sub, 10)
    return
  end
end

Given /^I generate an OpenPGP key named "([^"]+)" with password "([^"]+)"$/ do |name, pwd|
  @passphrase = pwd
  key_name = name
  key_comment = 'Blah'
  key_email = "#{key_name}@test.org"
  # This is how gpgApplet will present this key:
  @gpgApplet_key_desc = "#{key_name} (#{key_comment}) <#{key_email}>"
  gpg_key_recipie = <<EOF
     Key-Type: RSA
     Key-Length: 4096
     Subkey-Type: RSA
     Subkey-Length: 4096
     Name-Real: #{key_name}
     Name-Comment: #{key_comment}
     Name-Email: #{key_email}
     Expire-Date: 0
     Passphrase: #{pwd}
     %commit
EOF
  $vm.file_overwrite('/tmp/gpg_key_recipie', gpg_key_recipie, LIVE_USER)
  c = $vm.execute("gpg --batch --gen-key < /tmp/gpg_key_recipie",
                  :user => LIVE_USER)
  assert(c.success?, "Failed to generate OpenPGP key:\n#{c.stderr}")
end

When /^I type a message into gedit$/ do
  step 'I start "gedit" via the GNOME "Accessories" applications menu'
  @message = 'ATTACK AT DAWN'
  @gedit = Dogtail::Application.new('gedit')
  @gedit.child(roleName: 'text').typeText(@message)
end

def maybe_deal_with_pinentry
  begin
    @screen.wait_and_click("PinEntryPrompt.png", 10)
    # Without this sleep here (and reliable visual indicators) we can sometimes
    # miss keystrokes by typing too soon. This sleep prevents this problem from
    # coming up.
    sleep 5
    @screen.type(@passphrase + Sikuli::Key.ENTER)
  rescue FindFailed
    # The passphrase was cached or we wasn't prompted at all (e.g. when
    # only encrypting to a public key)
  end
end

def gedit_copy_all_text
  @gedit.interact do |app|
    app.child(roleName: 'text').click(button: Dogtail::Mouse::RIGHT_CLICK)
    app.menuItem('Select All').click
  end
end

def gedit_paste_into_a_new_tab
  @gedit.interact do |app|
    app.button('New').click()
    app.child(roleName: 'text').click(button: Dogtail::Mouse::RIGHT_CLICK)
    app.menuItem('Paste').click
  end
end

def encrypt_sign_helper(encrypt, sign)
  gedit_copy_all_text
  seahorse_menu_click_helper('GpgAppletIconNormal.png', 'GpgAppletSignEncrypt.png')
  Dogtail::Application.interact('gpgApplet') do |app|
    dialog = app.dialog('Choose keys')
    if encrypt
      dialog.child(roleName: "table").child(@gpgApplet_key_desc).doubleClick
    end
    if sign
      combobox = dialog.child(roleName: 'combo box')
      combobox.click
      combobox.child(@gpgApplet_key_desc, roleName: 'menu item').click
      # Often the cursor stays hovering over an element that opens a
      # pop-up blocking the OK button.
      @screen.hide_cursor
    end
    dialog.button('OK').click
  end
  maybe_deal_with_pinentry
  gedit_paste_into_a_new_tab
end

def decrypt_verify_helper(encrypted, signed)
  gedit_copy_all_text
  if encrypted
    icon = "GpgAppletIconEncrypted.png"
  else
    icon = "GpgAppletIconSigned.png"
  end
  seahorse_menu_click_helper(icon, 'GpgAppletDecryptVerify.png')
  maybe_deal_with_pinentry
  Dogtail::Application.interact('gpgApplet') do |app|
    dialog = app.child('Information', roleName: 'alert')
    stdout_text_area, stderr_text_area = app.children(roleName: 'text')
    # Given some inconsistency in either gpg or gpgApplet, we can get
    # either one or two trailing newlines here.
    stdout = stdout_text_area.get_field('text').chomp.chomp
    assert_equal(@message, stdout,
                 "The expected message could not be found in the GnuPG output")
    stderr = stderr_text_area.get_field('text').chomp.chomp
    if encrypted
      assert(stderr['gpg: encrypted with '], 'Message was not encrypted')
    end
    if signed
      assert(stderr['gpg: Good signature from '], 'Message was not signed')
    end
    dialog.button('OK').click
  end
end

When /^I encrypt the message using my OpenPGP key$/ do
  encrypt_sign_helper(true, false)
end

Then /^I can decrypt the encrypted message$/ do
  decrypt_verify_helper(true, false)
end

When /^I sign the message using my OpenPGP key$/ do
  encrypt_sign_helper(false, true)
end

Then /^I can verify the message's signature$/ do
  decrypt_verify_helper(false, true)
end

When /^I both encrypt and sign the message using my OpenPGP key$/ do
  encrypt_sign_helper(true, true)
end

Then /^I can decrypt and verify the encrypted message$/ do
  decrypt_verify_helper(true, true)
end

When /^I symmetrically encrypt the message with password "([^"]+)"$/ do |pwd|
  @passphrase = pwd
  gedit_copy_all_text
  seahorse_menu_click_helper('GpgAppletIconNormal.png', 'GpgAppletEncryptPassphrase.png')
  maybe_deal_with_pinentry # enter password
  maybe_deal_with_pinentry # confirm password
  gedit_paste_into_a_new_tab
end
