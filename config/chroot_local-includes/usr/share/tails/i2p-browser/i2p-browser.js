/* Disable proxy settings. We also set the other settings that
   Torbutton requires to be happy, i.e. its icon is green. */
user_pref("extensions.torbutton.http_port", 4444);
user_pref("extensions.torbutton.http_proxy", "127.0.0.1");
user_pref("extensions.torbutton.https_port", 4444);
user_pref("extensions.torbutton.https_proxy", "127.0.0.1");
user_pref("extensions.torbutton.custom.ftp_port", 4444);
user_pref("extensions.torbutton.custom.ftp_proxy", "127.0.0.1");
user_pref("extensions.torbutton.custom.http_port", 4444);
user_pref("extensions.torbutton.custom.http_proxy", "127.0.0.1");
user_pref("extensions.torbutton.custom.https_port", 4444);
user_pref("extensions.torbutton.custom.https_proxy", "127.0.0.1");
user_pref("extensions.torbutton.ftp_port", 4444);
user_pref("extensions.torbutton.ftp_proxy", "127.0.0.1");
user_pref("extensions.torbutton.gopher_port", 4444);
user_pref("extensions.torbutton.gopher_proxy", "127.0.0.1");
user_pref("extensions.torbutton.inserted_button", true);
user_pref("extensions.torbutton.settings_method", "custom");
user_pref("network.proxy.ftp", "127.0.0.1");
user_pref("network.proxy.ftp_port", 4444);
user_pref("network.proxy.http", "127.0.0.1");
user_pref("network.proxy.http_port", 4444);
user_pref("network.proxy.no_proxies_on", "127.0.0.1");
user_pref("network.proxy.ssl", "127.0.0.1");
user_pref("network.proxy.ssl_port", 4444);
// Disable searching from the URL bar
user_pref("keyword.enabled", false);
// Hide "Get Addons" in Add-ons manager
user_pref("extensions.getAddons.showPane", false);
/* Prevent File -> Print or CTRL+P from causing the browser to hang
   for several minutes while trying to communicate with CUPS, since
   access to port 631 isn't allowed through. */
user_pref("print.postscript.cups.enabled", false);
