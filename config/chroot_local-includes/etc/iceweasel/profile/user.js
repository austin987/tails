user_pref("capability.policy.maonoscript.javascript.enabled", "allAccess");
user_pref("capability.policy.maonoscript.sites", "about: about:addons about:blank about:certerror about:config about:crashes about:credits about:home about:neterror about:plugins about:privatebrowsing about:sessionrestore chrome: resource:");
user_pref("extensions.adblockplus.correctTypos", false);
user_pref("extensions.adblockplus.currentVersion", "2.1");
user_pref("extensions.adblockplus.savestats", false);
user_pref("extensions.adblockplus.showinaddonbar", false);
user_pref("extensions.adblockplus.showintoolbar", false);
user_pref("extensions.adblockplus.subscriptions_autoupdate", false);

user_pref("extensions.https_everywhere._observatory.enabled", false);
user_pref("extensions.https_everywhere._observatory.popup_shown", true);

// Block read and write access to the history in non-Tor mode
user_pref("extensions.torbutton.block_nthread", true);
user_pref("extensions.torbutton.block_nthwrite", true);

// Torbutton preferences the TBB also sets.
// We use the same value as the TBB unless noted.
user_pref("extensions.torbutton.fresh_install", false);
user_pref("extensions.torbutton.tor_enabled", true);
user_pref("extensions.torbutton.proxies_applied", true);
user_pref("extensions.torbutton.settings_applied", true);
user_pref("extensions.torbutton.socks_host", "127.0.0.1");
user_pref("extensions.torbutton.socks_port", 9063); // Tails-specific
user_pref("extensions.torbutton.tz_string", "UTC+00:00");

// .saved version of the Torbutton preferences the TBB also sets
user_pref("extensions.torbutton.saved.fresh_install", false);
user_pref("extensions.torbutton.saved.tor_enabled", true);
user_pref("extensions.torbutton.saved.proxies_applied", true);
user_pref("extensions.torbutton.saved.settings_applied", true);
user_pref("extensions.torbutton.saved.socks_host", "127.0.0.1");
user_pref("extensions.torbutton.saved.socks_port", 9063);

// Tails -specific Torbutton preferences
user_pref("extensions.torbutton.block_tforms", false);
user_pref("extensions.torbutton.disable_domstorage", false);
user_pref("extensions.torbutton.display_panel", false);
user_pref("extensions.torbutton.launch_warning", false);
user_pref("extensions.torbutton.no_updates", true);
user_pref("extensions.torbutton.nonontor_sessionstore", true);
user_pref("extensions.torbutton.nontor_memory_jar", true);
user_pref("extensions.torbutton.prompted_language", true);
user_pref("extensions.torbutton.socks_remote_dns", true);
user_pref("extensions.torbutton.socks_version", 5);
user_pref("extensions.torbutton.startup", true);
user_pref("extensions.torbutton.startup_state", 1);
user_pref("extensions.torbutton.tor_memory_jar", true);
user_pref("extensions.torbutton.use_privoxy", false);
user_pref("extensions.torbutton.versioncheck_enabled", false);
user_pref("extensions.torbutton.warned_ff3", true);

// .saved version of the Tails -specific Torbutton preferences
user_pref("extensions.torbutton.saved.socks_remote_dns", true);
user_pref("extensions.torbutton.saved.socks_version", 5);
user_pref("extensions.torbutton.saved.type", 1);

// Proxy and proxy security
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9063);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.type", 1);
user_pref("network.protocol-handler.warn-external.mailto", true);
user_pref("network.protocol-handler.warn-external.news", true);
user_pref("network.protocol-handler.warn-external.nntp", true);
user_pref("network.protocol-handler.warn-external.snews", true);
user_pref("network.protocol-handler.warn-external.file", true);

// Network and performance
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.aggressive", true);
user_pref("network.http.pipelining.maxrequests", 12);
user_pref("network.http.pipelining.ssl", true);
user_pref("network.http.proxy.pipelining", true);
user_pref("security.ssl.enable_false_start", true);
user_pref("network.http.keep-alive.timeout", 20);
user_pref("network.http.connection-retry-timeout", 0);
user_pref("network.http.max-persistent-connections-per-proxy", 256);
user_pref("network.http.pipelining.reschedule-timeout", 15000);
user_pref("network.http.pipelining.read-timeout", 60000);
// Quoting TBB: 'Hacked pref: Now means "Attempt to pipeline at least this many requests together"'
user_pref("network.http.pipelining.max-optimistic-requests", 3);

// Fingerprinting
user_pref("webgl.min_capability_mode", true);
user_pref("webgl.disable-extensions", true);

// Extension support
user_pref("extensions.autoDisableScopes", 0);

// Other non-Torbutton prefs
user_pref("browser.cache.disk.capacity", 0);
user_pref("browser.chrome.favicons", false);
user_pref("browser.chrome.image_icons.max_size", 0);
user_pref("browser.download.manager.closeWhenDone", true);
user_pref("browser.search.update", false);
user_pref("dom.event.contextmenu.enabled", false);
user_pref("extensions.foxyproxy.last-version", "99999.99");
user_pref("extensions.foxyproxy.socks_remote_dns", true);
user_pref("extensions.update.enabled", false);
user_pref("layout.css.report_errors", false);
user_pref("layout.spellcheckDefault", 0);
user_pref("network.dns.disableIPv6", true);
user_pref("network.proxy.failover_timeout", 0);
user_pref("noscript.ABE.enabled", false);
user_pref("noscript.ABE.notify", false);
user_pref("noscript.ABE.wanIpAsLocal", false);
user_pref("noscript.autoReload", false);
user_pref("noscript.confirmUnblock", false);
user_pref("noscript.contentBlocker", true);
user_pref("noscript.default", "about:blank about:credits addons.mozilla.org flashgot.net google.com gstatic.com googlesyndication.com informaction.com yahoo.com yimg.com maone.net noscript.net hotmail.com msn.com passport.com passport.net passportimages.com live.com");
user_pref("noscript.firstRunRedirection", false);
user_pref("noscript.forbidFonts", false);
user_pref("noscript.forbidMedia", false);
user_pref("noscript.forbidWebGL", true);
user_pref("noscript.global", true);
user_pref("noscript.gtemp", "");
user_pref("noscript.opacizeObject", 3);
user_pref("noscript.options.tabSelectedIndexes", "5,0,0");
user_pref("noscript.policynames", "");
user_pref("noscript.secureCookies", true);
user_pref("noscript.showAllowPage", false);
user_pref("noscript.showBaseDomain", false);
user_pref("noscript.showDistrust", false);
user_pref("noscript.showRecentlyBlocked", false);
user_pref("noscript.showRevokeTemp", false);
user_pref("noscript.showTemp", false);
user_pref("noscript.showTempAllowPage", false);
user_pref("noscript.showTempToPerm", false);
user_pref("noscript.showUntrusted", false);
user_pref("noscript.STS.enabled", false);
user_pref("noscript.subscription.lastCheck", -142148139);
user_pref("noscript.temp", "");
user_pref("noscript.untrusted", "google-analytics.com");
user_pref("privacy.item.cookies", true);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("security.xpconnect.plugin.unrestricted", false);
user_pref("security.warn_submit_insecure", true);
user_pref("torbrowser.version", "Tails");
