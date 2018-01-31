// As suggested in TBB's start-tor-browser script for system-wide Tor
// instances
pref("extensions.torbutton.banned_ports", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9062,9150,9051");
pref("extensions.torbutton.custom.socks_host", "127.0.0.1");
pref("extensions.torbutton.custom.socks_port", 9150);
pref("extensions.torbutton.launch_warning",  false);
pref("extensions.torbutton.settings_method", "custom");
pref("extensions.torbutton.socks_port", 9150);
pref("extensions.torbutton.use_privoxy", false);

// Tails-specific configuration below

// Since the slider notification will be shown everytime at each Tails
// boot, which is bad (nagging) UX, we disable it.
pref("extensions.torbutton.show_slider_notification", false);

// Disable the Tor Browser's automatic update checking
pref("app.update.enabled", false);

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
pref("extensions.torbutton.control_port", 9051);

// Not setting this prevents some add-on GUI elements from appearing
// on the first run of the browser, e.g. uBlock Origin's button.
pref("extensions.torbutton.inserted_button", true);

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
pref("browser.download.dir", "/home/amnesia/Tor Browser");
pref("dom.input.fallbackUploadDir", "/home/amnesia/Tor Browser");
pref("print.print_to_filename", "/home/amnesia/Tor Browser/output.pdf");
pref("browser.download.folderList", 2);
pref("browser.download.manager.closeWhenDone", true);
pref("extensions.update.enabled", false);
pref("layout.spellcheckDefault", 0);
pref("network.dns.disableIPv6", true);
pref("security.warn_submit_insecure", true);

// Disable fetching of the new tab page's Tiles links/ads. Ads are
// generally unwanted, and also the fetching is a "phone home" type of
// feature that generates traffic at least the first time the browser
// is started.
pref("browser.newtabpage.directory.source", "");
pref("browser.newtabpage.directory.ping", "");
// ... and disable the explanation shown the first time
pref("browser.newtabpage.introShown", true);

// Don't use geographically specific search prefs, like
// browser.search.*.US for US locales. Our generated localization
// profiles localizes search-engines in an incompatible but equivalent
// way.
pref("browser.search.geoSpecificDefaults", false);

// Without setting this, the Download Management page will not update
// the progress being made.
pref("browser.download.panel.shown", true);

// Given our AppArmor sandboxing, Tor Browser will not be allowed to
// open external applications, so let's not offer the option to the user,
// and instead only propose them to save downloaded files.
pref("browser.download.forbid_open_with", true);
