// Disable update checking
user_pref("app.update.enabled", false);
user_pref("extensions.update.enabled", false);

// Disable fetching of the new tab page's Tiles links/ads. Ads are
// generally unwanted, and also the fetching is a "phone home" type of
// feature that generates traffic at least the first time the browser
// is started.
user_pref("browser.newtabpage.directory.source", "");
user_pref("browser.newtabpage.directory.ping", "");
// ... and disable the explanation shown the first time
user_pref("browser.newtabpage.introShown", true);

/* Prevent File -> Print or CTRL+P from causing the browser to hang
   for several minutes while trying to communicate with CUPS, since
   access to port 631 isn't allowed through. */
user_pref("print.postscript.cups.enabled", false);

// Hide "Get Addons" in Add-ons manager
user_pref("extensions.getAddons.showPane", false);

// Disable Pocket service integration
pref("extensions.pocket.enabled", false);
