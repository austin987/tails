// This is the Debian specific preferences file for Iceweasel
// You can make any change in here, it is the purpose of this file.
// You can, with this file and all files present in the
// /etc/iceweasel/pref directory, override any preference that is
// present in /usr/lib/iceweasel/defaults/preferences directory.
// While your changes will be kept on upgrade if you modify files in
// /etc/iceweasel/pref, please note that they won't be kept if you
// do make your changes in /usr/lib/iceweasel/defaults/preferences.
//
// Note that lockPref is allowed in these preferences files if you
// don't want users to be able to override some preferences.

// Use LANG environment variable to choose locale
pref("intl.locale.matchOS", true);

// Disable browser auto updaters and associated homepage notifications
pref("app.update.auto", false);
pref("app.update.disable_button.showUpdateHistory", false);
pref("app.update.enabled", false);

// Disk activity: Disable Browsing History Storage
pref("browser.privatebrowsing.autostart", true);
pref("browser.cache.disk.enable", false);
pref("browser.cache.offline.enable", false);
pref("permissions.memory_only", true);
pref("network.cookie.lifetimePolicy", 2);
pref("browser.download.manager.retention", 0);

// Disk activity: TBB Directory Isolation
pref("browser.download.useDownloadDir", false);
pref("browser.shell.checkDefaultBrowser", false);

// Misc privacy: Disk
pref("signon.rememberSignons", false);
pref("browser.formfill.enable", false);
pref("signon.autofillForms", false);
pref("browser.sessionstore.privacy_level", 2);

// Misc privacy: Remote
pref("browser.send_pings", false);
pref("geo.enabled", false);
pref("geo.wifi.uri", "");
pref("browser.search.suggest.enabled", false);
pref("browser.safebrowsing.enabled", false);
pref("browser.safebrowsing.malware.enabled", false);

// Fingerprinting
pref("browser.display.max_font_attempts", 10);
pref("browser.display.max_font_count", 5);
pref("gfx.downloadable_fonts.fallback_delay", -1);
pref("general.appname.override", "Netscape");
pref("general.appversion.override", "5.0 (Windows)");
pref("general.buildID.override", "0");
pref("general.useragent.locale", "en-US");
pref("general.oscpu.override", "Windows NT 6.1");
pref("general.platform.override", "Win32");
pref("general.productSub.override", "20100101");
pref("general.useragent.override", "Mozilla/5.0 (Windows NT 6.1; rv:17.0) Gecko/20100101 Firefox/17.0");
pref("general.useragent.vendor", "");
pref("general.useragent.vendorSub", "");
pref("dom.enable_performance", false);
pref("plugin.expose_full_path", false);
pref("browser.startup.homepage_override.buildID", "20110325121920");
pref("browser.startup.homepage_override.mstone", "rv:2.0");
pref("browser.zoom.siteSpecific", false);

// Third party stuff
pref("network.cookie.cookieBehavior", 1);
pref("security.enable_tls_session_tickets", false);
pref("network.http.spdy.enabled", false);
pref("network.http.spdy.enabled.v2", false); // Seems redundant, but just in case
pref("network.http.spdy.enabled.v3", false); // Seems redundant, but just in case

// Proxy and proxy security
pref("network.security.ports.banned", "8118,8123,9050,9051,9061,9062,9063");
pref("network.dns.disablePrefetch", true);
pref("network.protocol-handler.external-default", false);
pref("network.protocol-handler.external.mailto", false);
pref("network.protocol-handler.external.news", false);
pref("network.protocol-handler.external.nntp", false);
pref("network.protocol-handler.external.snews", false)

// Extension support
pref("xpinstall.whitelist.add", "");
pref("xpinstall.whitelist.add.103", "");

// Unsorted prefs
pref("browser.bookmarks.livemark_refresh_seconds", 31536000);
pref("browser.chrome.site_icons", false);
pref("browser.history_expire_days", 0);
pref("browser.history_expire_days.mirror", 0);
pref("browser.microsummary.updateGenerators", false);
pref("browser.safebrowsing.remoteLookups", false);
pref("browser.sessionstore.enabled", false);
pref("extensions.shownSelectionUI", true);
pref("extensions.update.autoUpdateDefault", false);
pref("extensions.update.notifyUser", false);
pref("network.cookie.prefsMigrated", true);
pref("pref.privacy.disable_button.cookie_exceptions", false);
pref("pref.privacy.disable_button.view_cookies", false);
pref("pref.privacy.disable_button.view_passwords", false);
pref("privacy.item.offlineApps", true);
pref("privacy.item.passwords", true);
pref("privacy.sanitize.didShutdownSanitize", true);
pref("privacy.sanitize.promptOnSanitize", false);
pref("security.disable_button.openCertManager", false);
pref("security.enable_java", false);
pref("security.enable_ssl2", false);
pref("security.enable_ssl3", true);
pref("security.enable_tls", true);
pref("signon.prefillForms", false);
pref("spellchecker.dictionary", "en_US");
