# coding: utf-8
When /^I see and accept the Unsafe Browser start verification(?:| in the "([^"]+)" locale)$/ do |locale|
  @screen.wait('GnomeQuestionDialogIcon.png', 30)
  @screen.type(Sikuli::Key.TAB + Sikuli::Key.ENTER)
end

def supported_torbrowser_languages
  localization_descriptions = "#{Dir.pwd}/config/chroot_local-includes/usr/share/tails/browser-localization/descriptions"
  File.read(localization_descriptions).split("\n").map do |line|
    # The line will be of the form "xx:YY:..." or "xx-YY:YY:..."
    first, second = line.sub('-', '_').split(':')
    candidates = ["#{first}_#{second}.UTF-8", "#{first}_#{second}.utf8",
                  "#{first}.UTF-8", "#{first}.utf8",
                  "#{first}_#{second}", first]
    when_not_found = Proc.new { raise "Could not find a locale for '#{line}'" }
    candidates.find(when_not_found) do |candidate|
      $vm.directory_exist?("/usr/lib/locale/#{candidate}")
    end
  end
end

Then /^I start the Unsafe Browser in the "([^"]+)" locale$/ do |loc|
  step "I run \"LANG=#{loc} LC_ALL=#{loc} sudo unsafe-browser\" in GNOME Terminal"
  step "I see and accept the Unsafe Browser start verification in the \"#{loc}\" locale"
end

Then /^the Unsafe Browser works in all supported languages$/ do
  failed = Array.new
  supported_torbrowser_languages.sample(3).each do |lang|
    step "I start the Unsafe Browser in the \"#{lang}\" locale"
    begin
      step "the Unsafe Browser has started in the \"#{lang}\" locale"
    rescue RuntimeError
      failed << lang
      next
    end
    step "I close the Unsafe Browser"
    step "the Unsafe Browser chroot is torn down"
  end
  assert(failed.empty?, "Unsafe Browser failed to launch in the following locale(s): #{failed.join(', ')}")
end

Then /^the Unsafe Browser has no add-ons installed$/ do
  step "I open the address \"about:addons\" in the Unsafe Browser"
  step "I see \"UnsafeBrowserNoAddons.png\" after at most 30 seconds"
end

Then /^the Unsafe Browser has only Firefox's default bookmarks configured$/ do
  info = xul_application_info("Unsafe Browser")
  # "Show all bookmarks"
  @screen.type("o", Sikuli::KeyModifier.SHIFT + Sikuli::KeyModifier.CTRL)
  @screen.wait_and_click("UnsafeBrowserExportBookmarksButton.png", 20)
  @screen.wait_and_click("UnsafeBrowserExportBookmarksMenuEntry.png", 20)
  @screen.wait("UnsafeBrowserExportBookmarksSavePrompt.png", 20)
  path = "/home/#{info[:user]}/bookmarks"
  @screen.type(path + Sikuli::Key.ENTER)
  chroot_path = "#{info[:chroot]}/#{path}.json"
  try_for(10) { $vm.file_exist?(chroot_path) }
  dump = JSON.load($vm.file_content(chroot_path))

  def check_bookmarks_helper(a)
    mozilla_uris_counter = 0
    a.each do |h|
      h.each_pair do |k, v|
        if k == "children"
          mozilla_uris_counter += check_bookmarks_helper(v)
        elsif k == "uri"
          uri = v
          if uri.match("^https://(?:support|www)\.mozilla\.org/")
            mozilla_uris_counter += 1
          else
            raise "Unexpected Unsafe Browser bookmark for '#{uri}'"
          end
        end
      end
    end
    return mozilla_uris_counter
  end

  mozilla_uris_counter = check_bookmarks_helper(dump["children"])
  assert_equal(5, mozilla_uris_counter,
               "Unexpected number (#{mozilla_uris_counter}) of mozilla " \
               "bookmarks")
  @screen.type(Sikuli::Key.F4, Sikuli::KeyModifier.ALT)
