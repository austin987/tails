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
// Hide "Get Addons" in Add-ons manager
pref("extensions.getAddons.showPane", false);
/* Prevent File -> Print or CTRL+P from causing the browser to hang
   for several minutes while trying to communicate with CUPS, since
   access to port 631 isn't allowed through. */
pref("print.postscript.cups.enabled", false);
