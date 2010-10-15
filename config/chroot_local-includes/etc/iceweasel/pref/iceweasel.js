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

// Disable default browser checking.
pref("browser.shell.checkDefaultBrowser", false);

pref("app.update.auto", false);
pref("app.update.disable_button.showUpdateHistory", false);
pref("app.update.enabled", false);
pref("browser.cache.disk.enable", false);
pref("browser.download.manager.closeWhenDone", true);
pref("browser.download.manager.retention", 0);
pref("browser.history_expire_days", 0);
pref("browser.safebrowsing.enabled", false);
pref("browser.safebrowsing.malware.enabled", false);
pref("browser.safebrowsing.remoteLookups", false);
pref("browser.search.suggest.enabled", false);
pref("browser.search.update", false);
pref("browser.startup.homepage_override.mstone", "ignore");
pref("capability.policy.maonoscript.javascript.enabled", "allAccess");
pref("capability.policy.maonoscript.sites", "https://auk.riseup.net https://mail.riseup.net https://swift.riseup.net https://tern.riseup.net https://webmail.no-log.org about: about:blank about:certerror about:config about:credits about:neterror about:plugins about:privatebrowsing about:sessionrestore chrome: file:// https://webmail.boum.org resource:");
pref("extensions.update.enabled", false);
pref("extensions.update.notifyUser", false);
pref("network.cookie.lifetimePolicy", 2);
pref("network.cookie.prefsMigrated", true);
pref("network.protocol-handler.warn-external.file", true);
pref("network.protocol-handler.warn-external.mailto", true);
pref("network.protocol-handler.warn-external.news", true);
pref("network.protocol-handler.warn-external.nntp", true);
pref("network.protocol-handler.warn-external.snews", true);
pref("network.proxy.http", "localhost");
pref("network.proxy.http_port", 8118);
pref("network.proxy.socks", "127.0.0.1");
pref("network.proxy.socks_port", 9050);
pref("network.proxy.socks_remote_dns", true);
pref("network.proxy.ssl", "localhost");
pref("network.proxy.ssl_port", 8118);
pref("network.proxy.type", 1);
pref("network.security.ports.banned", "8118,8123,9050,9051");
pref("layout.spellcheckDefault", 0);
pref("network.dns.disableIPv6", true);
pref("noscript.httpsForced", "boum.org\nmail.google.com\nmail.riseup.net\nwebmail.no-log.org\nwebmail.boum.org");
pref("noscript.httpsForcedExceptions", "");
pref("noscript.notify.hide", true);
pref("noscript.policynames", "");
pref("noscript.showAddress", true);
pref("noscript.showAllowPage", false);
pref("noscript.showDistrust", true);
pref("noscript.showDomain", true);
pref("noscript.showGlobal", false);
pref("noscript.showPermanent", false);
pref("noscript.showTempToPerm", false);
pref("noscript.showUntrusted", true);
pref("noscript.untrusted", "google-analytics.com google.com file:// http://google-analytics.com http://google.com https://google-analytics.com https://google.com");
pref("pref.privacy.disable_button.cookie_exceptions", false);
pref("pref.privacy.disable_button.view_cookies", false);
pref("pref.privacy.disable_button.view_passwords", false);
pref("privacy.item.cookies", true);
pref("privacy.item.offlineApps", true);
pref("privacy.item.passwords", true);
pref("privacy.sanitize.didShutdownSanitize", true);
pref("privacy.sanitize.promptOnSanitize", false);
pref("privacy.sanitize.sanitizeOnShutdown", true);
pref("security.disable_button.openCertManager", false);
pref("security.enable_java", false);
pref("security.enable_ssl2", false);
pref("security.enable_ssl3", true);
pref("security.enable_tls", true);
pref("security.warn_leaving_secure", true);
pref("security.warn_submit_insecure", true);
pref("signon.prefillForms", false);
pref("signon.rememberSignons", false);
