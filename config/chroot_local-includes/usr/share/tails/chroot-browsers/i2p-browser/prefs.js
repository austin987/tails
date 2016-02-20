/* Disable proxy settings. We also set the other settings that
   Torbutton requires to be happy, i.e. its icon is green. */
pref("network.proxy.ftp", "127.0.0.1");
pref("network.proxy.ftp_port", 4444);
pref("network.proxy.http", "127.0.0.1");
pref("network.proxy.http_port", 4444);
pref("network.proxy.no_proxies_on", "127.0.0.1");
pref("network.proxy.ssl", "127.0.0.1");
pref("network.proxy.ssl_port", 4444);

// Disable searching from the URL bar
pref("keyword.enabled", false);

// Without setting this, the Download Management page will not update
// the progress being made.
pref("browser.download.panel.shown", true);

// Never  add 'www' or '.com' to hostnames in I2P Browser.
pref("browser.fixup.alternate.enabled", false);
