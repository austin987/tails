// Disable proxying in the chroot
pref("network.proxy.type", 0);
pref("network.proxy.socks_remote_dns", false);

/* Google seems like the least suspicious choice of default search
   engine for the Unsafe Browser's in-the-clear traffic. */
user_pref("browser.search.defaultenginename", "Google");
user_pref("browser.search.selectedEngine", "Google");

// Don't use geographically specific search prefs, like
// browser.search.*.US for US locales. Our generated amnesia branding
// add-on localizes search-engines in an incompatible but equivalent
// way.
pref("browser.search.geoSpecificDefaults", false);

// Without setting this, the Download Management page will not update
// the progress being made.
pref("browser.download.panel.shown", true);

// Web pages does not render when e10s is enabled, so we have to
// disable it. Note that the "user_"-prefix is required.
user_pref("browser.tabs.remote.autostart.2", false);
