// Disable update checking
pref("app.update.enabled", false);
pref("extensions.update.enabled", false);

// Disable fetching of the new tab page's Tiles links/ads. Ads are
// generally unwanted, and also the fetching is a "phone home" type of
// feature that generates traffic at least the first time the browser
// is started. It won't work in e.g. the I2P Browser, too.
pref("browser.newtabpage.directory.source", "");
pref("browser.newtabpage.directory.ping", "");
// ... and disable the explanation shown the first time
pref("browser.newtabpage.introShown", true);

/* Prevent File -> Print or CTRL+P from causing the browser to hang
   for several minutes while trying to communicate with CUPS, since
   access to port 631 isn't allowed through. */
pref("print.postscript.cups.enabled", false);

// Hide "Get Addons" in Add-ons manager
pref("extensions.getAddons.showPane", false);
