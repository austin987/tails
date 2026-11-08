// AniTails System Tor Integration Preferences for Official Tor Browser 16.0 (Firefox 153.6.0esr)
// IMPORTANT: Does NOT alter fingerprinting-sensitive canvas/font/screen/WebGL/JS prefs
// from official Tor Browser 16.0 defaults.

pref("network.security.ports.banned", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9051,9052,9062,9065,9150");
pref("extensions.torbutton.control_port", 9051);
pref("extensions.torbutton.socks_host", "127.0.0.1");
pref("extensions.torbutton.socks_port", 9050);
pref("extensions.update.enabled", false);
pref("app.update.auto", false);
pref("browser.download.dir", "/home/amnesia/Tor Browser");
pref("browser.download.folderList", 2);
pref("browser.download.forbid_open_with", true);
pref("network.dns.disableIPv6", true);
// Tor Browser 16.0 privacy enhancement: hide page title from OS window titlebar
pref("privacy.exposeContentTitleInWindow", false);
