// TODO: check for leaks: http://www.mozilla.org/scriptable/avoiding-leaks.html
// TODO: Double-check there are no strange exploits to defeat:
//       http://kb.mozillazine.org/Links_to_local_pages_don%27t_work

// status
var m_tb_wasinited = false;
var m_tb_prefs = false;
var m_tb_jshooks = false;
var m_tb_plugin_mimetypes = false;
var m_tb_plugin_string = false;
var m_tb_is_main_window = false;

var m_tb_window_height = window.outerHeight;
var m_tb_window_width = window.outerWidth;

var m_tb_ff3 = false;

var torbutton_window_pref_observer =
{
    register: function()
    {
        var pref_service = Components.classes["@mozilla.org/preferences-service;1"]
                                     .getService(Components.interfaces.nsIPrefBranchInternal);
        this._branch = pref_service.QueryInterface(Components.interfaces.nsIPrefBranchInternal);
        this._branch.addObserver("extensions.torbutton", this, false);
    },

    unregister: function()
    {
        if (!this._branch) return;
        this._branch.removeObserver("extensions.torbutton", this);
    },

    // topic:   what event occurred
    // subject: what nsIPrefBranch we're observing
    // data:    which pref has been changed (relative to subject)
    observe: function(subject, topic, data)
    {
        if (topic != "nsPref:changed") return;
        switch (data) {
            // These two need to be per-window:
            case "extensions.torbutton.display_panel":
                torbutton_set_panel_view();
                break;
            case "extensions.torbutton.panel_style":
                torbutton_set_panel_style();
                break;

            // FIXME: Maybe make a intermediate state with a yellow 
            // icon?
            case "extensions.torbutton.settings_applied":
                var mode = m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied");
                torbutton_update_toolbutton(mode);
                torbutton_update_statusbar(mode);
                break;
        }
    }
}

var torbutton_unique_pref_observer =
{
    register: function()
    {
        this.forced_ua = false;
        var pref_service = Components.classes["@mozilla.org/preferences-service;1"]
                                     .getService(Components.interfaces.nsIPrefBranchInternal);
        this._branch = pref_service.QueryInterface(Components.interfaces.nsIPrefBranchInternal);
        this._branch.addObserver("extensions.torbutton", this, false);
        this._branch.addObserver("network.proxy", this, false);
        this._branch.addObserver("network.cookie", this, false);
        this._branch.addObserver("general.useragent", this, false);
    },

    unregister: function()
    {
        if (!this._branch) return;
        this._branch.removeObserver("extensions.torbutton", this);
        this._branch.removeObserver("network.proxy", this);
        this._branch.removeObserver("network.cookie", this);
        this._branch.removeObserver("general.useragent", this);
    },

    // topic:   what event occurred
    // subject: what nsIPrefBranch we're observing
    // data:    which pref has been changed (relative to subject)
    observe: function(subject, topic, data)
    {
        if (topic != "nsPref:changed") return;
        switch (data) {
            // FIXME: If there are other addons than useragentswitcher 
            // that we need to fight with, we should probably check
            // every user agent pref here.. but for now, just these
            // two are enough to reset everything back for UAS.
            case "general.useragent.vendorSub":
            case "general.useragent.override":
                if((!m_tb_prefs.prefHasUserValue("general.useragent.override")
                    || !m_tb_prefs.prefHasUserValue("general.useragent.vendorSub")) 
                    && m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                    && m_tb_prefs.getBoolPref("extensions.torbutton.set_uagent")) {
                    torbutton_log(4, "Some other addond tried to clear user agent settings.");
                    torbutton_set_uagent();
                }
                break;
            case "network.proxy.http":
            case "network.proxy.http_port":
            case "network.proxy.ssl":
            case "network.proxy.ssl_port":
            case "network.proxy.ftp":
            case "network.proxy.ftp_port":
            case "network.proxy.gopher":
            case "network.proxy.gopher_port":
            case "network.proxy.socks":
            case "network.proxy.socks_port":
            case "network.proxy.socks_version":
            case "network.proxy.share_proxy_settings":
            case "network.proxy.socks_remote_dns":
            case "network.proxy.type":
                torbutton_log(1, "Got update message, setting status");
                torbutton_set_status();
                break;

            case "network.cookie.lifetimePolicy":
                // Keep our prefs in sync with the lifetime policy for non-tor
                torbutton_log(2, "Got FF cookie pref change");
                var tor_mode =  m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled");
                var lp = m_tb_prefs.getIntPref("network.cookie.lifetimePolicy");

                if(!tor_mode) {
                    if(lp == 0 && 
                            m_tb_prefs.getBoolPref("extensions.torbutton.nontor_memory_jar")) {
                        m_tb_prefs.setBoolPref("extensions.torbutton.nontor_memory_jar", false);
                    } else if(lp == 1) {
                        if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar'))
                            m_tb_prefs.setBoolPref('extensions.torbutton.tor_memory_jar', false);
                        if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar'))
                            m_tb_prefs.setBoolPref('extensions.torbutton.nontor_memory_jar', false);
                    } else if(lp == 2) {
                        if(!m_tb_prefs.getBoolPref("extensions.torbutton.nontor_memory_jar"))
                             m_tb_prefs.setBoolPref("extensions.torbutton.nontor_memory_jar", true);
                        if(!m_tb_prefs.getBoolPref("extensions.torbutton.tor_memory_jar"))
                             m_tb_prefs.setBoolPref("extensions.torbutton.tor_memory_jar", true);
                    }
                } else {
                    if(lp == 0) { // The cookie's lifetime is supplied by the server.
                        if(m_tb_prefs.getBoolPref("extensions.torbutton.clear_cookies"))
                            m_tb_prefs.setBoolPref("extensions.torbutton.clear_cookies", false);
                        if(m_tb_prefs.getBoolPref("extensions.torbutton.tor_memory_jar"))
                            m_tb_prefs.setBoolPref("extensions.torbutton.tor_memory_jar", false);
                        if(m_tb_prefs.getBoolPref("extensions.torbutton.cookie_jars"))
                            m_tb_prefs.setBoolPref("extensions.torbutton.cookie_jars", false);
                        if(!m_tb_prefs.getBoolPref("extensions.torbutton.dual_cookie_jars"))
                            m_tb_prefs.setBoolPref("extensions.torbutton.dual_cookie_jars", true);
                    } else if(lp == 1) { // The user is prompted for the cookie's lifetime. 
                        if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar'))
                            m_tb_prefs.setBoolPref('extensions.torbutton.tor_memory_jar', false);
                        if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar'))
                            m_tb_prefs.setBoolPref('extensions.torbutton.nontor_memory_jar', false);
                    } else if(lp == 2 && // The cookie expires when the browser closes. 
                            !m_tb_prefs.getBoolPref("extensions.torbutton.tor_memory_jar")) {
                        m_tb_prefs.setBoolPref("extensions.torbutton.tor_memory_jar", true);
                    }
                }
                break;

            case "extensions.torbutton.tor_memory_jar":
            case "extensions.torbutton.nontor_memory_jar":
            case "extensions.torbutton.dual_cookie_jars":
            case "extensions.torbutton.cookie_jars":
            case "extensions.torbutton.clear_cookies":
                torbutton_log(2, "Got cookie pref change");
                var tor_mode =  m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled");
                var lp = m_tb_prefs.getIntPref("network.cookie.lifetimePolicy");

                if(lp == 1) {
                    torbutton_log(3, "Ignoring lifetime policy of 1 (ask user)");
                    if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar'))
                        m_tb_prefs.setBoolPref('extensions.torbutton.tor_memory_jar', false);
                    if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar'))
                        m_tb_prefs.setBoolPref('extensions.torbutton.nontor_memory_jar', false);
                    break;
                }

                if(m_tb_prefs.getBoolPref('extensions.torbutton.clear_cookies')) {
                    lp = 2;
                } else if(m_tb_prefs.getBoolPref('extensions.torbutton.cookie_jars')) {
                    lp = tor_mode ? 2 : 0;
                } else if(m_tb_prefs.getBoolPref("extensions.torbutton.dual_cookie_jars")) {
                    lp = 0;
                } else {
                    lp = 0;
                }

                if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar') 
                        && tor_mode) {
                    lp = 2;
                }

                if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar') 
                        && !tor_mode) {
                    lp = 2;
                }

                if(lp != m_tb_prefs.getIntPref("network.cookie.lifetimePolicy")) {
                    m_tb_prefs.setIntPref("network.cookie.lifetimePolicy", lp);
                }

                break;

            // These two are set from the Torbutton crash-observer component
            // (which itself just wrappes the sessionstartup firefox
            // component to get doRestore notification)
            case "extensions.torbutton.crashed":
                torbutton_crash_recover();
                break;
            case "extensions.torbutton.noncrashed":
               torbutton_set_initial_state();
               break;

            case "extensions.torbutton.set_uagent":
                // If the user turns off the pref, reset their user agent to
                // vanilla
                if(!m_tb_prefs.getBoolPref("extensions.torbutton.set_uagent")) {
                    if(m_tb_prefs.prefHasUserValue("general.appname.override"))
                        m_tb_prefs.clearUserPref("general.appname.override");
                    if(m_tb_prefs.prefHasUserValue("general.appversion.override"))
                        m_tb_prefs.clearUserPref("general.appversion.override");
                    if(m_tb_prefs.prefHasUserValue("general.useragent.override"))
                        m_tb_prefs.clearUserPref("general.useragent.override");
                    if(m_tb_prefs.prefHasUserValue("general.useragent.vendor"))
                        m_tb_prefs.clearUserPref("general.useragent.vendor");
                    if(m_tb_prefs.prefHasUserValue("general.useragent.vendorSub"))
                        m_tb_prefs.clearUserPref("general.useragent.vendorSub");
                    if(m_tb_prefs.prefHasUserValue("general.platform.override"))
                        m_tb_prefs.clearUserPref("general.platform.override");
                    
                    if(m_tb_prefs.prefHasUserValue("general.oscpu.override"))
                        m_tb_prefs.clearUserPref("general.oscpu.override");
                    if(m_tb_prefs.prefHasUserValue("general.buildID.override"))
                        m_tb_prefs.clearUserPref("general.buildID.override");
                    if(m_tb_prefs.prefHasUserValue("general.productSub.override"))
                        m_tb_prefs.clearUserPref("general.productSub.override");

                } else {
                    torbutton_log(1, "Got update message, updating status");
                    torbutton_update_status(
                            m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"),
                            true);
                }
                break;

            case "extensions.torbutton.no_tor_plugins":
                torbutton_update_status(
                        m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"),
                        true);
            case "extensions.torbutton.disable_referer":
            case "extensions.torbutton.disable_domstorage":
            case "extensions.torbutton.no_updates":
            case "extensions.torbutton.no_search":
            case "extensions.torbutton.block_tforms":
            case "extensions.torbutton.block_cache":
            case "extensions.torbutton.block_thwrite":
                if(m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")) {
                    var o_stringbundle = torbutton_get_stringbundle();
                    var warning = o_stringbundle.GetStringFromName("torbutton.popup.toggle.warning");
                    window.alert(warning);
                }
                break;

            case "extensions.torbutton.block_nthwrite":
            case "extensions.torbutton.block_ntforms":
                if(!m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")) {
                    var o_stringbundle = torbutton_get_stringbundle();
                    var warning = o_stringbundle.GetStringFromName("torbutton.popup.toggle.warning");
                    window.alert(warning);
                }
                break;

            case "extensions.torbutton.spoof_english":
                torbutton_log(1, "Got update message, updating status");
                torbutton_update_status(
                        m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"),
                        true);
                break;
        }
    }
}


function torbutton_set_panel_view() {
    var o_statuspanel = false;
    var o_prefbranch = false;

    o_statuspanel = torbutton_get_statuspanel();
    o_prefbranch = torbutton_get_prefbranch('extensions.torbutton.');
    if (!o_statuspanel || !o_prefbranch) return;

    var display_panel = o_prefbranch.getBoolPref('display_panel');
    torbutton_log(2, 'setting panel visibility');
    o_statuspanel.setAttribute('collapsed', !display_panel);
}

function torbutton_set_panel_style() {
    var o_statuspanel = false;
    var o_prefbranch = false;

    o_statuspanel = torbutton_get_statuspanel();
    o_prefbranch = torbutton_get_prefbranch('extensions.torbutton.');
    if (!o_statuspanel || !o_prefbranch) return;

    var panel_style = o_prefbranch.getCharPref('panel_style');
    torbutton_log(2, 'setting panel style: ' + panel_style);
    o_statuspanel.setAttribute('class','statusbarpanel-' + panel_style);
}

function torbutton_toggle(force) {
    var o_toolbutton = false;

    // Only toggle if lock mode is set if the user goes out of their way.
    if(!force && m_tb_prefs.getBoolPref("extensions.torbutton.locked_mode")) {
        return;
    }

    o_toolbutton = torbutton_get_toolbutton();

    torbutton_log(3, 'called toggle()');
    if (!m_tb_wasinited) {
        torbutton_init();
    }

    if (torbutton_check_status()) {
        // Close on toggle before actually changing proxy settings
        // as additional safety precaution
        torbutton_close_on_toggle(false);
        torbutton_disable_tor();
    } else {
        torbutton_close_on_toggle(true);
        torbutton_enable_tor(false);
    }
}

function torbutton_set_status() {
    var state = false;
    if (torbutton_check_status()) {
        state = true;
        try {
            torbutton_update_status(true, false);
        } catch(e) {
            // This should never happen.. 
            // FIXME: Do we need to translate it? I'm guessing not.
            window.alert("Torbutton: Please file bug report! Error applying Tor settings: "+e);
            torbutton_log(5,'Error applying tor settings: '+e);
            // Setting these prefs should avoid ininite recursion
            // because torbutton_update_status should return immediately
            // on the next call.
            m_tb_prefs.setBoolPref("extensions.torbutton.tor_enabled", false);
            m_tb_prefs.setBoolPref("extensions.torbutton.proxies_applied", false);
            m_tb_prefs.setBoolPref("extensions.torbutton.settings_applied", false);
            torbutton_disable_tor();
        }
    } else {
        state = false;
        try {
            torbutton_update_status(false, false);
        } catch(e) {
            // This should never happen.. 
            // FIXME: Do we need to translate it? I'm guessing not.
            window.alert("Torbutton: Please file bug report! Error applying Non-Tor settings: "+e);
            torbutton_log(5,'Error applying nontor settings: '+e);
            // Setting these prefs should avoid ininite recursion
            // because torbutton_update_status should return immediately
            // on the next call.
            m_tb_prefs.setBoolPref("extensions.torbutton.tor_enabled", true);
            m_tb_prefs.setBoolPref("extensions.torbutton.proxies_applied", true);
            m_tb_prefs.setBoolPref("extensions.torbutton.settings_applied", true);
            torbutton_enable_tor(true);
        }
    }
}

