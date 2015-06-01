// Disable proxying in the chroot
pref("network.proxy.type", 0);
pref("network.proxy.socks_remote_dns", false);

// Disable update checking
pref("app.update.enabled", false);
pref("extensions.update.enabled", false);

/* Prevent File -> Print or CTRL+P from causing the browser to hang
   for several minutes while trying to communicate with CUPS, since
   access to port 631 isn't allowed through. */
pref("print.postscript.cups.enabled", false);
// Hide "Get Addons" in Add-ons manager
pref("extensions.getAddons.showPane", false);

/* Google seems like the least suspicious choice of default search
   engine for the Unsafe Browser's in-the-clear traffic. */
user_pref("browser.search.defaultenginename", "Google");
user_pref("browser.search.selectedEngine", "Google");
