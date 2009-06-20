// debug prefs
pref("extensions.torbutton.debug",true);
pref("extensions.torbutton.loglevel",4);
pref("extensions.torbutton.logmethod",2); // 0=stdout, 1=errorconsole, 2=debuglog

// Display prefs
pref("extensions.torbutton.display_panel",true);
pref("extensions.torbutton.panel_style",'text');
pref("extensions.{e0204bd5-9d31-402b-a99d-a6aa8ffebdca}.description", "chrome://torbutton/locale/torbutton.properties");

// proxy prefs
pref("extensions.torbutton.settings_method",'recommended');
pref("extensions.torbutton.use_privoxy",true);
pref("extensions.torbutton.http_proxy","");
pref("extensions.torbutton.http_port",0);
pref("extensions.torbutton.https_proxy","");
pref("extensions.torbutton.https_port",0);
pref("extensions.torbutton.ftp_proxy","");
pref("extensions.torbutton.ftp_port",0);
pref("extensions.torbutton.gopher_proxy","");
pref("extensions.torbutton.gopher_port",0);
pref("extensions.torbutton.socks_host","");
pref("extensions.torbutton.socks_port",0);
pref("extensions.torbutton.locked_mode",false);
pref("extensions.torbutton.test_url","https://check.torproject.org/?TorButton=true");
pref("extensions.torbutton.test_failed",false);

// XXX: wtf prefs? These seem not actually connected, but govern
// if user wants own tor proxy settings
pref("extensions.torbutton.custom.http_proxy","");
pref("extensions.torbutton.custom.http_port",0);
pref("extensions.torbutton.custom.https_proxy","");
pref("extensions.torbutton.custom.https_port",0);
pref("extensions.torbutton.custom.ftp_proxy","");
pref("extensions.torbutton.custom.ftp_port",0);
pref("extensions.torbutton.custom.gopher_proxy","");
pref("extensions.torbutton.custom.gopher_port",0);
pref("extensions.torbutton.custom.socks_host","");
pref("extensions.torbutton.custom.socks_port",0);

// saved prefs:
pref("extensions.torbutton.saved.type", 0);
pref("extensions.torbutton.saved.http_proxy", "");
pref("extensions.torbutton.saved.http_port",0);
pref("extensions.torbutton.saved.https_proxy","");
pref("extensions.torbutton.saved.https_port",0);
pref("extensions.torbutton.saved.ftp_proxy","");
pref("extensions.torbutton.saved.ftp_port",0);
pref("extensions.torbutton.saved.gopher_proxy","");
pref("extensions.torbutton.saved.gopher_port",0);
pref("extensions.torbutton.saved.socks_host","");
pref("extensions.torbutton.saved.socks_version",0);
pref("extensions.torbutton.saved.socks_port",0);
pref("extensions.torbutton.saved.socks_remote_dns",false);

pref("extensions.torbutton.saved.cookieLifetime",0);
pref("extensions.torbutton.saved.full_page_plugins","");
pref("extensions.torbutton.saved.disk_cache",true);
pref("extensions.torbutton.saved.safebrowsing",true);
pref("extensions.torbutton.saved.search_suggest",true);
pref("extensions.torbutton.saved.enable_java", true);
pref("extensions.torbutton.saved.expire_history", 9);
pref("extensions.torbutton.saved.download_retention", 2);
pref("extensions.torbutton.saved.formfill", true);
pref("extensions.torbutton.saved.remember_signons", true);
pref("extensions.torbutton.saved.livemark_refresh", 0);
pref("extensions.torbutton.saved.sendSecureXSiteReferrer", true);
pref("extensions.torbutton.saved.sendRefererHeader", 2);
pref("extensions.torbutton.saved.dom_storage", true);
pref("extensions.torbutton.saved.mem_cache", true);
pref("extensions.torbutton.saved.http_cache", true);
pref("extensions.torbutton.saved.extension_update", true);
pref("extensions.torbutton.saved.app_update", true);
pref("extensions.torbutton.saved.auto_update", true);
pref("extensions.torbutton.saved.search_update", true);