function torbutton_init_toolbutton(event)
{
    if (event.originalTarget && event.originalTarget.getAttribute('id') == 'torbutton-button')
       torbutton_update_toolbutton(torbutton_check_status());
}

function torbutton_init() {
    torbutton_log(3, 'called init()');

    // Determine if we are firefox 3 or not.
    var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
        .getService(Components.interfaces.nsIXULAppInfo);
    var versionChecker = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
        .getService(Components.interfaces.nsIVersionComparator);

    if(versionChecker.compare(appInfo.version, "3.0a1") >= 0) {
        m_tb_ff3 = true;
    } else {
        m_tb_ff3 = false;
    }
    
    // initialize preferences before we start our prefs observer
    torbutton_init_prefs();

    // set panel style from preferences
    torbutton_set_panel_style();

    // listen for our toolbar button being added so we can initialize it
    if (torbutton_gecko_compare("1.8") <= 0) {
        document.getElementById('navigator-toolbox')
                .addEventListener('DOMNodeInserted', torbutton_init_toolbutton, false);
    }

    if (!m_tb_wasinited) { 
        // Runs every time a new window is opened
        m_tb_prefs =  Components.classes["@mozilla.org/preferences-service;1"]
                        .getService(Components.interfaces.nsIPrefBranch);

        torbutton_init_jshooks();

        torbutton_log(1, 'registering pref observer');
        torbutton_window_pref_observer.register(); 
        m_tb_wasinited = true;
    } else {
        torbutton_log(1, 'skipping pref observer init');
    }
    
    torbutton_set_panel_view();
    torbutton_log(1, 'setting torbutton status from proxy prefs');
    torbutton_set_status();
    var mode = m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled");
    torbutton_update_toolbutton(mode);
    torbutton_update_statusbar(mode);
    torbutton_log(3, 'init completed');
}

// this function duplicates a lot of code in preferences.js for deciding our
// recommended settings.  figure out a way to eliminate the redundancy.
// TODO: Move it to torbutton_util.js?
function torbutton_init_prefs() {
    var torprefs = false;
    var proxy_port;
    var proxy_host;
    torbutton_log(2, "called init_prefs()");
    torprefs = torbutton_get_prefbranch('extensions.torbutton.');

    // Privoxy is always recommended for Firefoxes not supporting socks_remote_dns
    if (!torbutton_check_socks_remote_dns())
        torprefs.setBoolPref('use_privoxy', true);

    if (torprefs.getBoolPref('use_privoxy'))
    {
        proxy_host = '127.0.0.1';
        proxy_port = 8118;
    }
    else
    {
        proxy_host = '';
        proxy_port = 0;
    }

    if (torprefs.getCharPref('settings_method') == 'recommended')
    {
        torbutton_log(2, "using recommended settings");
        if (torbutton_check_socks_remote_dns())
        {
            torprefs.setCharPref('http_proxy', proxy_host);
            torprefs.setCharPref('https_proxy', proxy_host);
            torprefs.setCharPref('ftp_proxy', '');
            torprefs.setCharPref('gopher_proxy', '');
            torprefs.setIntPref('http_port', proxy_port);
            torprefs.setIntPref('https_port', proxy_port);
            torprefs.setIntPref('ftp_port', 0);
            torprefs.setIntPref('gopher_port', 0);
        } else {
            torprefs.setCharPref('http_proxy', proxy_host);
            torprefs.setCharPref('https_proxy', proxy_host);
            torprefs.setCharPref('ftp_proxy', proxy_host);
            torprefs.setCharPref('gopher_proxy', proxy_host);
            torprefs.setIntPref('http_port', proxy_port);
            torprefs.setIntPref('https_port', proxy_port);
            torprefs.setIntPref('ftp_port', proxy_port);
            torprefs.setIntPref('gopher_port', proxy_port);
        }
        torprefs.setCharPref('socks_host', '127.0.0.1');
        torprefs.setIntPref('socks_port', 9050);
    }

    torbutton_log(1, 'http_port='+torprefs.getIntPref('http_port'));
    // m_tb_prefs.setCharPref('extensions.torbutton.http_proxy',   m_http_proxy);
    // m_tb_prefs.setIntPref('extensions.torbutton.http_port',     m_http_port);
    // m_tb_prefs.setCharPref('extensions.torbutton.https_proxy',  m_https_proxy);
    // m_tb_prefs.setIntPref('extensions.torbutton.https_port',    m_https_port);
    // m_tb_prefs.setCharPref('extensions.torbutton.ftp_proxy',    m_ftp_proxy);
    // m_tb_prefs.setIntPref('extensions.torbutton.ftp_port',      m_ftp_port);
    // m_tb_prefs.setCharPref('extensions.torbutton.gopher_proxy', m_gopher_proxy);
    // m_tb_prefs.setIntPref('extensions.torbutton.gopher_port',   m_gopher_port);
    // m_tb_prefs.setCharPref('extensions.torbutton.socks_host',   m_socks_host);
    // m_tb_prefs.setIntPref('extensions.torbutton.socks_port',    m_socks_port);
}

function torbutton_get_toolbutton() {
    var o_toolbutton = false;

    torbutton_log(1, 'get_toolbutton(): looking for button element');
    if (document.getElementById("torbutton-button")) {
        o_toolbutton = document.getElementById("torbutton-button");
    } else if (document.getElementById("torbutton-button-tb")) {
        o_toolbutton = document.getElementById("torbutton-button-tb");
    } else if (document.getElementById("torbutton-button-tb-msg")) {
        o_toolbutton = document.getElementById("torbutton-button-tb-msg");
    } else {
        torbutton_log(3, 'get_toolbutton(): did not find torbutton-button');
    }

    return o_toolbutton;
}

function torbutton_get_statuspanel() {
    var o_statuspanel = false;

    torbutton_log(1, 'init_statuspanel(): looking for statusbar element');
    if (document.getElementById("torbutton-panel")) {
        o_statuspanel = document.getElementById("torbutton-panel");
    } else {
        torbutton_log(5, 'ERROR (init): failed to find torbutton-panel');
    }

    return o_statuspanel;
}

function torbutton_save_nontor_settings()
{
  var liveprefs = false;
  var savprefs = false;

  liveprefs = torbutton_get_prefbranch('network.proxy.');
  savprefs = torbutton_get_prefbranch('extensions.torbutton.saved.');
  if (!liveprefs || !savprefs) {
      torbutton_log(4, 'Prefbranch error');
      return;
  }

  torbutton_log(2, 'saving nontor settings');
  savprefs.setIntPref('type',          liveprefs.getIntPref('type'));
  savprefs.setCharPref('http_proxy',   liveprefs.getCharPref('http'));
  savprefs.setIntPref('http_port',     liveprefs.getIntPref('http_port'));
  savprefs.setCharPref('https_proxy',  liveprefs.getCharPref('ssl'));
  savprefs.setIntPref('https_port',    liveprefs.getIntPref('ssl_port'));
  savprefs.setCharPref('ftp_proxy',    liveprefs.getCharPref('ftp'));
  torbutton_log(1, 'half-way');
  savprefs.setIntPref('ftp_port',      liveprefs.getIntPref('ftp_port'));
  savprefs.setCharPref('gopher_proxy', liveprefs.getCharPref('gopher'));
  savprefs.setIntPref('gopher_port',   liveprefs.getIntPref('gopher_port'));
  savprefs.setCharPref('socks_host',   liveprefs.getCharPref('socks'));
  savprefs.setIntPref('socks_port',    liveprefs.getIntPref('socks_port'));
  savprefs.setIntPref('socks_version', liveprefs.getIntPref('socks_version'));
  try { // ff-0.9 doesn't have share_proxy_settings
    savprefs.setBoolPref('share_proxy_settings', liveprefs.getBoolPref('share_proxy_settings'));
  } catch(e) {}
  
  torbutton_log(1, 'almost there');
  if (torbutton_check_socks_remote_dns())
    savprefs.setBoolPref('socks_remote_dns',     liveprefs.getBoolPref('socks_remote_dns'));
  torbutton_log(2, 'Non-tor settings saved');
}

function torbutton_restore_nontor_settings()
{
  var liveprefs = false;
  var savprefs = false;

  liveprefs = torbutton_get_prefbranch('network.proxy.');
  savprefs = torbutton_get_prefbranch('extensions.torbutton.saved.');
  if (!liveprefs || !savprefs) {
      torbutton_log(4, 'Prefbranch error');
      return;
  }

  torbutton_log(2, 'restoring nontor settings');

  m_tb_prefs.setBoolPref("extensions.torbutton.tor_enabled", false);
  liveprefs.setIntPref('type',          savprefs.getIntPref('type'));
  liveprefs.setCharPref('http',         savprefs.getCharPref('http_proxy'));
  liveprefs.setIntPref('http_port',     savprefs.getIntPref('http_port'));
  liveprefs.setCharPref('ssl',          savprefs.getCharPref('https_proxy'));
  liveprefs.setIntPref('ssl_port',      savprefs.getIntPref('https_port'));
  liveprefs.setCharPref('ftp',          savprefs.getCharPref('ftp_proxy'));
  torbutton_log(1, 'half-way there');
  liveprefs.setIntPref('ftp_port',      savprefs.getIntPref('ftp_port'));
  liveprefs.setCharPref('gopher',       savprefs.getCharPref('gopher_proxy'));
  liveprefs.setIntPref('gopher_port',   savprefs.getIntPref('gopher_port'));
  liveprefs.setCharPref('socks',        savprefs.getCharPref('socks_host'));
  liveprefs.setIntPref('socks_port',    savprefs.getIntPref('socks_port'));
  liveprefs.setIntPref('socks_version', savprefs.getIntPref('socks_version'));
  try { // ff-0.9 doesn't have share_proxy_settings
    liveprefs.setBoolPref('share_proxy_settings', savprefs.getBoolPref('share_proxy_settings'));
  } catch(e) {}
  
  torbutton_log(1, 'almost there');
  if (torbutton_check_socks_remote_dns())
    liveprefs.setBoolPref('socks_remote_dns',     savprefs.getBoolPref('socks_remote_dns'));

  // This is needed for torbrowser and other cases where the 
  // proxy prefs are actually the same..
  if(torbutton_check_status()) {
      m_tb_prefs.setBoolPref("extensions.torbutton.tor_enabled", true);
  }

  torbutton_log(2, 'settings restored');
}

function torbutton_test_settings() {
    var wasEnabled = true;
    var ret = 0;
    if(!torbutton_check_status()) {
        wasEnabled = false;
        torbutton_enable_tor(true);
    }
            
    torbutton_log(3, "Testing Tor settings");

    m_tb_prefs.setBoolPref("extensions.torbutton.test_failed", true);
    try {
        var req = Components.classes["@mozilla.org/xmlextras/xmlhttprequest;1"]
                                .createInstance(Components.interfaces.nsIXMLHttpRequest);
        //var req = new XMLHttpRequest(); Blocked by content policy
        var url = m_tb_prefs.getCharPref("extensions.torbutton.test_url");
        req.open('GET', url, false);
        req.overrideMimeType("text/xml");
        req.send(null);
    } catch(e) {
        // XXX: This happens if this function is called from a browser
        // window with tor disabled because the content policy will block us.
        // Right now the check works because we get called from the 
        // preference window. Sort of makes automatic testing a bit trickier..
        if(!wasEnabled) torbutton_disable_tor();
        torbutton_log(5, "Test failed! Tor internal error: "+e);
        return 0;
    }
    if(req.status == 200) {
        if(!req.responseXML) {
            if(!wasEnabled) torbutton_disable_tor();
            torbutton_log(5, "Test failed! Not text/xml!");
            return 1;
        }

        var result = req.responseXML.getElementById('TorCheckResult');

        if(result===null) {
            torbutton_log(5, "Test failed! No TorCheckResult element");
            ret = 2;
        } else if(typeof(result.target) == 'undefined' 
                || result.target === null) {
            torbutton_log(5, "Test failed! No target");
            ret = 3;
        } else if(result.target === "success") {
            torbutton_log(3, "Test Successful");
            m_tb_prefs.setBoolPref("extensions.torbutton.test_failed", false);
            ret = 4;
        } else if(result.target === "failure") {
            torbutton_log(5, "Tor test failed!");
            ret = 5;
        } else if(result.target === "unknown") {
            torbutton_log(5, "Tor test failed. TorDNSEL Failure?");
            ret = 6;
        } else {
            torbutton_log(5, "Tor test failed. Strange target.");
            ret = 7;
        }
    } else {
        torbutton_log(5, "Tor test failed. HTTP Error: "+req.status);
        ret = -req.status;
    }
    
    torbutton_log(3, "Done testing Tor settings. Result: "+ret);
        
    if(!wasEnabled) torbutton_disable_tor();
    return ret;
}

function torbutton_disable_tor()
{
  torbutton_log(3, 'called disable_tor()');
  torbutton_restore_nontor_settings();
}

function torbutton_enable_tor(force)
{
  torbutton_log(3, 'called enable_tor()');

  if(!force && m_tb_prefs.getBoolPref("extensions.torbutton.test_failed")) {
      var strings = torbutton_get_stringbundle();
      var warning = strings.GetStringFromName("torbutton.popup.test.confirm_toggle");
      if(!window.confirm(warning)) {
          return;
      }
  }

  torbutton_save_nontor_settings();
  torbutton_activate_tor_settings();
}

function torbutton_update_toolbutton(mode)
{
  var o_toolbutton = torbutton_get_toolbutton();
  if (!o_toolbutton) return;
  var o_stringbundle = torbutton_get_stringbundle();

  if (mode) {
      tooltip = o_stringbundle.GetStringFromName("torbutton.button.tooltip.enabled");
      o_toolbutton.setAttribute('tbstatus', 'on');
      o_toolbutton.setAttribute('tooltiptext', tooltip);
  } else {
      tooltip = o_stringbundle.GetStringFromName("torbutton.button.tooltip.disabled");
      o_toolbutton.setAttribute('tbstatus', 'off');
      o_toolbutton.setAttribute('tooltiptext', tooltip);
  }
}

