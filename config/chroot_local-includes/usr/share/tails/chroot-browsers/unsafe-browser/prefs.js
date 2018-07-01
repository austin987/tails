// Disable proxying in the chroot
user_pref("network.proxy.type", 0);
user_pref("network.proxy.socks_remote_dns", false);

// Without setting this, the Download Management page will not update
// the progress being made.
user_pref("browser.download.panel.shown", true);

// Web pages does not render when e10s is enabled, so we have to
// disable it. Note that the "user_"-prefix is required.
user_pref("browser.tabs.remote.autostart.2", false);

// Disable searching from the URL bar. Mistyping e.g. the IP address
// to your router or some LAN resource could leak to the default
// search engine (this could include credentials, e.g. if something
// like the following is mistyped: ftp://user:password@host).
user_pref("keyword.enabled", false);
