// As suggested in TBB's start-tor-browser script for system-wide Tor
// instances
pref("extensions.torbutton.banned_ports", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9061,9062,9150,9052");
pref("extensions.torbutton.custom.socks_host", "127.0.0.1");
pref("extensions.torbutton.custom.socks_port", 9150);
pref("extensions.torbutton.launch_warning",  false);
pref("extensions.torbutton.settings_method", "custom");
pref("extensions.torbutton.socks_port", 9150);
pref("extensions.torbutton.use_privoxy", false);

// Tails-specific configuration below

// Disable the Tor Browser's automatic update checking
pref("app.update.enabled", false);

// Adblock Plus preferences
pref("extensions.adblockplus.correctTypos", false);
pref("extensions.adblockplus.currentVersion", "2.1");
pref("extensions.adblockplus.savestats", false);
pref("extensions.adblockplus.showinaddonbar", false);
pref("extensions.adblockplus.showintoolbar", false);
pref("extensions.adblockplus.subscriptions_autoupdate", false);

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
pref("extensions.torbutton.control_port", 9052);

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

// Other Tails-specific NoScript preferences
pref("noscript.untrusted", "google-analytics.com");

// Other non-Torbutton, Tails-specific prefs
pref("browser.download.manager.closeWhenDone", true);
pref("extensions.update.enabled", false);
pref("layout.spellcheckDefault", 0);
pref("network.dns.disableIPv6", true);
pref("security.warn_submit_insecure", true);
pref("network.proxy.no_proxies_on", "10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16");