function torbutton_update_statusbar(mode)
{
    var o_statuspanel = torbutton_get_statuspanel();
    if (!window.statusbar.visible) return;
    var o_stringbundle = torbutton_get_stringbundle();

    if (mode) {
        label   = o_stringbundle.GetStringFromName("torbutton.panel.label.enabled");
        tooltip = o_stringbundle.GetStringFromName("torbutton.panel.tooltip.enabled");
        o_statuspanel.style.color = "#390";
        o_statuspanel.setAttribute('label', label);
        o_statuspanel.setAttribute('tooltiptext', tooltip);
        o_statuspanel.setAttribute('tbstatus', 'on');
    } else {
        label   = o_stringbundle.GetStringFromName("torbutton.panel.label.disabled");
        tooltip = o_stringbundle.GetStringFromName("torbutton.panel.tooltip.disabled");
        o_statuspanel.style.color = "#F00";
        o_statuspanel.setAttribute('label', label);
        o_statuspanel.setAttribute('tooltiptext', tooltip);
        o_statuspanel.setAttribute('tbstatus', 'off');
    }
}

function torbutton_setIntPref(pref, save, val, mode, changed) {
    if(!changed) return; // Handle the pref change cases via observers
    if(mode) {
        if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.setIntPref("extensions.torbutton.saved."+save,
                    m_tb_prefs.getIntPref(pref));
        } else if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.clearUserPref("extensions.torbutton.saved."+save);
        }
        m_tb_prefs.setIntPref(pref, val);
    } else {
        if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.setIntPref(pref, 
                    m_tb_prefs.getIntPref("extensions.torbutton.saved."+save));
        } else if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.clearUserPref(pref);
        }
    }
}

function torbutton_setCharPref(pref, save, val, mode, changed) {
    if(!changed) return; // Handle the pref change cases via observers
    if(mode) {
        if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.setCharPref("extensions.torbutton.saved."+save,
                    m_tb_prefs.getCharPref(pref));
        } else if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.clearUserPref("extensions.torbutton.saved."+save);
        }
        m_tb_prefs.setCharPref(pref, val);
    } else {
        if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.setCharPref(pref, 
                    m_tb_prefs.getCharPref("extensions.torbutton.saved."+save));
        } else if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.clearUserPref(pref);
        }
    }
}

function torbutton_setBoolPref(pref, save, val, mode, changed) {
    if(!changed) return; // Handle the pref change cases via observers
    if(mode) {
        if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.setBoolPref("extensions.torbutton.saved."+save,
                    m_tb_prefs.getBoolPref(pref));
        } else if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.clearUserPref("extensions.torbutton.saved."+save);
        }
        m_tb_prefs.setBoolPref(pref, val);
    } else {
        if(m_tb_prefs.prefHasUserValue("extensions.torbutton.saved."+save)) {
            m_tb_prefs.setBoolPref(pref, 
                    m_tb_prefs.getBoolPref("extensions.torbutton.saved."+save));
        } else if(m_tb_prefs.prefHasUserValue(pref)) {
            m_tb_prefs.clearUserPref(pref);
        }
    }
}

function torbutton_set_timezone(mode, startup) {
    /*
     * XXX: Windows doesn't call tzset() automatically.. Linux and MacOS
     * both do though.. :(
     */
    // XXX: Test: 
    //  1. odd timezones like IST and IST+13:30
    //  2. negative offsets
    //  3. Windows-style spaced names
    var environ = Components.classes["@mozilla.org/process/environment;1"]
                   .getService(Components.interfaces.nsIEnvironment);
        
    torbutton_log(3, "Setting timezone at "+startup+" for mode "+mode);

    // For TZ info, see:
    // http://www-01.ibm.com/support/docview.wss?rs=0&uid=swg21150296
    // and 
    // http://msdn.microsoft.com/en-us/library/90s5c885.aspx
    if(startup) {
        // Save Date() string to pref
        var d = new Date();
        var offset = d.getTimezoneOffset();
        var offStr = "";
        if(d.getTimezoneOffset() < 0) {
            offset = -offset;
            offStr = "-";
        } else {
            offStr = "+";
        }
        
        if(offset/60 < 10) {
            offStr += "0";
        }
        offStr += (offset/60)+":";
        if((offset%60) < 10) {
            offStr += "0";
        }
        offStr += (offset%60);

        // Regex match for 3 letter code
        var re = new RegExp('\\((\\S+)\\)', "gm");
        match = re.exec(d.toString());
        // Parse parens. If parseable, use. Otherwise set TZ=""
        var set = ""
        if(match) {
            set = match[1]+offStr;
        } else {
            torbutton_log(3, "Skipping timezone storage");
        }
        m_tb_prefs.setCharPref("extensions.torbutton.tz_string", set);
    }

    if(mode) {
        torbutton_log(2, "Setting timezone to UTC");
        environ.set("TZ", "UTC");
    } else {
        // 1. If startup TZ string, reset.
        torbutton_log(2, "Unsetting timezone.");
        // FIXME: Tears.. This will not update during daylight switch for linux+mac users
        // Windows users will be fine though, because tz_string should be empty for them
        environ.set("TZ", m_tb_prefs.getCharPref("extensions.torbutton.tz_string"));
    }
}

function torbutton_set_uagent() {
    try {
        var torprefs = torbutton_get_prefbranch('extensions.torbutton.');
        var lang = new RegExp("LANG", "gm");
        var appname = torprefs.getCharPref("appname_override");
        var appvers = torprefs.getCharPref("appversion_override");
        if(torprefs.getBoolPref("spoof_english")) {
            appname = appname.replace(lang, 
                    torprefs.getCharPref("spoof_locale"));
            appvers = appvers.replace(lang, 
                    torprefs.getCharPref("spoof_locale"));
        } else {
            appname = appname.replace(lang, 
                    m_tb_prefs.getCharPref("general.useragent.locale"));
            appvers = appvers.replace(lang, 
                    m_tb_prefs.getCharPref("general.useragent.locale"));
        }
        m_tb_prefs.setCharPref("general.appname.override", appname);

        m_tb_prefs.setCharPref("general.appversion.override", appvers);

        m_tb_prefs.setCharPref("general.platform.override",
                torprefs.getCharPref("platform_override"));

        var agent = torprefs.getCharPref("useragent_override");
        if(torprefs.getBoolPref("spoof_english")) {
            agent = agent.replace(lang,
                    torprefs.getCharPref("spoof_locale"));
        } else {
            agent = agent.replace(lang,
                    m_tb_prefs.getCharPref("general.useragent.locale"));
        }
        m_tb_prefs.setCharPref("general.useragent.override", agent);

        m_tb_prefs.setCharPref("general.useragent.vendor",
                torprefs.getCharPref("useragent_vendor"));

        m_tb_prefs.setCharPref("general.useragent.vendorSub",
                torprefs.getCharPref("useragent_vendorSub"));

        m_tb_prefs.setCharPref("general.oscpu.override",
                torprefs.getCharPref("oscpu_override"));

        m_tb_prefs.setCharPref("general.buildID.override",
                torprefs.getCharPref("buildID_override"));

        m_tb_prefs.setCharPref("general.productSub.override",
                torprefs.getCharPref("productsub_override"));
    } catch(e) {
        torbutton_log(5, "Prefset error");
    }
}


// NOTE: If you touch any additional prefs in here, be sure to update
// the list in torbutton_util.js::torbutton_reset_browser_prefs()
function torbutton_update_status(mode, force_update) {
    var o_toolbutton = false;
    var o_statuspanel = false;
    var o_stringbundle = false;
    var sPrefix;
    var label;
    var tooltip;
   
    var torprefs = torbutton_get_prefbranch('extensions.torbutton.');
    var changed = (torprefs.getBoolPref('proxies_applied') != mode);

    torbutton_log(2, 'called update_status: '+mode+","+changed);

    // this function is called every time there is a new window! Alot of this
    // stuff expects to be called on toggle only.. like the cookie jars and
    // history/cookie clearing
    if(!changed && !force_update) return;

    torprefs.setBoolPref('proxies_applied', mode);
    if(torprefs.getBoolPref("tor_enabled") != mode) {
        torbutton_log(3, 'Got external update for: '+mode);
        torprefs.setBoolPref("tor_enabled", mode);
    }

    /*
    if(m_tb_ff3 
            && !m_tb_prefs.getBoolPref("extensions.torbutton.warned_ff3")
            && mode && changed) {
        var o_stringbundle = torbutton_get_stringbundle();
        var warning = o_stringbundle.GetStringFromName("torbutton.popup.ff3.warning");
        var ret = window.confirm(warning);

        if(!ret) {
            torbutton_disable_tor();
            return;
        }
        m_tb_prefs.setBoolPref("extensions.torbutton.warned_ff3", true);
    }*/
    
    // Toggle JS state early, since content window JS runs in a different
    // thread
    torbutton_log(2, 'Toggling JS state');

    torbutton_toggle_jsplugins(mode, 
            changed && torprefs.getBoolPref("isolate_content"),
            torprefs.getBoolPref("no_tor_plugins"));

    torbutton_log(2, 'Setting user agent');
    
    if(torprefs.getBoolPref("set_uagent")) {
        if(mode) {
            torbutton_set_uagent();
        } else {
            try {
                if(m_tb_prefs.prefHasUserValue("general.appname.override"))
                    m_tb_prefs.clearUserPref("general.appname.override");
                if(m_tb_prefs.prefHasUserValue("general.appversion.override"))
                    m_tb_prefs.clearUserPref("general.appversion.override");
                if(m_tb_prefs.prefHasUserValue("general.useragent.override"))
                    m_tb_prefs.clearUserPref("general.useragent.override");
                if(m_tb_prefs.prefHasUserValue("general.useragent.vendor"))
                    m_tb_prefs.clearUserPref("general.useragent.vendor");
                if(m_tb_prefs.prefHasUserValue("general.useragent.vendorSub"))
                    m_tb_prefs.clearUserPref("general.useragent.vendorSub");
                if(m_tb_prefs.prefHasUserValue("general.platform.override"))
                    m_tb_prefs.clearUserPref("general.platform.override");

                if(m_tb_prefs.prefHasUserValue("general.oscpu.override"))
                    m_tb_prefs.clearUserPref("general.oscpu.override");
                if(m_tb_prefs.prefHasUserValue("general.buildID.override"))
                    m_tb_prefs.clearUserPref("general.buildID.override");
                if(m_tb_prefs.prefHasUserValue("general.productSub.override"))
                    m_tb_prefs.clearUserPref("general.productSub.override");
            } catch (e) {
                // This happens because we run this from time to time
                torbutton_log(3, "Prefs already cleared");
            }
        }
    }

    torbutton_log(2, 'Done with user agent: '+changed);

    // FIXME: This is not ideal, but the refspoof method is not compatible
    // with FF2.0
    if(torprefs.getBoolPref("disable_referer")) {
        torbutton_setBoolPref("network.http.sendSecureXSiteReferrer", 
                "sendSecureXSiteReferrer", !mode, mode, changed);
        torbutton_setIntPref("network.http.sendRefererHeader", 
                "sendRefererHeader", mode?0:2, mode, changed);
    } else {
        torbutton_setBoolPref("network.http.sendSecureXSiteReferrer", 
                "sendSecureXSiteReferrer", true, mode, changed);
        torbutton_setIntPref("network.http.sendRefererHeader", 
                "sendRefererHeader", 2, mode, changed);
    }

    if(torprefs.getBoolPref("disable_domstorage")) {
        torbutton_setBoolPref("dom.storage.enabled", 
                "dom_storage", !mode, mode, changed);
    } else {
        torbutton_setBoolPref("dom.storage.enabled", 
                "dom_storage", true, mode, changed);
    }

    if(torprefs.getBoolPref("spoof_english") && mode) {
        m_tb_prefs.setCharPref("intl.accept_charsets", 
                torprefs.getCharPref("spoof_charset"));
        m_tb_prefs.setCharPref("intl.accept_languages",
                torprefs.getCharPref("spoof_language"));
    } else {
        try {
            if(m_tb_prefs.prefHasUserValue("intl.accept_charsets"))
                m_tb_prefs.clearUserPref("intl.accept_charsets");
            if(m_tb_prefs.prefHasUserValue("intl.accept_languages"))
                m_tb_prefs.clearUserPref("intl.accept_languages");
        } catch (e) {
            // Can happen if english browser.
            torbutton_log(3, "Browser already english");
        }
    }

    if (torprefs.getBoolPref("no_updates")) {
        torbutton_setBoolPref("extensions.update.enabled", "extension_update",
                !mode, mode, changed);
        torbutton_setBoolPref("app.update.enabled", "app_update",
                !mode, mode, changed);
        torbutton_setBoolPref("app.update.auto", "auto_update",
                !mode, mode, changed);
        torbutton_setBoolPref("browser.search.update", "search_update",
                !mode, mode, changed);
    } else {
        torbutton_setBoolPref("extensions.update.enabled", "extension_update",
                true, mode, changed);
        torbutton_setBoolPref("app.update.enabled", "app_update",
                true, mode, changed);
        torbutton_setBoolPref("app.update.auto", "auto_update",
                true, mode, changed);
        torbutton_setBoolPref("browser.search.update", "search_update",
                true, mode, changed);
    }

    if (torprefs.getBoolPref('block_cache')) {
        torbutton_setBoolPref("browser.cache.memory.enable", 
                "mem_cache", !mode, mode, changed);
        torbutton_setBoolPref("network.http.use-cache", 
                "http_cache", !mode, mode, changed);
    } else {
        torbutton_setBoolPref("browser.cache.memory.enable", 
                "mem_cache", true, mode, changed);
        torbutton_setBoolPref("network.http.use-cache", 
                "http_cache", true, mode, changed);
    }

    var children = m_tb_prefs.getChildList("network.protocol-handler.warn-external", 
            new Object());
    torbutton_log(2, 'Children: '+ children.length);
    for(var i = 0; i < children.length; i++) {
        torbutton_log(2, 'Children: '+ children[i]);
        if(mode) {
            m_tb_prefs.setBoolPref(children[i], mode);
        } else {
            if(m_tb_prefs.prefHasUserValue(children[i]))
                m_tb_prefs.clearUserPref(children[i]);
        }
    }
    
    // Always block disk cache during Tor. We clear it on toggle, 
    // so no need to keep it around for someone to rifle through.
    torbutton_setBoolPref("browser.cache.disk.enable", "disk_cache", !mode, 
            mode, changed);

    // Disable safebrowsing in Tor for FF2. It fetches some info in 
    // cleartext with no HMAC (Firefox Bug 360387)
    if(!m_tb_ff3) {
        torbutton_setBoolPref("browser.safebrowsing.enabled", "safebrowsing", 
                !mode, mode, changed);
    }

    // I think this pref is evil (and also hidden from user configuration, 
    // which makes it extra evil) and so therefore am disabling it 
    // by fiat for both tor and non-tor. Basically, I'm not willing 
    // to put the code in to allow it to be enabled until someone 
    // complains that it breaks stuff.
    m_tb_prefs.setBoolPref("browser.send_pings", false);

    // Always, always disable remote "safe browsing" lookups.
    m_tb_prefs.setBoolPref("browser.safebrowsing.remoteLookups", false);

    // Prevent pages from pinging the Tor ports regardless tor mode
    m_tb_prefs.setCharPref("network.security.ports.banned", 
            m_tb_prefs.getCharPref("extensions.torbutton.banned_ports"));
   
    if (m_tb_prefs.getBoolPref("extensions.torbutton.no_search")) {
        torbutton_setBoolPref("browser.search.suggest.enabled", 
                "search_suggest", !mode, mode, changed);
    } else {
        torbutton_setBoolPref("browser.search.suggest.enabled", 
                "search_suggest", true, mode, changed);
    }
        
    if(m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins")) {
        torbutton_setBoolPref("security.enable_java", "enable_java", !mode, 
                mode, changed);
    } else {
        torbutton_setBoolPref("security.enable_java", "enable_java", true,
                mode, changed);
    }

    if (m_tb_prefs.getBoolPref('extensions.torbutton.clear_cache')) {
        var cache = Components.classes["@mozilla.org/network/cache-service;1"].
        getService(Components.interfaces.nsICacheService);
        // Throws exception on FF3 sometimes.. who knows why. FF3 bug?
        try {
            cache.evictEntries(0);
        } catch(e) {
            torbutton_log(3, "Exception on cache clearing: "+e);
        }
    }

    if (m_tb_prefs.getBoolPref('extensions.torbutton.clear_history')) {
        torbutton_clear_history();
    }

    if(mode) {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.block_thwrite')) {
            torbutton_setIntPref("browser.download.manager.retention", 
                    "download_retention", 0, mode, changed);
        } 

        if(m_tb_prefs.getBoolPref('extensions.torbutton.block_tforms')) {
            torbutton_setBoolPref("browser.formfill.enable", "formfill",
                    false, mode, changed);
            torbutton_setBoolPref("signon.rememberSignons", "remember_signons", 
                    false, mode, changed);
        }
    } else {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.block_nthwrite')) {
            m_tb_prefs.setIntPref("browser.download.manager.retention", 0);
        } else {
            torbutton_setIntPref("browser.download.manager.retention", 
                    "download_retention", 0, mode, changed);
        }

        if(m_tb_prefs.getBoolPref('extensions.torbutton.block_ntforms')) {
            m_tb_prefs.setBoolPref("browser.formfill.enable", false);
            m_tb_prefs.setBoolPref("signon.rememberSignons", false);
        } else {
            torbutton_setBoolPref("browser.formfill.enable", "formfill", 
                    false, mode, changed);
            torbutton_setBoolPref("signon.rememberSignons", "remember_signons", 
                    false, mode, changed);
        }
    }

    torbutton_log(2, "Prefs pretty much done");
    
    if(m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins")) {
        torbutton_setCharPref("plugin.disable_full_page_plugin_for_types",
                "full_page_plugins", m_tb_plugin_string, mode, changed);
    } else {
        torbutton_setCharPref("plugin.disable_full_page_plugin_for_types",
                "full_page_plugins", m_tb_plugin_string, false, changed);
    }

    // No need to clear cookies if just updating prefs
    if(!changed && force_update)
        return;

    // XXX: Pref for this? Hrmm.. It's broken anyways
    torbutton_setIntPref("browser.bookmarks.livemark_refresh_seconds", 
            "livemark_refresh", 31536000, mode, changed);

    torbutton_set_timezone(mode, false);

    // This call also has to be here for 3rd party proxy changers.
    torbutton_close_on_toggle(mode);

    if(m_tb_prefs.getBoolPref('extensions.torbutton.clear_http_auth')) {
        var auth = Components.classes["@mozilla.org/network/http-auth-manager;1"].
        getService(Components.interfaces.nsIHttpAuthManager);
        auth.clearAll();
    }

    // This clears the SSL Identifier Cache.
    // See https://bugzilla.mozilla.org/show_bug.cgi?id=448747 and
    // http://mxr.mozilla.org/security/source/security/manager/ssl/src/nsNSSComponent.cpp#2057
    m_tb_prefs.setBoolPref("security.enable_ssl2", 
            !m_tb_prefs.getBoolPref("security.enable_ssl2"));
    m_tb_prefs.setBoolPref("security.enable_ssl2", 
            !m_tb_prefs.getBoolPref("security.enable_ssl2"));

    var lp = m_tb_prefs.getIntPref("network.cookie.lifetimePolicy");

    if(lp == 1) {
        torbutton_log(3, "Ignoring update lifetime policy of 1 (ask user)");
        if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar'))
            m_tb_prefs.setBoolPref('extensions.torbutton.tor_memory_jar', false);
        if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar'))
            m_tb_prefs.setBoolPref('extensions.torbutton.nontor_memory_jar', false);
    } else {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.clear_cookies')) {
            lp = 2;
        } else if(m_tb_prefs.getBoolPref('extensions.torbutton.cookie_jars')) {
            lp = mode ? 2 : 0;
        } else if(m_tb_prefs.getBoolPref("extensions.torbutton.dual_cookie_jars")) {
            lp = 0;
        }

        /* Don't write cookies to disk no matter what if memory jars are enabled
         * for this mode. */
        if(m_tb_prefs.getBoolPref('extensions.torbutton.tor_memory_jar') && mode) {
            lp = 2;
        }

        if(m_tb_prefs.getBoolPref('extensions.torbutton.nontor_memory_jar') && !mode) {
            lp = 2;
        }

        if(lp != m_tb_prefs.getIntPref("network.cookie.lifetimePolicy")) {
            m_tb_prefs.setIntPref("network.cookie.lifetimePolicy", lp);
        }
    }

    if (m_tb_prefs.getBoolPref('extensions.torbutton.clear_cookies')) {
        torbutton_clear_cookies();
    } else if (m_tb_prefs.getBoolPref('extensions.torbutton.cookie_jars') 
            || m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars')) {
        torbutton_jar_cookies(mode);
    }

    if (m_tb_prefs.getBoolPref('extensions.torbutton.jar_certs')) {
        torbutton_jar_certs(mode);
    }

    m_tb_prefs.setBoolPref("extensions.torbutton.settings_applied", mode);
    torbutton_log(3, "Settings applied for mode: "+mode);
}

