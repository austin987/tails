// As suggested in TBB's start-tor-browser script for system-wide Tor
// instances
pref("network.security.ports.banned", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9062,9150,9051");

// Tails-specific configuration below

// Since the slider notification will be shown everytime at each Tails
// boot, which is bad (nagging) UX, we disable it.
pref("extensions.torbutton.show_slider_notification", false);

// Disable the Tor Browser's automatic update checking
pref("app.update.enabled", false);

// Suppress prompt and always spoof useragent as English
pref("privacy.spoof_english", 2);

// Tails-specific Torbutton preferences
pref("extensions.torbutton.lastUpdateCheck", "9999999999.999");
pref("extensions.torbutton.control_port", 9051);

// Skip migration of prefs from Tor Browser 5 or older
pref("extensions.torbutton.pref_fixup_version", 1);

// These must be set to the same value to prevent Torbutton from
// flashing its upgrade notification.
pref("extensions.torbutton.lastBrowserVersion", "Tails");
pref("torbrowser.version", "Tails");

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

// Without setting this, the Download Management page will not update
// the progress being made.
pref("browser.download.panel.shown", true);

// Given our AppArmor sandboxing, Tor Browser will not be allowed to
// open external applications, so let's not offer the option to the user,
// and instead only propose them to save downloaded files.
pref("browser.download.forbid_open_with", true);