// State prefs:
pref("extensions.torbutton.tor_enabled",false);
pref("extensions.torbutton.proxies_applied",false);
pref("extensions.torbutton.settings_applied",false);
pref("extensions.torbutton.startup",false);
pref("extensions.torbutton.crashed",false);
pref("extensions.torbutton.noncrashed",false);
pref("extensions.torbutton.block_cert_dialogs",false);
pref("extensions.torbutton.asked_ca_disable",false);
pref("extensions.torbutton.warned_ff3",false);
pref("extensions.torbutton.fresh_install",true);
pref("extensions.torbutton.normal_exit",true);

// Security prefs:
pref("extensions.torbutton.no_tor_plugins",true);
pref("extensions.torbutton.clear_cookies",false);
pref("extensions.torbutton.cookie_jars",true);
pref("extensions.torbutton.dual_cookie_jars",false);
pref("extensions.torbutton.disable_domstorage",true);
pref("extensions.torbutton.clear_cache",true);
pref("extensions.torbutton.block_cache",false);
pref("extensions.torbutton.clear_history",false);
pref("extensions.torbutton.kill_bad_js",true);
pref("extensions.torbutton.block_thread",true);
pref("extensions.torbutton.block_thwrite",true);
pref("extensions.torbutton.block_nthread",false);
pref("extensions.torbutton.block_nthwrite",false);
pref("extensions.torbutton.no_updates",true);
pref("extensions.torbutton.isolate_content",true);
pref("extensions.torbutton.no_search",true);
pref("extensions.torbutton.set_uagent",true);
pref("extensions.torbutton.notor_sessionstore",true);
pref("extensions.torbutton.nonontor_sessionstore",false);
pref("extensions.torbutton.restore_tor",false); 
pref("extensions.torbutton.reload_crashed_jar",true); 
pref("extensions.torbutton.spoof_english",true);
pref("extensions.torbutton.spoof_charset",'iso-8859-1,*,utf-8');
pref("extensions.torbutton.spoof_language",'en-us, en');
pref("extensions.torbutton.spoof_locale",'en-US');
pref("extensions.torbutton.disable_referer",false);
pref("extensions.torbutton.shutdown_method",1); // 0=none, 1=tor, 2=all
pref("extensions.torbutton.block_tforms",true);
pref("extensions.torbutton.block_ntforms",false);
pref("extensions.torbutton.clear_http_auth",true);
pref("extensions.torbutton.close_tor",false);
pref("extensions.torbutton.close_nontor",false);
pref("extensions.torbutton.block_js_history",true);
pref("extensions.torbutton.resize_on_toggle",true);
pref("extensions.torbutton.banned_ports","8118,8123,9050,9051");
pref("extensions.torbutton.block_tor_file_net",true);
pref("extensions.torbutton.block_nontor_file_net",false);
pref("extensions.torbutton.jar_certs",false);
pref("extensions.torbutton.jar_ca_certs",false);
pref("extensions.torbutton.startup_state", 2); // 0=non-tor, 1=tor, 2=last
pref("extensions.torbutton.block_remoting",false);
pref("extensions.torbutton.tor_memory_jar",false);
pref("extensions.torbutton.nontor_memory_jar",false);

// User agent prefs:
pref("extensions.torbutton.appname_override","Netscape");
pref("extensions.torbutton.appversion_override","5.0 (Windows; LANG)");
pref("extensions.torbutton.platform_override","Win32");
pref("extensions.torbutton.oscpu_override", "Windows NT 5.1");
pref("extensions.torbutton.useragent_override", "Mozilla/5.0 (Windows; U; Windows NT 5.1; LANG; rv:1.8.1.16) Gecko/20080702 Firefox/2.0.0.16");
pref("extensions.torbutton.productsub_override","20080702");
pref("extensions.torbutton.buildID_override","0");
pref("extensions.torbutton.useragent_vendor", "");
pref("extensions.torbutton.useragent_vendorSub","");