function torbutton_close_on_toggle(mode) {
    var close_tor = m_tb_prefs.getBoolPref("extensions.torbutton.close_tor");
    var close_nontor = m_tb_prefs.getBoolPref("extensions.torbutton.close_nontor");

    if((!close_tor && !mode) || (mode && !close_nontor)) {
        torbutton_log(3, "Not closing tabs");
        return;
    }

    // TODO: muck around with browser.tabs.warnOnClose.. maybe..
    torbutton_log(3, "Closing tabs");
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
        .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("navigator:browser");
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        var browser = win.getBrowser();
        var tabs = browser.browsers.length;
        var remove = new Array();
        for(var i = 0; i < tabs; i++) {
            if(browser.browsers[i].__tb_tor_fetched != mode) {
                remove.push(browser.browsers[i]);
            }
        }

        for(var i = 0; i < remove.length; i++) {
            browser.removeTab(remove[i]);
        }

        torbutton_log(3, "Length: "+browser.browsers.length);

        if(browser.browsers.length == 1 
                && browser.browsers[0].__tb_tor_fetched != mode) {
            if(win != window) {
                win.close();
            } else {
                var newb = browser.addTab("about:blank");
                browser.removeAllTabsBut(newb);
            }
        }
    }
}


function torbutton_open_prefs_dialog() {
    window.openDialog("chrome://torbutton/content/preferences.xul","torbutton-preferences","centerscreen, chrome");
    torbutton_log(2, 'opened preferences window');
}

function torbutton_open_about_dialog() {
    var extensionManager = Components.classes["@mozilla.org/extensions/manager;1"]
                           .getService(Components.interfaces.nsIExtensionManager);
    var database = '@mozilla.org/rdf/datasource;1?name=composite-datasource';
    var extension_id = '';
    database = Components.classes[database]
               .getService(Components.interfaces.nsIRDFCompositeDataSource);
    database.AddDataSource(extensionManager.datasource);

    if (torbutton_gecko_compare("1.8") <= 0)
    {
        // Firefox 1.5 -- use built-in about box
        extension_id = "urn:mozilla:item:{e0204bd5-9d31-402b-a99d-a6aa8ffebdca}";
        window.openDialog("chrome://mozapps/content/extensions/about.xul","","chrome",extension_id,database);
    } else {
        // Firefox 1.0 -- home page link is broken in built-in about box, use our own
        extension_id = "urn:mozilla:extension:{e0204bd5-9d31-402b-a99d-a6aa8ffebdca}";
        window.openDialog("chrome://torbutton/content/about.xul","","chrome",extension_id,database);
    }
}

function torbutton_about_init() {
    var extensionID = window.arguments[0];
    var extensionDB = window.arguments[1];

    var oBundle = Components.classes["@mozilla.org/intl/stringbundle;1"]
                            .getService(Components.interfaces.nsIStringBundleService);
    var extensionsStrings = document.getElementById("extensionsStrings");

    var rdfs = Components.classes["@mozilla.org/rdf/rdf-service;1"]
                         .getService(Components.interfaces.nsIRDFService);
    var extension = rdfs.GetResource(extensionID);

    var versionArc = rdfs.GetResource("http://www.mozilla.org/2004/em-rdf#version");
    var version = extensionDB.GetTarget(extension, versionArc, true);
    version = version.QueryInterface(Components.interfaces.nsIRDFLiteral).Value;

    var extensionVersion = document.getElementById("torbuttonVersion");

    extensionVersion.setAttribute("value", extensionsStrings.getFormattedString("aboutWindowVersionString", [version]));
}

function torbutton_gecko_compare(aVersion) {
    var ioService = Components.classes["@mozilla.org/network/io-service;1"]
                    .getService(Components.interfaces.nsIIOService);
    var httpProtocolHandler = ioService.getProtocolHandler("http")
                              .QueryInterface(Components.interfaces.nsIHttpProtocolHandler);
    var versionComparator = null;

    if ("nsIVersionComparator" in Components.interfaces) {
        versionComparator = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
                            .getService(Components.interfaces.nsIVersionComparator);
    } else {
        versionComparator = Components.classes["@mozilla.org/updates/version-checker;1"]
                            .getService(Components.interfaces.nsIVersionChecker);
    }
    var geckoVersion = httpProtocolHandler.misc.match(/rv:([0-9.]+)/)[1];
    return versionComparator.compare(aVersion, geckoVersion);
}

function torbutton_browser_proxy_prefs_init()
{
  var _elementIDs = ["networkProxyType",
                     "networkProxyFTP", "networkProxyFTP_Port",
                     "networkProxyGopher", "networkProxyGopher_Port",
                     "networkProxyHTTP", "networkProxyHTTP_Port",
                     "networkProxySOCKS", "networkProxySOCKS_Port",
                     "networkProxySOCKSVersion",
                     "networkProxySOCKSVersion4", "networkProxySOCKSVersion5",
                     "networkProxySSL", "networkProxySSL_Port",
                     "networkProxyNone", "networkProxyAutoconfigURL", "shareAllProxies"];

  torbutton_log(2, 'called torbutton_browser_proxy_prefs_init()');
  if (!torbutton_check_status())
  {
    document.getElementById('torbutton-pref-connection-notice').hidden = true;
    document.getElementById('torbutton-pref-connection-more-info').hidden = true;
  }
  else
  {
    document.getElementById('networkProxyType').disabled = true;
    for (i = 0; i < _elementIDs.length; i++)
        document.getElementById(_elementIDs[i]).setAttribute( "disabled", "true" );
  }

  // window.sizeToContent();
}

// -------------- HISTORY & COOKIES ---------------------
function torbutton_clear_history() {
    torbutton_log(2, 'called torbutton_clear_history');
    var hist = Components.classes["@mozilla.org/browser/global-history;2"]
                    .getService(Components.interfaces.nsIBrowserHistory);
    hist.removeAllPages();

    // Clear individual session histories also
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                       .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("navigator:browser");
    var js_enabled = m_tb_prefs.getBoolPref("javascript.enabled");
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        var browser = win.getBrowser();
        var browsers = browser.browsers;
        torbutton_log(1, "Toggle window plugins");

        for (var i = 0; i < browsers.length; ++i) {
            var b = browser.browsers[i];

            if(b.webNavigation.sessionHistory.count) {
                b.webNavigation.sessionHistory.PurgeHistory(
                        b.webNavigation.sessionHistory.count);
            }
        }
    }
}

function torbutton_clear_cookies() {
    torbutton_log(2, 'called torbutton_clear_cookies');
    var cm = Components.classes["@mozilla.org/cookiemanager;1"]
                    .getService(Components.interfaces.nsICookieManager);
   
    cm.removeAll();
}

function torbutton_jar_cookies(mode) {
    var selector =
          Components.classes["@stanford.edu/cookie-jar-selector;1"]
                    .getService(Components.interfaces.nsISupports)
                    .wrappedJSObject;

    /*
    if(m_tb_ff3) {
        var o_stringbundle = torbutton_get_stringbundle();
        var warning = o_stringbundle.GetStringFromName("torbutton.popup.ff3.cookie_warning");
        window.alert(warning);
        return;
    }*/

    if(mode) {
        selector.saveCookies("nontor");
        selector.clearCookies();
        if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars'))
            selector.loadCookies("tor", false);
    } else {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars'))
            selector.saveCookies("tor");
        selector.clearCookies();
        selector.loadCookies("nontor", false);
    }
}

