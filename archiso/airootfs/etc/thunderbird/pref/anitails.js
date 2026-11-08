// AniTails Hardened Preferences for Thunderbird (Arch Linux thunderbird 158.0.1-1)
pref("extensions.update.enabled", false);
pref("mailnews.database.global.indexer.enabled", false);
pref("mail.chat.enabled", false);
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.rejected", true);
pref("datareporting.healthreport.uploadEnabled", false);

// Force TLS/SSL only during account discovery
pref("mailnews.auto_config.fetchFromISP.sslOnly", true);
pref("mailnews.auto_config.sslOnly", true);
pref("mailnews.auto_config.guess.sslOnly", true);
pref("mailnews.auto_config.fetchFromExchange.enabled", false);
pref("mailnews.auto_config.mx.enabled", false);
pref("mailnews.auto_config.account_constraints.allow_oauth2", false);

// EFAIL & metadata hardening
pref("mailnews.p7m_subparts_external", true);
pref("mail.suppress_content_language", true);
pref("mail.sanitize_date_header", true);
pref("mail.server.default.enableAutocrypt", false);

// Route all traffic + DNS exclusively over system Tor SOCKSPort 127.0.0.1:9050
pref("network.proxy.type", 1);
pref("network.proxy.socks", "127.0.0.1");
pref("network.proxy.socks_port", 9050);
pref("network.proxy.socks_version", 5);
pref("network.proxy.socks_remote_dns", true);
pref("network.dns.disablePrefetch", true);
pref("network.dns.disableIPv6", true);
pref("network.security.ports.banned", "631,6136,4444,4445,6668,7656,7657,7658,7659,7660,8998,9040,9050,9051,9052,9062,9065,9150");

// Allow optional external GnuPG keyring / smartcard integration (tracked under Tails #21841 parity note)
pref("mail.openpgp.allow_external_gnupg", true);
