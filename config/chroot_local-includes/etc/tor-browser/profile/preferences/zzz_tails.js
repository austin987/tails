// As suggested in TBB's start-tor-browser script for system-wide Tor
// instances
pref("extensions.torbutton.banned_ports", "9150,9051");
pref("extensions.torbutton.custom.socks_host", "127.0.0.1");
pref("extensions.torbutton.custom.socks_port", 9150);
pref("extensions.torbutton.launch_warning",  false);
pref("extensions.torbutton.loglevel", 2);
pref("extensions.torbutton.logmethod", 0);
pref("extensions.torbutton.settings_method", "custom");
pref("extensions.torbutton.socks_port", 9150);
pref("extensions.torbutton.use_privoxy", false);

// Also suggested, but probably not needed given Tails uses its own
// Tor Launcher
pref("extensions.torlauncher.control_port", 9051);
pref("extensions.torlauncher.loglevel", 2);
pref("extensions.torlauncher.logmethod", 0);
pref("extensions.torlauncher.prompt_at_startup", false);
pref("extensions.torlauncher.start_tor", false);

// Tails-specific configuartion below

// Adblock Plus preferences
pref("extensions.adblockplus.correctTypos", false);
pref("extensions.adblockplus.currentVersion", "2.1");
pref("extensions.adblockplus.savestats", false);
pref("extensions.adblockplus.showinaddonbar", false);
pref("extensions.adblockplus.showintoolbar", false);
pref("extensions.adblockplus.subscriptions_autoupdate", false);

// FoxyProxy preferences
pref("extensions.foxyproxy.last-version", "99999.99");
pref("extensions.foxyproxy.socks_remote_dns", true);

// Suppress prompt and always spoof useragent as English
pref("extensions.torbutton.spoof_english", true);
pref("extensions.torbutton.prompted_language", true);

// Block read and write access to the history in non-Tor mode
pref("extensions.torbutton.block_nthread", true);
pref("extensions.torbutton.block_nthwrite", true);

// Tails-specific Torbutton preferences
pref("extensions.torbutton.block_tforms", false);
pref("extensions.torbutton.display_panel", false);
pref("extensions.torbutton.lastUpdateCheck", "9999999999.999");
pref("extensions.torbutton.no_updates", true);
pref("extensions.torbutton.nonontor_sessionstore", true);
pref("extensions.torbutton.nontor_memory_jar", true);
pref("extensions.torbutton.startup", true);
pref("extensions.torbutton.startup_state", 1);
pref("extensions.torbutton.test_enabled", false); // Tails-specific
pref("extensions.torbutton.tor_memory_jar", true);

// These must be set to the same value to prevent Torbutton from
// flashing its upgrade notification.
pref("extensions.torbutton.lastBrowserVersion", "Tails");
pref("torbrowser.version", "Tails");

// Quoting TBB: "Now handled by plugins.click_to_play"
// Tails: we don't support these plugins, so letting NoScript block it seems
// to be potentially useful defense-in-depth.
pref("noscript.forbidFlash", true);
pref("noscript.forbidSilverlight", true);
pref("noscript.forbidJava", true);
pref("noscript.forbidPlugins", true);

// Other non-Torbutton, Tails-specific prefs
pref("browser.download.manager.closeWhenDone", true);
pref("extensions.update.enabled", false);
pref("layout.spellcheckDefault", 0);
pref("network.dns.disableIPv6", true);
pref("security.warn_submit_insecure", true);
pref("network.proxy.no_proxies_on", "10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16");