function torbutton_jar_cert_type(mode, treeView, name, type) {
    var certdb = Components.classes["@mozilla.org/security/x509certdb;1"]
                    .getService(Components.interfaces.nsIX509CertDB2);
    certdb.QueryInterface(Components.interfaces.nsIX509CertDB);
    var outFile = Components.classes["@mozilla.org/file/local;1"].
        createInstance(Components.interfaces.nsILocalFile); 
    var outList = [];
    var outIndexList = [];
    
    torbutton_log(2, "Jaring "+name+" certificates: "+mode);

    if(type == Components.interfaces.nsIX509Cert.CA_CERT) {
        try {
            var bundles = Components.classes["@mozilla.org/intl/stringbundle;1"]
                .getService(Components.interfaces.nsIStringBundleService);
            var pipnss_bundle = bundles.createBundle("chrome://pipnss/locale/pipnss.properties");
            var internalToken = pipnss_bundle.GetStringFromName("InternalToken");
        } catch(err) {
            torbutton_log(5, "No String bundle for NSS: "+err);
        }
    }

    for(var i = 0; i < treeView.rowCount; i++) {
        var cert = treeView.getCert(i);
        // HACK alert
        // There is no real way to differentiate user added 
        // CA certificates from builtin ones, aside from the 
        // token name string (which is localized) 
        if(!cert || (type == Components.interfaces.nsIX509Cert.CA_CERT
                && cert.tokenName != internalToken)) {
            continue;
        }

        outList.push(cert);
        outIndexList.push(i);
    }

    // Write current certs to certjar-tor
    // clear certs
    // load certs from certjar-nontor (if exists)

    var dir = Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("ProfD", Components.interfaces.nsIFile);

    if(mode) {
        // http://developer.mozilla.org/en/docs/Code_snippets:File_I/O#Getting_special_files
        outFile.initWithPath(dir.path);
        outFile.append("certs-"+name+".nottor");
    } else {
        // http://developer.mozilla.org/en/docs/Code_snippets:File_I/O#Getting_special_files
        outFile.initWithPath(dir.path);
        outFile.append("certs-"+name+".tor");
    }

    // this prompts for a password..
    //certdb.exportPKCS12File(null, outFile, outList.length, outList);
 
    if(outFile.exists()) {
        outFile.remove(false);
    }

    if(outList.length) {
        outFile.create(Components.interfaces.nsIFile.NORMAL_FILE_TYPE, 0600);

        var stream = Components.classes["@mozilla.org/network/file-output-stream;1"]
            .createInstance(Components.interfaces.nsIFileOutputStream);
        stream.init(outFile, 0x04 | 0x08 | 0x20, 0600, 0); // write, create, truncate

        var bstream = Components.classes["@mozilla.org/binaryoutputstream;1"]
            .createInstance(Components.interfaces.nsIBinaryOutputStream);
        bstream.setOutputStream(stream);

        var binaryCerts = [];
        var bitList = [];

        for(var i = outList.length-1; i>=0; i--) {
            if(outList[i]) {
                var len = new Object();
                var data = outList[i].getRawDER(len);
                //torbutton_log(2, "Delete: "+certdb.deleteCertificate(outList[i]));
                torbutton_log(2, "Delete: "+outList[i].organization+" "+outList[i].tokenName);
                // Need to save trustbits somehow.. They are not saved.
                var bits = 0;
                if(certdb.isCertTrusted(outList[i], type, certdb.TRUSTED_SSL)) {
                    bits |= certdb.TRUSTED_SSL;
                }
                if(certdb.isCertTrusted(outList[i], type, certdb.TRUSTED_EMAIL)) {
                    bits |= certdb.TRUSTED_EMAIL;
                }
                if(certdb.isCertTrusted(outList[i], type, certdb.TRUSTED_OBJSIGN)) {
                    bits |= certdb.TRUSTED_OBJSIGN;
                }

                treeView.removeCert(outIndexList[i]);
                certdb.deleteCertificate(outList[i]);

                bitList.push(bits); 
                binaryCerts.push(data);
            }
        }

        bstream.write32(binaryCerts.length);
        for(var i = 0; i < binaryCerts.length; i++) {
            bstream.write32(binaryCerts[i].length);
            bstream.write32(bitList[i]);
            bstream.writeByteArray(binaryCerts[i], binaryCerts[i].length);
        }

        bstream.close();
        stream.close();
    }
    
    torbutton_log(2, "Wrote "+outList.length+" "+name+" certificates to "+outFile.path);
}

function torbutton_bytearray_to_string(ba) {
    var ret = "";
    for(var i = 0; i < ba.length; i++) {
        ret = ret + String.fromCharCode(ba[i]);
    }
    return ret;
}

function torbutton_unjar_cert_type(mode, treeView, name, type) {
    var unjared_certs = 0;
    var certdb = Components.classes["@mozilla.org/security/x509certdb;1"]
                    .getService(Components.interfaces.nsIX509CertDB2);
    certdb.QueryInterface(Components.interfaces.nsIX509CertDB);

    var inFile = Components.classes["@mozilla.org/file/local;1"].
        createInstance(Components.interfaces.nsILocalFile); 

    var dir = Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("ProfD", Components.interfaces.nsIFile);

    if(mode) {
        inFile.initWithPath(dir.path);
        inFile.append("certs-"+name+".tor");
    } else {
        inFile.initWithPath(dir.path);
        inFile.append("certs-"+name+".nottor");
    }
    
    torbutton_log(2, "Checking for certificates from "+inFile.path);

    if(!inFile.exists()) {
        return;
    }
    torbutton_log(2, "Reading certificates from "+inFile.path);

    var istream = Components.classes["@mozilla.org/network/file-input-stream;1"]
        .createInstance(Components.interfaces.nsIFileInputStream);
    istream.init(inFile, -1, -1, false);

    var bstream = Components.classes["@mozilla.org/binaryinputstream;1"]
        .createInstance(Components.interfaces.nsIBinaryInputStream);
    bstream.setInputStream(istream);

    if(bstream.available()) {
        var certs = bstream.read32();

        if(type == Components.interfaces.nsIX509Cert.CA_CERT) {
            m_tb_prefs.setBoolPref("extensions.torbutton.block_cert_dialogs", 
                    true);
        }

        for(var i = 0; i < certs; i++) {
            var len = bstream.read32();
            var trustBits = bstream.read32();
            var bytes = bstream.readByteArray(len);

            // This just for the trustBits, which seem to be lost 
            // in the BER translation. sucks..
            var base64 = window.btoa(torbutton_bytearray_to_string(bytes));
            var checkCert = certdb.constructX509FromBase64(base64);
            torbutton_log(2, "Made Cert: "+checkCert.organization);

            try {
                switch(type) {
                    case Components.interfaces.nsIX509Cert.EMAIL_CERT:
                        certdb.importEmailCertificate(bytes, bytes.length, null);
                        break;
                    case Components.interfaces.nsIX509Cert.SERVER_CERT:
                        certdb.importServerCertificate(bytes, bytes.length, null);
                        break;
                    case Components.interfaces.nsIX509Cert.USER_CERT:
                        certdb.importUserCertificate(bytes, bytes.length, null);
                        break;
                    case Components.interfaces.nsIX509Cert.CA_CERT:
                        certdb.importCertificates(bytes, bytes.length, type, null);
                        break;
                }
            
                certdb.setCertTrust(checkCert, type, trustBits);

            } catch(e) {
                torbutton_log(5, "Failed to import cert: "+checkCert.organization+": "+e);
            }

            unjared_certs++;
        }
        if(type == Components.interfaces.nsIX509Cert.CA_CERT) {
            m_tb_prefs.setBoolPref("extensions.torbutton.block_cert_dialogs", 
                    false);
        }

        torbutton_log(2, "Read "+unjared_certs+" "+name+" certificates from "+inFile.path);
    }

    bstream.close();
    istream.close();

    return unjared_certs;
}

function torbutton_jar_certs(mode) {
    var tot_certs = 0;
    var certCache = 
        Components.classes["@mozilla.org/security/nsscertcache;1"]
                    .getService(Components.interfaces.nsINSSCertCache);

    var serverTreeView = 
        Components.classes["@mozilla.org/security/nsCertTree;1"]
         .createInstance(Components.interfaces.nsICertTree);
    var emailTreeView = Components.classes["@mozilla.org/security/nsCertTree;1"]
        .createInstance(Components.interfaces.nsICertTree);
    var userTreeView = Components.classes["@mozilla.org/security/nsCertTree;1"]
        .createInstance(Components.interfaces.nsICertTree);
    var caTreeView = Components.classes["@mozilla.org/security/nsCertTree;1"]
        .createInstance(Components.interfaces.nsICertTree);

    torbutton_log(3, "Jaring certificates: "+mode);

    // backup cert8.db just in case..
    // XXX: Verify it actually is cert8.db on windows

    var dbfile = Components.classes["@mozilla.org/file/local;1"].
        createInstance(Components.interfaces.nsILocalFile); 

    var dir = Components.classes["@mozilla.org/file/directory_service;1"]
        .getService(Components.interfaces.nsIProperties)
        .get("ProfD", Components.interfaces.nsIFile);

    dbfile.initWithPath(dir.path);
    dbfile.append("cert8.db.bak");

    if(!dbfile.exists()) {
        torbutton_log(4, "Backing up certificates from "+dbfile.path);
        dbfile.initWithPath(dir.path);
        dbfile.append("cert8.db");
        dbfile.copyTo(dir, "cert8.db.bak");
        torbutton_log(4, "Backed up certificates to "+dbfile.path+".bak");
    }

    certCache.cacheAllCerts();
    serverTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.SERVER_CERT);
    emailTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);
    userTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.USER_CERT);
    caTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.CA_CERT);

    if(m_tb_prefs.getBoolPref("extensions.torbutton.jar_ca_certs")) {
        torbutton_jar_cert_type(mode, caTreeView, "ca", 
                Components.interfaces.nsIX509Cert.CA_CERT);
    }
    torbutton_jar_cert_type(mode, userTreeView, "user", 
            Components.interfaces.nsIX509Cert.USER_CERT);
    torbutton_jar_cert_type(mode, emailTreeView, "email", 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);
    torbutton_jar_cert_type(mode, serverTreeView, "server", 
            Components.interfaces.nsIX509Cert.SERVER_CERT);
    
    certCache.cacheAllCerts();
    serverTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.SERVER_CERT);
    if(serverTreeView.selection)
        serverTreeView.selection.clearSelection();
    
    emailTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);
    if(emailTreeView.selection)
        emailTreeView.selection.clearSelection();
    
    userTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.USER_CERT);
    if(userTreeView.selection)
        userTreeView.selection.clearSelection();
    
    caTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.CA_CERT);
    if(caTreeView.selection)
        caTreeView.selection.clearSelection();

    var certdb = Components.classes["@mozilla.org/security/x509certdb;1"]
                    .getService(Components.interfaces.nsIX509CertDB2);
    certdb.QueryInterface(Components.interfaces.nsIX509CertDB);

    certCache.cacheAllCerts();
    serverTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.SERVER_CERT);
    if(serverTreeView.selection)
        serverTreeView.selection.clearSelection();
    
    emailTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);
    if(emailTreeView.selection)
        emailTreeView.selection.clearSelection();
    
    userTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.USER_CERT);
    if(userTreeView.selection)
        userTreeView.selection.clearSelection();
    
    caTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.CA_CERT);
    if(caTreeView.selection)
        caTreeView.selection.clearSelection();


    if(m_tb_prefs.getBoolPref("extensions.torbutton.jar_ca_certs")) {
        if(torbutton_unjar_cert_type(mode, caTreeView, "ca", 
                Components.interfaces.nsIX509Cert.CA_CERT) == 0) {
            // arma thinks this not worth even asking. He is probably right.
            m_tb_prefs.setBoolPref("extensions.torbutton.jar_ca_certs",
                    false);
        }
    }
    torbutton_unjar_cert_type(mode, userTreeView, "user", 
            Components.interfaces.nsIX509Cert.USER_CERT);
    torbutton_unjar_cert_type(mode, emailTreeView, "email", 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);

    // XXX: on FF3, somehow CA certs get loaded into server pane on 
    // reload
    torbutton_unjar_cert_type(mode, serverTreeView, "server", 
            Components.interfaces.nsIX509Cert.SERVER_CERT);


    certCache.cacheAllCerts();
    serverTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.SERVER_CERT);
    if(serverTreeView.selection)
        serverTreeView.selection.clearSelection();
    
    emailTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.EMAIL_CERT);
    if(emailTreeView.selection)
        emailTreeView.selection.clearSelection();
    
    userTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.USER_CERT);
    if(userTreeView.selection)
        userTreeView.selection.clearSelection();
    
    caTreeView.loadCertsFromCache(certCache, 
            Components.interfaces.nsIX509Cert.CA_CERT);
    if(caTreeView.selection)
        caTreeView.selection.clearSelection();

}


// -------------- JS/PLUGIN HANDLING CODE ---------------------

function torbutton_check_js_tag(browser, tor_enabled, js_enabled) {
    if (typeof(browser.__tb_tor_fetched) == 'undefined') {
        try {
            torbutton_log(5, "UNTAGGED WINDOW at: "+browser.src);
        } catch(e) {
            torbutton_log(5, "UNTAGGED WINDOW: "+e);
        }
        // Defensive programming to tag this window here to 
        // an alternate tor state. It wil lmake this window totally
        // useless, but that is better than some undefined state
        browser.__tb_tor_fetched = !tor_enabled;
    }

    if(browser.__tb_tor_fetched == tor_enabled) { // States match, js ok 
        browser.docShell.allowJavascript = js_enabled;
    } else { // States differ or undefined, js not ok 
        browser.docShell.allowJavascript = false;
    }
}

function torbutton_toggle_win_jsplugins(win, tor_enabled, js_enabled, isolate_dyn, 
                                        kill_plugins) {
    var browser = win.getBrowser();
    var browsers = browser.browsers;
    torbutton_log(1, "Toggle window plugins");

    for (var i = 0; i < browsers.length; ++i) {
        var b = browser.browsers[i];
        if (b && !b.docShell) {
            try {
                if (b.currentURI) 
                    torbutton_log(5, "DocShell is null for: "+b.currentURI.spec);
                else 
                    torbutton_log(5, "DocShell is null for unknown URL");
            } catch(e) {
                torbutton_log(5, "DocShell is null for unparsable URL: "+e);
            }
        }
        if (b && b.docShell) {
            // Only allow plugins if the tab load was from an 
            // non-tor state and the current tor state is off.
            if(kill_plugins) 
                b.docShell.allowPlugins = !b.__tb_tor_fetched && !tor_enabled;
            else 
                b.docShell.allowPlugins = true;
            
            if(isolate_dyn) {
                torbutton_check_js_tag(b, tor_enabled, js_enabled);
                // kill meta-refresh and existing page loading 
                b.webNavigation.stop(b.webNavigation.STOP_ALL);
            }
        }
    }
}

