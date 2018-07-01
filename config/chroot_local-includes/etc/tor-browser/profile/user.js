// As suggested in TBB's start-tor-browser script for system-wide Tor
// instances
user_pref("network.security.ports.banned", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9062,9150,9051");
user_pref("extensions.torbutton.launch_warning",  false);

// Tails-specific configuration below

// Since the slider notification will be shown everytime at each Tails
// boot, which is bad (nagging) UX, we disable it.
user_pref("extensions.torbutton.show_slider_notification", false);

// Disable the Tor Browser's automatic update checking
user_pref("app.update.enabled", false);

// Suppress prompt and always spoof useragent as English
user_pref("extensions.torbutton.spoof_english", true);
user_pref("extensions.torbutton.prompted_language", true);

// Tails-specific Torbutton preferences
user_pref("extensions.torbutton.lastUpdateCheck", "9999999999.999");
user_pref("extensions.torbutton.startup", true);
user_pref("extensions.torbutton.startup_state", 1);
user_pref("extensions.torbutton.test_enabled", false); // Tails-specific
user_pref("extensions.torbutton.control_port", 9051);

// Not setting this prevents some add-on GUI elements from appearing
// on the first run of the browser, e.g. uBlock Origin's button.
user_pref("extensions.torbutton.inserted_button", true);

// These must be set to the same value to prevent Torbutton from
// flashing its upgrade notification.
user_pref("extensions.torbutton.lastBrowserVersion", "Tails");
user_pref("torbrowser.version", "Tails");

// Other Tails-specific NoScript preferences
user_pref("noscript.untrusted", "google-analytics.com");

// Other non-Torbutton, Tails-specific prefs
user_pref("browser.download.dir", "/home/amnesia/Tor Browser");
user_pref("dom.input.fallbackUploadDir", "/home/amnesia/Tor Browser");
user_pref("print.print_to_filename", "/home/amnesia/Tor Browser/output.pdf");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.manager.closeWhenDone", true);
user_pref("extensions.update.enabled", false);
user_pref("layout.spellcheckDefault", 0);
user_pref("network.dns.disableIPv6", true);
user_pref("security.warn_submit_insecure", true);

// Without setting this, the Download Management page will not update
// the progress being made.
user_pref("browser.download.panel.shown", true);

// Given our AppArmor sandboxing, Tor Browser will not be allowed to
// open external applications, so let's not offer the option to the user,
// and instead only propose them to save downloaded files.
user_pref("browser.download.forbid_open_with", true);
