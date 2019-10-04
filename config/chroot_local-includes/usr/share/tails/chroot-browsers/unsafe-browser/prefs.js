user_pref("extensions.torbutton.inserted_button", true);
user_pref("extensions.torbutton.inserted_security_level", true);
// Disable proxying in the chroot
user_pref("extensions.torbutton.use_nontor_proxy", true);
user_pref("network.proxy.type", 0);
user_pref("network.proxy.socks_remote_dns", false);

// Without setting this, the Download Management page will not update
// the progress being made.
user_pref("browser.download.panel.shown", true);

// Disable searching from the URL bar. Mistyping e.g. the IP address
// to your router or some LAN resource could leak to the default
// search engine (this could include credentials, e.g. if something
// like the following is mistyped: ftp://user:password@host).
user_pref("keyword.enabled", false);

// Use the red theme
user_pref("extensions.activeThemeID", "{91a24c60-0f27-427c-b9a6-96b71f3984a9}");

// Hide the security level button
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"PersonalToolbar\":[\"personal-bookmarks\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"torbutton-button\",\"downloads-button\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"PanelUI-contents\":[\"home-button\",\"edit-controls\",\"zoom-controls\",\"new-window-button\",\"save-page-button\",\"print-button\",\"bookmarks-menu-button\",\"history-panelmenu\",\"find-button\",\"preferences-button\",\"add-ons-button\",\"developer-button\"],\"addon-bar\":[\"addonbar-closebutton\",\"status-bar\"]},\"seen\":[\"developer-button\",\"https-everywhere-eff_eff_org-browser-action\",\"_73a6fe31-595d-460b-a920-fcc0f8843232_-browser-action\"],\"dirtyAreaCache\":[\"PersonalToolbar\",\"nav-bar\",\"TabsToolbar\",\"toolbar-menubar\"],\"currentVersion\":14,\"newElementCount\":1}");

// temporary fix
user_pref("extensions.webextensions.uuids", "{\"{91a24c60-0f27-427c-b9a6-96b71f3984a9}\":\"5df1b656-8c68-4696-aca5-682bd09bb455\"}");