// This is an ugly beast.. But unfortunately it has to be so..
// Looping over all tabs twice is not somethign we wanna do..
function torbutton_toggle_jsplugins(tor_enabled, isolate_dyn, kill_plugins) {
    torbutton_log(1, "Toggle plugins for: "+tor_enabled);
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                       .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("navigator:browser");
    var js_enabled = m_tb_prefs.getBoolPref("javascript.enabled");
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        torbutton_toggle_win_jsplugins(win, tor_enabled, js_enabled, isolate_dyn, 
                                       kill_plugins);   
    }
}

function tbHistoryListener(browser) {
    this.browser = browser;

    var o_stringbundle = torbutton_get_stringbundle();
    var warning = o_stringbundle.GetStringFromName("torbutton.popup.history.warning");

    this.f1 = function() {
        // Block everything unless we've reached steady state
        if((this.browser.__tb_tor_fetched != m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"))
                || (this.browser.__tb_tor_fetched != m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied"))
                && m_tb_prefs.getBoolPref("extensions.torbutton.block_js_history")) {
            torbutton_log(3, "Blocking history manipulation");
            window.alert(warning);
            return false;
        } else {
            return true;
        }
    };
}

tbHistoryListener.prototype = {
    QueryInterface: function(iid) {
        // XXX: Is this the right way to handle weak references from JS?
        if(iid.equals(Components.interfaces.nsISHistoryListener) || 
                iid.equals(Components.interfaces.nsISupports) ||
                iid.equals(Components.interfaces.nsISupportsWeakReference))
            return this;
        else
            return null;
    },

    OnHistoryGoBack: function(url) { return this.f1(); },
    OnHistoryGoForward: function(url) { return this.f1(); },
    OnHistoryGotoIndex: function(idx, url) { return this.f1(); }, 
    OnHistoryNewEntry: function(url) { return true; },
    OnHistoryPurge: function(ents) { return true; },
    OnHistoryReload: function(uri,flags) { return this.f1(); }
};

function torbutton_tag_new_browser(browser, tor_tag, no_plugins) {
    if (!tor_tag && no_plugins) {
        browser.docShell.allowPlugins = tor_tag;
    }

    // Only tag new windows
    if (typeof(browser.__tb_tor_fetched) == 'undefined') {
        torbutton_log(3, "Tagging new window: "+tor_tag);
        browser.__tb_tor_fetched = !tor_tag;

        // XXX: Do we need to remove this listener on tab close?
        var hlisten = new tbHistoryListener(browser);

        var sessionSetter = function() {
            if(!browser.webNavigation.sessionHistory) {
                torbutton_log(4, "Still failed to add historyListener!");
            }
            browser.webNavigation.sessionHistory.addSHistoryListener(hlisten);
            browser.__tb_hlistener = hlisten;
            torbutton_log(2, "Added history listener");
        }
        
        if(browser.webNavigation.sessionHistory) {
            sessionSetter();
        } else {
            torbutton_log(3, "Delayed session setter");
            window.setTimeout(sessionSetter, 500); 
        }
    }
}

function torbutton_conditional_set(state) {
    if (!m_tb_wasinited) torbutton_init();
    var no_plugins = m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins");
            
    torbutton_log(3, "Conditional set");
    
    // Need to set the tag on all tabs, some of them can be mis-set when
    // the first window is created (before session restore)
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
                       .getService(Components.interfaces.nsIWindowMediator);
    var enumerator = wm.getEnumerator("navigator:browser");
    var js_enabled = m_tb_prefs.getBoolPref("javascript.enabled");
    while(enumerator.hasMoreElements()) {
        var win = enumerator.getNext();
        var browser = win.getBrowser();
        var browsers = browser.browsers;

        for (var i = 0; i < browsers.length; ++i) {
            var b = browser.browsers[i];

            if (!state && no_plugins) {
                if(b && b.docShell){
                    b.docShell.allowPlugins = false;
                } else {
                    try {
                        if (b && b.currentURI) 
                            torbutton_log(5, "Initial docShell is null for: "+b.currentURI.spec);
                        else 
                            torbutton_log(5, "Initial docShell is null for unknown URL");
                    } catch(e) {
                        torbutton_log(5, "Initial docShell is null for unparsable URL: "+e);
                    }
                } 
            }
            b.__tb_tor_fetched = state;
        }
    }

    torbutton_log(4, "Restoring tor state");
    if (torbutton_check_status() == state) return;
    
    if(state) torbutton_enable_tor(true);
    else  torbutton_disable_tor();
}

function torbutton_restore_cookies()
{
    var selector =
          Components.classes["@stanford.edu/cookie-jar-selector;1"]
                    .getService(Components.interfaces.nsISupports)
                    .wrappedJSObject;
    torbutton_log(4, "Restoring cookie status");
    selector.clearCookies();
    
    if(m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")) {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars')) {
            torbutton_log(4, "Loading tor jar after crash");
            selector.loadCookies("tor", false);
        }
    } else {
        if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars')
                || m_tb_prefs.getBoolPref('extensions.torbutton.cookie_jars')) {
            torbutton_log(4, "Loading non-tor jar after crash");
            selector.loadCookies("nontor", false);
        }
    }
}

function torbutton_crash_recover()
{
    if (!m_tb_wasinited) torbutton_init();
    torbutton_log(3, "Crash recover check");

    // Crash detection code (works w/ components/crash-observer.js)
    if(m_tb_prefs.getBoolPref("extensions.torbutton.crashed")) {
        // This may run on first install and wipe the user's cookies
        // It may also run on upgrade
        try {
            if(m_tb_prefs.getBoolPref("extensions.torbutton.normal_exit")) {
                m_tb_prefs.setBoolPref("extensions.torbutton.normal_exit", false);
                m_tb_prefs.setBoolPref("extensions.torbutton.crashed", false);
                torbutton_log(3, "False positive crash recovery. Setting tor state");
                if(m_tb_prefs.getBoolPref("extensions.torbutton.restore_tor"))
                    torbutton_conditional_set(true);
                else
                    torbutton_conditional_set(false);
                return;
            }
        } catch(e) {
            torbutton_log(4, "Exception on crash check: "+e);
        }

        torbutton_log(4, "Crash detected, attempting recovery");
        var state = torbutton_check_status();
        if(state != m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                || state != m_tb_prefs.getBoolPref("extensions.torbutton.proxies_applied")
                || state != m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied")) {
            var te = m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled");
            var pa = m_tb_prefs.getBoolPref("extensions.torbutton.proxies_applied");
            var sa = m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied");
            // XXX: This did happen once in the wild. We should
            // probably write some code to carefully recover user's
            // prefs that were touched by Tor.
            window.alert("Torbutton crash state conflict! Please file bug report with these four values: "
                    +state+","+te+","+pa+","+sa);
            torbutton_log(5, "Crash state conflict: "+state+","
                    +te+","+pa+","+sa);
        }

        // FIXME: consider trying to check these to see what work we may 
        // need to redo?
        m_tb_prefs.setBoolPref("extensions.torbutton.tor_enabled", state);
        m_tb_prefs.setBoolPref("extensions.torbutton.proxies_applied", state);
        m_tb_prefs.setBoolPref("extensions.torbutton.settings_applied", state);
      
        // Do the restore cookies first because we potentially save
        // cookies by toggling tor state in the next pref. If we
        // do this first, we can be sure we have the 'right' cookies
        // currently loaded before the switch writes out a new jar
        if(m_tb_prefs.getBoolPref("extensions.torbutton.reload_crashed_jar"))
            torbutton_restore_cookies();

        if(m_tb_prefs.getBoolPref("extensions.torbutton.restore_tor"))
            torbutton_conditional_set(true);
        else
            torbutton_conditional_set(false);
        m_tb_prefs.setBoolPref("extensions.torbutton.crashed", false);
    }

    torbutton_log(3, "End crash recover check");
}


// ---------------------- Event handlers -----------------

