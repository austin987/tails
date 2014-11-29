When /^I see and accept the Unsafe Browser start verification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserStartVerification.png", 30)
  @screen.type("l", Sikuli::KeyModifier.ALT)
end

Then /^I see the Unsafe Browser start notification and wait for it to close$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserStartNotification.png", 30)
  @screen.waitVanish("UnsafeBrowserStartNotification.png", 10)
end

Then /^the Unsafe Browser has started$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserHomepage.png", 360)
end

Then /^the Unsafe Browser has a red theme$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserRedTheme.png", 10)
end

Then /^the Unsafe Browser shows a warning as its start page$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait("UnsafeBrowserStartPage.png", 10)
end

When /^I start the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  step 'I start "UnsafeBrowser" via the GNOME "Internet" applications menu'
end

When /^I successfully start the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  step "I start the Unsafe Browser"
  step "I see and accept the Unsafe Browser start verification"
  step "I see the Unsafe Browser start notification and wait for it to close"
  step "the Unsafe Browser has started"
end

Then /^I see a warning about another instance already running$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('UnsafeBrowserWarnAlreadyRunning.png', 10)
end

When /^I close the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  @screen.type("q", Sikuli::KeyModifier.CTRL)
end

Then /^I see the Unsafe Browser stop notification$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait('UnsafeBrowserStopNotification.png', 20)
  @screen.waitVanish('UnsafeBrowserStopNotification.png', 10)
end

Then /^I can start the Unsafe Browser again$/ do
  next if @skip_steps_while_restoring_background
  step "I start the Unsafe Browser"
end

When /^I open a new tab in the Unsafe Browser$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("UnsafeBrowserWindow.png", 10)
  @screen.type("t", Sikuli::KeyModifier.CTRL)
end

When /^I open the address "([^"]*)" in the Unsafe Browser$/ do |address|
  next if @skip_steps_while_restoring_background
  step "I open a new tab in the Unsafe Browser"
  @screen.type("l", Sikuli::KeyModifier.CTRL)
  sleep 0.5
  @screen.type(address + Sikuli::Key.ENTER)
end

Then /^I cannot configure the Unsafe Browser to use any local proxies$/ do
  next if @skip_steps_while_restoring_background
  @screen.wait_and_click("UnsafeBrowserWindow.png", 10)
  # First we open the proxy settings page to prepare it with the
  # correct open tabs for the loop below.
  @screen.click('UnsafeBrowserMenuButton.png')
  @screen.wait_and_click('UnsafeBrowserPreferencesButton.png', 10)
  @screen.wait('UnsafeBrowserPreferencesWindow.png', 10)
  @screen.wait_and_click('UnsafeBrowserAdvancedSettings.png', 10)
  @screen.wait_and_click('UnsafeBrowserNetworkTab.png', 10)
  sleep 0.5
  @screen.type(Sikuli::Key.ESC)
#  @screen.waitVanish('UnsafeBrowserPreferences.png', 10)
  sleep 0.5

  http_proxy  = 'x' # Alt+x is the shortcut to select http proxy
  socks_proxy = 'c' # Alt+c for socks proxy
  no_proxy    = 'y' # Alt+y for no proxy

  # Note: the loop below depends on that http_proxy is done after any
  # other proxy types since it will set "Use this proxy server for all
  # protocols", which will make the other proxy types unselectable.
  proxies = [[socks_proxy, 9050],
             [socks_proxy, 9061],
             [socks_proxy, 9062],
             [socks_proxy, 9150],
             [http_proxy,  8118],
             [no_proxy,       0]]

  proxies.each do |proxy|
    proxy_type = proxy[0]
    proxy_port = proxy[1]

    @screen.hide_cursor

    # Open proxy settings and select manual proxy configuration
    @screen.click('UnsafeBrowserMenuButton.png')
    @screen.wait_and_click('UnsafeBrowserPreferencesButton.png', 10)
    @screen.wait('UnsafeBrowserPreferencesWindow.png', 10)
    @screen.type("e", Sikuli::KeyModifier.ALT)
    @screen.wait('UnsafeBrowserProxySettings.png', 10)
    @screen.type("m", Sikuli::KeyModifier.ALT)

    # Configure the proxy
    @screen.type(proxy_type, Sikuli::KeyModifier.ALT)  # Select correct proxy type
    @screen.type("127.0.0.1" + Sikuli::Key.TAB + "#{proxy_port}") if proxy_type != no_proxy
    # For http proxy we set "Use this proxy server for all protocols"
    @screen.type("s", Sikuli::KeyModifier.ALT) if proxy_type == http_proxy

    # Close settings
    @screen.type(Sikuli::Key.ENTER)
#    @screen.waitVanish('UnsafeBrowserProxySettings.png', 10)
    sleep 0.5
    @screen.type(Sikuli::Key.ESC)
#    @screen.waitVanish('UnsafeBrowserPreferences.png', 10)
    sleep 0.5

    # Test that the proxy settings work as they should
    step "I open the address \"https://check.torproject.org\" in the Unsafe Browser"
    if proxy_type == no_proxy
      @screen.wait('UnsafeBrowserTorCheckFail.png', 60)
    else
      @screen.wait('UnsafeBrowserProxyRefused.png', 60)
    end
  end
end