end

Then /^the Unsafe Browser has a red theme$/ do
  @screen.wait("UnsafeBrowserRedTheme.png", 10)
end

Then /^the Unsafe Browser shows a warning as its start page(?: in the "([^"]+)" locale)?$/ do |locale|
  case locale
  # Use localized image for languages that have a translated version
  # of the Unsafe Browser homepage.
  when /\A([a-z]+)/
    if File.exists?("#{SIKULI_IMAGE_PATH}/UnsafeBrowserStartPage.#{$1}.png")
      start_page_image = "UnsafeBrowserStartPage.#{$1}.png"
    else
      start_page_image = "UnsafeBrowserStartPage.png"
    end
  else
    start_page_image = "UnsafeBrowserStartPage.png"
  end
  @screen.wait(start_page_image, 60)
end

Then /^the Unsafe Browser has started(?: in the "([^"]+)" locale)?$/ do |locale|
  if locale
    step "the Unsafe Browser shows a warning as its start page in the \"#{locale}\" locale"
  else
    step "the Unsafe Browser shows a warning as its start page"
  end
end

Then /^I see a warning about another instance already running$/ do
  @screen.wait('UnsafeBrowserWarnAlreadyRunning.png', 10)
end

Then /^I can start the Unsafe Browser again$/ do
  step "I start the Unsafe Browser"
end

When /^I configure the Unsafe Browser to use a local proxy$/ do
  socksport_lines =
    $vm.execute_successfully('grep -w "^SocksPort" /etc/tor/torrc').stdout
  assert(socksport_lines.size >= 4, "We got fewer than four Tor SocksPorts")
  proxy = socksport_lines.scan(/^SocksPort\s([^:]+):(\d+)/).sample
  proxy_host = proxy[0]
  proxy_port = proxy[1]

  debug_log("Configuring the Unsafe Browser to use a Tor SOCKS proxy (host=#{proxy_host}, port=#{proxy_port})")

  prefs = '/usr/share/tails/chroot-browsers/unsafe-browser/prefs.js'
  $vm.file_append(prefs, 'user_pref("network.proxy.type", 1);' + "\n")
  $vm.file_append(prefs, "user_pref(\"network.proxy.socks\", \"#{proxy_host})\";\n")
  $vm.file_append(prefs, "user_pref(\"network.proxy.socks_port\", #{proxy_port});\n")

  lib = '/usr/local/lib/tails-shell-library/chroot-browser.sh'
  $vm.execute_successfully("sed -i -E '/^\s*export TOR_TRANSPROXY=1/d' #{lib}")
end

Then /^the Unsafe Browser complains that no DNS server is configured$/ do
  assert_not_nil(
    Dogtail::Application.new('zenity')
    .child(roleName: 'label')
    .text['No DNS server was obtained']
  )
end

Then /^I configure the Unsafe Browser to check for updates more frequently$/ do
  prefs = '/usr/share/tails/chroot-browsers/unsafe-browser/prefs.js'
  $vm.file_append(prefs, 'pref("app.update.idletime", 1);')
  $vm.file_append(prefs, 'pref("app.update.promptWaitTime", 1);')
  $vm.file_append(prefs, 'pref("app.update.interval", 5);')
end

But /^checking for updates is disabled in the Unsafe Browser's configuration$/ do
  prefs = '/usr/share/tails/chroot-browsers/common/prefs.js'
  assert($vm.file_content(prefs).include?('pref("app.update.enabled", false)'))
end

Then /^the clearnet user has (|not )sent packets out to the Internet$/ do |sent|
  uid = $vm.execute_successfully("id -u clearnet").stdout.chomp.to_i
  pkts = ip4tables_packet_counter_sum(:tables => ['OUTPUT'], :uid => uid)
  case sent
  when ''
    assert(pkts > 0, "Packets have not gone out to the internet.")
  when 'not'
    assert_equal(pkts, 0, "Packets have gone out to the internet.")
  end
end