// Technique courtesy of:
// http://xulsolutions.blogspot.com/2006/07/creating-uninstall-script-for.html
const TORBUTTON_EXTENSION_UUID = "{E0204BD5-9D31-402B-A99D-A6AA8FFEBDCA}";
var torbutton_uninstall_observer = {
_uninstall : false,
observe : function(subject, topic, data) {
  if (topic == "em-action-requested") {
    subject.QueryInterface(Components.interfaces.nsIUpdateItem);
    torbutton_log(2, "Uninstall: "+data+" "+subject.id.toUpperCase());

    if (subject.id.toUpperCase() == TORBUTTON_EXTENSION_UUID) {
      torbutton_log(2, "Uninstall: "+data);
      if (data == "item-uninstalled" || data == "item-disabled") {
        this._uninstall = true;
      } else if (data == "item-cancel-action") {
        this._uninstall = false;
      }
    }

  } else if (topic == "quit-application-granted") {
    if (this._uninstall) {
        torbutton_disable_tor();
    }

    // Set pref in case this is just an upgrade (So we don't
    // mess with cookies)
    torbutton_log(2, "Torbutton normal exit");
    m_tb_prefs.setBoolPref("extensions.torbutton.normal_exit", true);
    m_tb_prefs.setBoolPref("extensions.torbutton.crashed", false);
    m_tb_prefs.setBoolPref("extensions.torbutton.noncrashed", false);

    if((m_tb_prefs.getIntPref("extensions.torbutton.shutdown_method") == 1 && 
        m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"))
        || m_tb_prefs.getIntPref("extensions.torbutton.shutdown_method") == 2) {
        var selector =
            Components.classes["@stanford.edu/cookie-jar-selector;1"]
            .getService(Components.interfaces.nsISupports)
            .wrappedJSObject;
        selector.clearCookies();
        // clear the cookie jar by saving the empty cookies to it.
        if(m_tb_prefs.getIntPref("extensions.torbutton.shutdown_method") == 2) {
            if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars'))
                selector.saveCookies("tor");
            selector.saveCookies("nontor");
        } else if(m_tb_prefs.getBoolPref('extensions.torbutton.dual_cookie_jars')) {
            selector.saveCookies("tor");
        }
    }
    this.unregister();
  }
},
register : function() {
 var observerService =
   Components.classes["@mozilla.org/observer-service;1"].
     getService(Components.interfaces.nsIObserverService);
 torbutton_log(3, "Observer register");

 observerService.addObserver(this, "em-action-requested", false);
 observerService.addObserver(this, "quit-application-granted", false);
 torbutton_log(3, "Observer register");
},
unregister : function() {
  var observerService =
    Components.classes["@mozilla.org/observer-service;1"].
      getService(Components.interfaces.nsIObserverService);

  observerService.removeObserver(this,"em-action-requested");
  observerService.removeObserver(this,"quit-application-granted");
}
}

// This observer is to catch some additional http load events
// to deal with firefox bug 401296
// TODO: One of these days we should probably unify these http observers
// with our content policy, like NoScript does.
var torbutton_http_observer = {
observe : function(subject, topic, data) {
  torbutton_eclog(2, 'Examine response: '+subject.name);
  if (((subject instanceof Components.interfaces.nsIHttpChannel)
      && !(subject.loadFlags & Components.interfaces.nsIChannel.LOAD_DOCUMENT_URI))) {
      // FIXME: FF3 no longer calls the contet policy for favicons. 
      // This is the workaround. Fun fun fun.
      if(m_tb_ff3 && subject.notificationCallbacks) {
          try {
              var wind = subject.notificationCallbacks.QueryInterface(
                      Components.interfaces.nsIInterfaceRequestor).getInterface(
                          Components.interfaces.nsIDOMWindow);

              if(wind instanceof Components.interfaces.nsIDOMChromeWindow) {
                  if(wind.browserDOMWindow) {
                      var browser = wind.getBrowser().selectedTab.linkedBrowser;
                      // This can happen in the first request of a new state.
                      // block favicons till we've reach steady state
                      if((typeof(browser.__tb_tor_fetched) != "undefined")
                        && (browser.__tb_tor_fetched != 
                              m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                              || browser.__tb_tor_fetched != m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied"))) {
                          subject.cancel(0x804b0002); // NS_BINDING_ABORTED
                          torbutton_eclog(3, 'Cancelling opposing (favicon?) request: '+subject.name);
                      }
                  }
              }
          } catch(e) {
              torbutton_eclog(2, 'Failure cancelling opposing (favicon?) request '+subject.name+': '+e);
          }
      }
      return;
  }
  if(!(subject instanceof Components.interfaces.nsIHttpChannel)) {
      torbutton_eclog(2, 'Non-http request '+subject.name);
  }

  if (topic == "http-on-examine-response") {
      torbutton_eclog(3, 'Definitaly Examine response: '+subject.name);
      torbutton_check_progress(null, subject, 0);
  } else if (topic == "http-on-modify-request") {
      torbutton_eclog(3, 'Modify request: '+subject.name);
  }
},
register : function() {
 var observerService =
   Components.classes["@mozilla.org/observer-service;1"].
     getService(Components.interfaces.nsIObserverService);
 torbutton_log(3, "Observer register");

 observerService.addObserver(this, "http-on-modify-request", false);
 observerService.addObserver(this, "http-on-examine-response", false);
 torbutton_log(3, "Observer register");
},
unregister : function() {
  var observerService =
    Components.classes["@mozilla.org/observer-service;1"].
      getService(Components.interfaces.nsIObserverService);

  observerService.removeObserver(this,"http-on-modify-request");
  observerService.removeObserver(this,"http-on-examine-response");
}
}


function torbutton_do_main_window_startup()
{
    torbutton_log(3, "Torbutton main window startup");
    m_tb_is_main_window = true;

    // http://www.xulplanet.com/references/xpcomref/ifaces/nsIWebProgress.html
    var progress =
        Components.classes["@mozilla.org/docloaderservice;1"].
        getService(Components.interfaces.nsIWebProgress);

    progress.addProgressListener(torbutton_weblistener,
            //   Components.interfaces.nsIWebProgress.NOTIFY_STATE_ALL|
            //   Components.interfaces.nsIWebProgress.NOTIFY_ALL);
        Components.interfaces.nsIWebProgress.NOTIFY_STATE_DOCUMENT|
            Components.interfaces.nsIWebProgress.NOTIFY_LOCATION);

    torbutton_unique_pref_observer.register();
    torbutton_uninstall_observer.register();
    torbutton_http_observer.register();
}

function torbutton_set_initial_state() {
    if(m_tb_prefs.getBoolPref("extensions.torbutton.noncrashed")) {
        try {
            if(m_tb_prefs.getBoolPref("extensions.torbutton.normal_exit")) {
                m_tb_prefs.setBoolPref("extensions.torbutton.normal_exit", false);
            } else {
                // This happens if user decline to restore sessions after crashes
                torbutton_log(4, "Conflict between noncrashed and normal_exit states.. Assuming crash but no session restore..");
                m_tb_prefs.setBoolPref("extensions.torbutton.noncrashed", false);

                // This will cause torbutton_crash_recover to get called:
                m_tb_prefs.setBoolPref("extensions.torbutton.crashed", true);
                return;
            }
        } catch(e) {
            torbutton_log(4, "Exception on noncrashed check: "+e);
        }

        var startup_state = m_tb_prefs.getIntPref("extensions.torbutton.startup_state");
        
        torbutton_log(3, "Setting initial state to: "+startup_state);

        if(startup_state == 0) {
            torbutton_conditional_set(false); // must be boolean
        } else if(startup_state == 1) {
            torbutton_conditional_set(true);
        } // 2 means leave it as it was

        m_tb_prefs.setBoolPref("extensions.torbutton.noncrashed", false);
    }
}

function torbutton_do_fresh_install() 
{
    if(m_tb_prefs.getBoolPref("extensions.torbutton.fresh_install")) {
        // Set normal_exit, because the session store will soon run and
        // cause us to think a crash happened
        m_tb_prefs.setBoolPref("extensions.torbutton.normal_exit", true);

        if(!m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")) {
            // Make our cookie prefs more closely match the user's 
            // so we don't change people's settings on install.
            if(m_tb_prefs.getIntPref("network.cookie.lifetimePolicy") == 2) {
                m_tb_prefs.setBoolPref("extensions.torbutton.nontor_memory_jar", 
                        true);
            }
            // perform updates in ff3 if the user's non-tor prefs allow it
            if(m_tb_ff3 && m_tb_prefs.getBoolPref("app.update.auto")
                    && m_tb_prefs.getBoolPref("extensions.update.enabled")) {
                m_tb_prefs.setBoolPref("extensions.torbutton.no_updates", false);
            }
        } else {
            // Punt. Allow updates via Tor now.
            if(m_tb_ff3) {
                // Perform updates if FF3. They are secure now.
                m_tb_prefs.setBoolPref("extensions.torbutton.no_updates", false);
            }
        }

        m_tb_prefs.setBoolPref("extensions.torbutton.fresh_install", false);

        torbutton_log(4, "First time startup completed");
    }
}

function torbutton_do_startup()
{
    if(m_tb_prefs.getBoolPref("extensions.torbutton.startup")) {
        // Do this before the unique pref observer is registered
        // in torbutton_do_main_window_startup to avoid
        // popup notification.
        torbutton_do_fresh_install();
       
        torbutton_do_main_window_startup();

        // This is due to Bug 908: UserAgent Switcher is resetting
        // the user agent at startup to default
        if(m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                    && m_tb_prefs.getBoolPref("extensions.torbutton.set_uagent")) {
            torbutton_set_uagent();
        }

        torbutton_set_timezone(torbutton_check_status(), true);

        // XXX: This is probably better done by reimplementing the 
        // component.
        if(m_tb_prefs.getBoolPref("extensions.torbutton.block_remoting")) {
            var appSupport = Cc["@mozilla.org/toolkit/native-app-support;1"]
                .getService(Ci.nsINativeAppSupport);
            if(!appSupport.stop()) {
                torbutton_log(5, "Remoting stop() failed. Forcing quit");
                // We really want this thing gone.
                appSupport.quit();
            } else {
                torbutton_log(3, "Remoting window closed.");
            }
        }
        
        m_tb_prefs.setBoolPref("extensions.torbutton.startup", false);
    }
}

function torbutton_get_plugin_mimetypes()
{
    m_tb_plugin_mimetypes = { null : null };
    var plugin_list = [];
    for(var i = 0; i < window.navigator.mimeTypes.length; ++i) {
        var mime = window.navigator.mimeTypes.item(i);
        if(mime && mime.enabledPlugin) {
            m_tb_plugin_mimetypes[mime.type] = true;
            plugin_list.push(mime.type);
        }
    }
    m_tb_plugin_string = plugin_list.join();
}


function torbutton_new_tab(event)
{ 
    // listening for new tabs
    torbutton_log(2, "New tab");

    var tor_tag = !m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled");
    var no_plugins = m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins");
    var browser = event.currentTarget;

    // Fucking garbage.. event is delivered to the current tab, not the 
    // newly created one. Need to traverse the current window for it.
    for (var i = 0; i < browser.browsers.length; ++i) {
        torbutton_tag_new_browser(browser.browsers[i], tor_tag, no_plugins);
    }
}

// Returns true if the window wind is neither maximized, full screen,
// ratpoisioned/evilwmed, nor minimized.
function torbutton_is_windowed(wind) {
    torbutton_log(2, "Window: ("+wind.outerHeight+","+wind.outerWidth+") ?= ("
            +wind.screen.availHeight+","+wind.screen.availWidth+")");
    if(wind.windowState == Components.interfaces.nsIDOMChromeWindow.STATE_MINIMIZED
      || wind.windowState == Components.interfaces.nsIDOMChromeWindow.STATE_MAXIMIZED) {
        torbutton_log(2, "Window is minimized/maximized");
        return false;
    }
    if ("fullScreen" in wind && wind.fullScreen) {
        torbutton_log(2, "Window is fullScreen");
        return false;
    }
    if(wind.outerHeight == wind.screen.availHeight 
            && wind.outerWidth == wind.screen.availWidth) {
        torbutton_log(3, "Window is ratpoisoned/evilwm'ed");
        return false;
    }
        
    torbutton_log(2, "Window is normal");
    return true;
}

function torbutton_do_resize(ev)
{
    if(m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
            && m_tb_prefs.getBoolPref("extensions.torbutton.resize_on_toggle")) {
        var bWin = window.getBrowser().contentWindow;
        // only resize if outer window size has changed (ignore stuff like
        // scrollbars and find bars)
        if((m_tb_window_height != window.outerHeight ||
                m_tb_window_width != window.outerWidth) && 
                torbutton_is_windowed(window)) {
            torbutton_log(3, "Resizing window on event: "+window.windowState);
            bWin.innerHeight = Math.round(bWin.innerHeight/50.0)*50;
            bWin.innerWidth = Math.round(bWin.innerWidth/50.0)*50;
        }
    }

    m_tb_window_height = window.outerHeight;
    m_tb_window_width = window.outerWidth;
}

function torbutton_check_round(browser) 
{
    // XXX: Not called???
    if(torbutton_is_windowed(window)
            && m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
            && m_tb_prefs.getBoolPref("extensions.torbutton.resize_on_toggle")) {
        
        if(Math.abs(browser.contentWindow.innerHeight - 
           Math.floor(Math.round(browser.contentWindow.innerHeight/50.0)*50))
           > 0.1) {
            if(m_tb_window_height < 100 && m_tb_window_width < 100) {
                torbutton_log(3, "Window size damn near zero: ("+
                        m_tb_window_height+", "+m_tb_window_width+")");
                m_tb_window_height = window.outerHeight;
                m_tb_window_width = window.outerWidth;
            } else {
                torbutton_log(3, "Restoring orig window size: "+window.windowState);
                window.outerHeight = m_tb_window_height;
                window.outerWidth = m_tb_window_width;
            }
        }

        // Always round.
        torbutton_log(3, "Resizing window on load: "+window.windowState);
        browser.contentWindow.innerHeight = Math.round(browser.contentWindow.innerHeight/50.0)*50;
        browser.contentWindow.innerWidth = Math.round(browser.contentWindow.innerWidth/50.0)*50;
    }
}

function torbutton_new_window(event)
{
    torbutton_log(3, "New window");
    var browser = getBrowser(); 

    m_tb_window_height = window.outerHeight;
    m_tb_window_width = window.outerWidth;

    if (!m_tb_wasinited) {
        torbutton_init();
    }
    
    torbutton_do_startup();
    torbutton_crash_recover();

    torbutton_get_plugin_mimetypes();

    torbutton_tag_new_browser(browser.browsers[0], 
            !m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled"),
            m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins"));

    window.addEventListener("resize", torbutton_do_resize, true);
}

function torbutton_close_window(event) {
    torbutton_window_pref_observer.unregister();

    // TODO: This is a real ghetto hack.. When the original window
    // closes, we need to find another window to handle observing 
    // unique events... The right way to do this is to move the 
    // majority of torbutton functionality into a XPCOM component.. 
    // But that is a major overhaul..
    if (m_tb_is_main_window) {
        torbutton_log(3, "Original window closed. Searching for another");
        var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
            .getService(Components.interfaces.nsIWindowMediator);
        var enumerator = wm.getEnumerator("navigator:browser");
        while(enumerator.hasMoreElements()) {
            var win = enumerator.getNext();
            if(win != window) {
                torbutton_log(3, "Found another window");
                win.torbutton_do_main_window_startup();
                m_tb_is_main_window = false;
                break;
            }
        }

        // remove old listeners
        var progress = Components.classes["@mozilla.org/docloaderservice;1"].
            getService(Components.interfaces.nsIWebProgress);

        progress.removeProgressListener(torbutton_weblistener);
        torbutton_unique_pref_observer.unregister();
        torbutton_uninstall_observer.unregister();
        torbutton_http_observer.unregister();

        if(m_tb_is_main_window) { // main window not reset above
            // This happens on Mac OS because they allow firefox
            // to still persist without a navigator window
            torbutton_log(3, "Last window closed. None remain.");
            m_tb_prefs.setBoolPref("extensions.torbutton.startup", true);
            m_tb_is_main_window = false;
        }
    }
}

window.addEventListener('load',torbutton_new_window,false);
window.addEventListener('unload', torbutton_close_window, false);
getBrowser().addEventListener("TabOpen", torbutton_new_tab, false);


// ----------- JAVASCRIPT HOOKING + EVENT HANDLERS ----------------

function torbutton_init_jshooks() {
    torbutton_log(2, "torbutton_init_jshooks()");
    var nsio = Components.classes["@mozilla.org/network/io-service;1"]
                .getService(Components.interfaces.nsIIOService);
    var chan = nsio.newChannel("chrome://torbutton/content/jshooks.js", 
                               null, null);
    var istream = Components.classes["@mozilla.org/scriptableinputstream;1"].
            createInstance(Components.interfaces.nsIScriptableInputStream);

    istream.init(chan.open());
    m_tb_jshooks = istream.read(istream.available());
    istream.close();
}

function torbutton_getbody(doc) {
    if (doc.body)
        return doc.body;
    else if (doc.documentElement)
        return doc.documentElement;
    return null;
}

/* This seems to be necessary due to javascript's
 * nebulous scoping/parsing/evaluations issues. Having this as
 * a standalone statement seems to cause the flag
 * to become defined after just parsing, not execution */
function torbutton_set_flag(obj, flag) {
    obj[flag] = true;
}

function torbutton_check_flag(obj, flag) {
    try {
        return (typeof(obj[flag]) != 'undefined');
    } catch(e) {
        torbutton_log(5, "Exception on flag "+flag+" check: "+e); 
        return true;
    }
}

function torbutton_is_same_origin(source, target) { // unused.
    var fixup = Components.classes["@mozilla.org/docshell/urifixup;1"]
        .getService(Components.interfaces.nsIURIFixup);
    var source = fixup.createFixupURI(win.top.location.href, 0);
    var target = fixup.createFixupURI(win.location.href, 0);

    var secmgr = Components.classes["@mozilla.org/scriptsecuritymanager;1"]
        .getService(Components.interfaces.nsIScriptSecurityManager);

    if(!source || !target) {
        torbutton_log(5, "Can't convert one of: "+win.document.location+", parent is: "+win.top.document.location);
    }

    // TODO: this doesn't work.. esp if document modifies document.domain
    // window.windowRoot instead? Also, prints an error message
    // to the error console..
    try {
        secmgr.checkSameOriginURI(source, target);
        torbutton_log(3, "Same-origin non-toplevel window: "+win.document.location+", parent is: "+win.top.document.location);
        win = win.top;
    } catch(e) {
        torbutton_log(3, "Exception w/ non-same-origin non-toplevel window: "+win.document.location+", parent is: "+win.top.document.location);
    }
}


function torbutton_update_tags(win) {
    torbutton_eclog(2, "Updating tags.");
    if(typeof(win.wrappedJSObject) == 'undefined') {
        torbutton_eclog(3, "No JSObject: "+win.location);
        return;
    }

    var wm = Components.classes["@torproject.org/content-window-mapper;1"]
        .getService(Components.interfaces.nsISupports)
        .wrappedJSObject;

    // Expire the cache on page loads. TODO: Do a timer instead.. 
    if(win == win.top) wm.expireOldCache();

    var browser = wm.getBrowserForContentWindow(win.top);
    if(!browser) {
        torbutton_log(5, "No window found!1");
        return;
        //win.alert("No window found!");
    }
    torbutton_log(2, "Got browser "+browser.contentWindow.location+" for: " 
            + win.location + ", under: "+win.top.location);

    // Base this tag off of proxies_applied, since we want to go
    // by whatever the actual load proxy was
    var tor_tag = !m_tb_prefs.getBoolPref("extensions.torbutton.proxies_applied");
    var js_enabled = m_tb_prefs.getBoolPref("javascript.enabled");
    var kill_plugins = m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins");

    if (!torbutton_check_flag(win.top, "__tb_did_tag")) {
        torbutton_log(2, "Tagging browser for: " + win.location);
        torbutton_set_flag(win.top, "__tb_did_tag");

        if(typeof(browser.__tb_tor_fetched) == "undefined") {
            torbutton_log(5, "Untagged browser at: "+win.location);
            // Defensive programming to tag this window here to 
            // an alternate tor state. It wil lmake this window totally
            // useless, but that is better than some undefined state
            browser.__tb_tor_fetched = tor_tag;
        } 
        if(browser.__tb_tor_fetched != !tor_tag) {
            // Purge session history every time we fetch a new doc 
            // in a new tor state
            torbutton_log(2, "Purging session history");
            if(browser.webNavigation.sessionHistory.count > 1
                    && m_tb_prefs.getBoolPref("extensions.torbutton.block_js_history")) {
                // XXX: This isn't quite right.. For some reason
                // this breaks in some cases..
                /*
                var current = browser.webNavigation
                    .QueryInterface(Components.interfaces.nsIDocShellHistory)
                    .getChildSHEntry(0).clone(); // XXX: Use index??
                    */
                var current = browser.webNavigation.contentViewer.historyEntry;

                browser.webNavigation.sessionHistory.PurgeHistory(
                        browser.webNavigation.sessionHistory.count);

                if(current) {
                    // Add current page back in
                    browser.webNavigation
                        .QueryInterface(Components.interfaces.nsISHistoryInternal)
                        .addChildSHEntry(current, true);
                }
            }
        }

        browser.__tb_tor_fetched = !tor_tag;
        browser.docShell.allowPlugins = tor_tag || !kill_plugins;
        if(js_enabled && !browser.docShell.allowJavascript) {
            // Only care about re-enabling javascript. 
            // The js engine obeys the pref over the docshell attribute
            // for disabling js, and this is the source of a conflict with
            // NoScript
            torbutton_log(3, "Javascript changed from "+browser.docShell.allowJavascript+" to: "+js_enabled);
            browser.docShell.allowJavascript = js_enabled;
            torbutton_check_round(browser);
            // JS was not fully enabled for some page elements. 
            // Need to reload
            browser.reload(); 
        } else {
            // We need to do the resize here as well in case the window
            // was minimized during toggle...
            torbutton_check_round(browser);
        }
    }

    torbutton_log(2, "Tags updated.");
}

// XXX: Same-origin policy may prevent our hooks from applying
// to inner iframes.. Test with frames, iframes, and
// popups. Test these extensively:
// http://taossa.com/index.php/2007/02/08/same-origin-policy/
//  - http://www.htmlbasix.com/popup.shtml
//  - http://msdn2.microsoft.com/en-us/library/ms531202.aspx
//  - Url-free: http://www.yourhtmlsource.com/javascript/popupwindows.html#accessiblepopups
//    - Blocked by default (tho perhaps only via onload). 
//      see popup blocker detectors:
//      - http://javascript.internet.com/snippets/popup-blocker-detection.html
//      - http://www.visitor-stats.com/articles/detect-popup-blocker.php 
//      - http://www.dynamicdrive.com/dynamicindex8/dhtmlwindow.htm
//  - popup blocker tests:
//    - http://swik.net/User:Staple/JavaScript+Popup+Windows+Generation+and+Testing+Tutorials
//  - pure javascript pages/non-text/html pages
//  - Messing with variables/existing hooks
function torbutton_hookdoc(win, doc) {
    if(typeof(win.wrappedJSObject) == 'undefined') {
        torbutton_eclog(3, "No JSObject: "+win.location);
        return;
    }

    torbutton_log(2, "Hooking document: "+win.location);
    if(doc && doc.doctype) {
        torbutton_log(2, "Type: "+doc.doctype.name);
    }
    
    var js_enabled = m_tb_prefs.getBoolPref("javascript.enabled");

    // No need to hook js if tor is off
    if(!js_enabled 
            || !m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled") 
            || !m_tb_prefs.getBoolPref('extensions.torbutton.kill_bad_js')) {
        torbutton_log(2, "Finished non-hook of: " + win.location);
        return;
    }

    // Date Hooking:

    /* Q: Do this better with XPCOM?
     *    http://www.mozilla.org/projects/xpcom/nsIClassInfo.html
     * A: Negatory.. Date() is not an XPCOM component :(
     */
    
    // So it looks like the race condition is actually a result of
    // the insertion function returning before the injected code is evaluated.
    // This code seems to do what we want.

    var str2 = "";
    if(m_tb_ff3) {
        str2 += "window.__tb_set_uagent=false;\r\n";
        str2 += "window.__tb_hook_date=false;\r\n";
    } else {
        str2 += "window.__tb_hook_date=true;\r\n";
        if(m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins")) {
            str2 += "window.__tb_set_uagent="+m_tb_prefs.getBoolPref('extensions.torbutton.set_uagent')+";\r\n";
        } else {
            // Abandon ship on user agent spoofing if user wants plugins.
            // OS+platform can be obtained from plugins anyways, and complications
            // with XPCNativeWrappers makes it hard to provide
            // plugin information in window.navigator properly with plugins
            // enabled.
            str2 += "window.__tb_set_uagent=false;\r\n";
        }
        if(m_tb_prefs.getBoolPref("extensions.torbutton.spoof_english")) {
            str2 += "window.__tb_locale=\""+m_tb_prefs.getCharPref('extensions.torbutton.spoof_locale')+"\";\r\n";
        } else {
            str2 += "window.__tb_locale=false;\r\n";
        }
        str2 += "window.__tb_oscpu=\""+m_tb_prefs.getCharPref('extensions.torbutton.oscpu_override')+"\";\r\n";
        str2 += "window.__tb_platform=\""+m_tb_prefs.getCharPref('extensions.torbutton.platform_override')+"\";\r\n";
        str2 += "window.__tb_productSub=\""+m_tb_prefs.getCharPref('extensions.torbutton.productsub_override')+"\";\r\n";
    }
    str2 += m_tb_jshooks;

    try {
        torbutton_log(2, "Type of window: " + typeof(win));
        torbutton_log(2, "Type of wrapped window: " + typeof(win.wrappedJSObject));
        var s = new Components.utils.Sandbox(win.wrappedJSObject);
        // XXX: FF3 issues 
        // http://developer.mozilla.org/en/docs/XPConnect_wrappers#XPCSafeJSObjectWrapper
        // http://developer.mozilla.org/en/docs/Code_snippets:Interaction_between_privileged_and_non-privileged_pages
        s.window = win.wrappedJSObject; 
//        s.__proto__ = win.wrappedJSObject;
        //var result = Components.utils.evalInSandbox('var origDate = Date; window.alert(new origDate())', s);
        //result = 23;
        var result = Components.utils.evalInSandbox(str2, s);
        if(result === 23) { // secret confirmation result code.
            torbutton_log(3, "Javascript hooks applied successfully at: " + win.location);
        } else if(result === 13) {
            torbutton_log(3, "Double-hook at: " + win.location);
        } else {
            window.alert("Torbutton Sandbox evaluation failed. Date hooks not applied!");
            torbutton_log(5, "Hook evaluation failure at " + win.location);
        }
    } catch (e) {
        window.alert("Torbutton Exception in sandbox evaluation. Date hooks not applied:\n"+e);
        torbutton_log(5, "Hook exception at: "+win.location+", "+e);
    }

    torbutton_log(2, "Finished hook: " + win.location);

    return;
}

// XXX: Tons of exceptions get thrown from this function on account
// of its being called so early. Need to find a quick way to check if
// aProgress and aRequest are actually fully initialized 
// (without throwing exceptions)
function torbutton_check_progress(aProgress, aRequest, aFlags) {
    if (!m_tb_wasinited) {
        torbutton_init();
    }

    var DOMWindow = null;

    // Bug #866: Zotero conflict with about:blank windows
    // handle docshell JS switching and other early duties
    var WP_STATE_START = Ci.nsIWebProgressListener.STATE_START;
    var WP_STATE_DOC = Ci.nsIWebProgressListener.STATE_IS_DOCUMENT;
    var WP_STATE_START_DOC = WP_STATE_START | WP_STATE_DOC;

    if ((aFlags & WP_STATE_START_DOC) == WP_STATE_START_DOC 
            && aRequest instanceof Ci.nsIChannel
            && !(aRequest.loadFlags & aRequest.LOAD_INITIAL_DOCUMENT_URI) 
            && aRequest.URI.spec == "about:blank") { 
        torbutton_log(3, "Passing on about:blank");
        return 0;
    }

    if(aProgress) {
        try {
            DOMWindow = aProgress.DOMWindow;
        } catch(e) {
            torbutton_log(4, "Exception on DOMWindow: "+e);
            DOMWindow = null;
        }
    } 

    if(!DOMWindow) {
        try {
            if(aRequest.notificationCallbacks) {
                DOMWindow = aRequest.notificationCallbacks.QueryInterface(
                        Components.interfaces.nsIInterfaceRequestor).getInterface(
                            Components.interfaces.nsIDOMWindow);
            }
        } catch(e) { }
    }
    
    // FIXME if intstanceof nsIHttpChannel check headers for 
    // Content-Disposition..

    // This noise is a workaround for firefox bugs involving
    // enforcement of docShell.allowPlugins and docShell.allowJavascript
    // (Bugs 401296 and 409737 respectively) 
    try {
        if(aRequest) {
            var chanreq = aRequest.QueryInterface(Components.interfaces.nsIChannel);
            if(chanreq
                    && chanreq instanceof Components.interfaces.nsIChannel
                    && aRequest.isPending()) {

                try { torbutton_eclog(2, 'Pending request: '+aRequest.name); }
                catch(e) { }

                if(DOMWindow && DOMWindow.opener 
                        && m_tb_prefs.getBoolPref("extensions.torbutton.isolate_content")) {

                    try { torbutton_eclog(3, 'Popup request: '+aRequest.name); } 
                    catch(e) { }

                    if(!(DOMWindow.top instanceof Components.interfaces.nsIDOMChromeWindow)) {
                        // Workaround for Firefox bug 409737
                        // The idea is that the content policy should stop all
                        // forms of javascript fetches except for popups. This
                        // code handles blocking popups from alternate tor states.
                        var wm = Components.classes["@torproject.org/content-window-mapper;1"]
                            .getService(Components.interfaces.nsISupports)
                            .wrappedJSObject;

                        var browser = wm.getBrowserForContentWindow(DOMWindow.opener);
                        torbutton_eclog(3, 'Got browser for request: ' + (browser != null));

                        // XXX: This may block ssl popups in the first tab
                        if(browser && 
                                (browser.__tb_tor_fetched != m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                                 || browser.__tb_tor_fetched != m_tb_prefs.getBoolPref("extensions.torbutton.settings_applied"))) {
                            try {
                                torbutton_eclog(3, 'Stopping document: '+DOMWindow.location);
                                aRequest.cancel(0x804b0002); // NS_BINDING_ABORTED
                                DOMWindow.stop();
                                torbutton_eclog(3, 'Stopped document: '+DOMWindow.location);
                                DOMWindow.document.clear();
                                torbutton_eclog(3, 'Cleared document: '+DOMWindow.location);
                            } catch(e) { 
                            } 
                            torbutton_eclog(4, 'Torbutton blocked state-changed popup');
                            DOMWindow.close();
                            return 0;
                        }
                    }
                }

                torbutton_eclog(2, 'LocChange: '+aRequest.contentType);

                // Workaround for Firefox Bug 401296
                if((m_tb_prefs.getBoolPref("extensions.torbutton.tor_enabled")
                            && m_tb_prefs.getBoolPref("extensions.torbutton.no_tor_plugins")
                            && aRequest.contentType in m_tb_plugin_mimetypes)) {
                    aRequest.cancel(0x804b0002); // NS_BINDING_ABORTED
                    var o_stringbundle = torbutton_get_stringbundle();
                    var warning = o_stringbundle.GetStringFromName("torbutton.popup.plugin.warning");
                    if(DOMWindow) {
                        // ZOMG DIE DIE DXIE!!!!!@
                        try {
                            DOMWindow.stop();
                            torbutton_eclog(2, 'Stopped document');
                            DOMWindow.document.clear();
                            torbutton_eclog(2, 'Cleared document');

                            if(typeof(DOMWindow.__tb_kill_flag) == 'undefined') {
                                window.alert(warning);
                                DOMWindow.__tb_kill_flag = true;
                            }
                            // This doesn't seem to actually remove the child..
                            // It usually just causes an exception to be thrown,
                            // which strangely enough, actually does finally 
                            // kill the plugin.
                            DOMWindow.document.removeChild(
                                    DOMWindow.document.firstChild);
                        } catch(e) {
                            torbutton_eclog(3, 'Exception on stop/clear');
                        }
                    } else {
                        torbutton_eclog(4, 'No progress for document cancel!');
                        window.alert(warning);
                    }
                    torbutton_eclog(3, 'Killed plugin document');
                    return 0;
                }
            } else {
                torbutton_eclog(2, 'Nonpending: '+aRequest.name);
                torbutton_eclog(2, 'Type: '+aRequest.contentType);
            }
        }
    } catch(e) {
        torbutton_eclog(3, 'Exception on request cancel');
    }

    // TODO: separate this from the above?
    if(DOMWindow) {
        var doc = DOMWindow.document;
        try {
            if(doc && doc.domain) {
                torbutton_update_tags(DOMWindow.window);
                torbutton_hookdoc(DOMWindow.window, doc);
            }
        } catch(e) {
            try {
                if(doc && doc.location && 
                  (doc.location.href.indexOf("about:") != 0 &&
                   doc.location.href.indexOf("chrome:") != 0)) {
                    torbutton_eclog(4, "Exception on tag application at "+doc.location+": "+e);
                } else {
                    torbutton_eclog(3, "Got an about url: "+e);
                }
            } catch(e1) {
                torbutton_eclog(3, "Got odd url "+e);
            }
        }        
    } else {
        torbutton_eclog(3, "No aProgress for location!");
    }
    return 0;
}

// Warning: These can also fire when the 'debuglogger' extension
// updates its window. Typically for this, doc.domain is null. Do not
// log in this case (until we find a better way to filter those
// events out). Use torbutton_eclog for common-path stuff.
var torbutton_weblistener =
{
  QueryInterface: function(aIID)
  {
   if (aIID.equals(Components.interfaces.nsIWebProgressListener) ||
       aIID.equals(Components.interfaces.nsISupportsWeakReference) ||
       aIID.equals(Components.interfaces.nsISupports))
     return this;
   throw Components.results.NS_NOINTERFACE;
  },

  onStateChange: function(aProgress, aRequest, aFlag, aStatus)
  { 
      torbutton_eclog(1, 'State change()');
      return torbutton_check_progress(aProgress, aRequest, aFlag);
  },

  onLocationChange: function(aProgress, aRequest, aURI)
  {
      torbutton_eclog(1, 'onLocationChange: '+aURI.asciiSpec);
      return torbutton_check_progress(aProgress, aRequest, 0);
  },

  onProgressChange: function(aProgress, aRequest, curSelfProgress, maxSelfProgress, curTotalProgress, maxTotalProgress) 
  { 
      torbutton_eclog(1, 'called progressChange'); 
      return torbutton_check_progress(aProgress, aRequest, 0);
  },
  
  onStatusChange: function(aProgress, aRequest, stat, message) 
  { 
      torbutton_eclog(1, 'called progressChange'); 
      return torbutton_check_progress(aProgress, aRequest, 0);
  },
  
  onSecurityChange: function() {return 0;},
  
  onLinkIconAvailable: function() 
  { /*torbutton_eclog(1, 'called linkIcon'); */ return 0; }
}


//vim:set ts=4
