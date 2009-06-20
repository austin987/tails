var m_tb_torlog = Components.classes["@torproject.org/torbutton-logger;1"]
.getService(Components.interfaces.nsISupports).wrappedJSObject;


function torbutton_eclog(nLevel, sMsg) {
    m_tb_torlog.eclog(nLevel, sMsg);

    return true;
}

function torbutton_log(nLevel, sMsg) {
    m_tb_torlog.log(nLevel, sMsg);

    // So we can use it in boolean expressions to determine where the 
    // short-circuit is..
    return true; 
}

// get a preferences branch object
// FIXME: this is lame.
function torbutton_get_prefbranch(branch_name) {
    var o_prefs = false;
    var o_branch = false;

    torbutton_log(1, "called get_prefbranch()");
    o_prefs = Components.classes["@mozilla.org/preferences-service;1"]
                        .getService(Components.interfaces.nsIPrefService);
    if (!o_prefs)
    {
        torbutton_log(5, "Failed to get preferences-service!");
        return false;
    }

    o_branch = o_prefs.getBranch(branch_name);
    if (!o_branch)
    {
        torbutton_log(5, "Failed to get prefs branch!");
        return false;
    }

    return o_branch;
}

function torbutton_reset_browser_prefs() {
    var o_all_prefs = torbutton_get_prefbranch('');
    var prefs = ["network.http.sendSecureXSiteReferrer", 
        "network.http.sendRefererHeader", "dom.storage.enabled", 
        "extensions.update.enabled", "app.update.enabled",
        "app.update.auto", "browser.search.update", 
        "browser.cache.memory.enable", "network.http.use-cache", 
        "browser.cache.disk.enable", "browser.safebrowsing.enabled",
        "browser.send_pings", "browser.safebrowsing.remoteLookups",
        "network.security.ports.banned", "browser.search.suggest.enabled",
        "security.enable_java", "browser.history_expire_days",
        "browser.download.manager.retention", "browser.formfill.enable",
        "signon.rememberSignons", "plugin.disable_full_page_plugin_for_types",
        "browser.bookmarks.livemark_refresh_seconds", 
        "network.cookie.lifetimePolicy" ];
    for(var i = 0; i < prefs.length; i++) {
        if(o_all_prefs.prefHasUserValue(prefs[i]))
            o_all_prefs.clearUserPref(prefs[i]);
    }
}

// check if the socks_remote_dns preference exists
function torbutton_check_socks_remote_dns()
{
    var o_prefbranch = false;

    o_prefbranch = torbutton_get_prefbranch("network.proxy.");
    // check if this version of Firefox has the socks_remote_dns option
    try {
        o_prefbranch.getBoolPref('socks_remote_dns');
        torbutton_log(2, "socks_remote_dns is available");
        return true;
    } catch (rErr) {
        // no such preference
        torbutton_log(4, "socks_remote_dns is unavailable");
        return false;
    }
}

function torbutton_check_status() {
    var liveprefs = false;
    var torprefs = false;
    torbutton_log(1, "Check status");

    liveprefs = torbutton_get_prefbranch('network.proxy.');
    torprefs = torbutton_get_prefbranch('extensions.torbutton.');

    if (!torprefs) {
        torbutton_log(5, "Failed to get torprefs!");
        return false;
    }

    if (!liveprefs) {
        torbutton_log(5, "Failed to get lifeprefs!");
        return false;
    }

    if (torbutton_check_socks_remote_dns())
         remote_dns = liveprefs.getBoolPref("socks_remote_dns");
    else
         remote_dns = true;

    return ((liveprefs.getIntPref("type")          == 1)              &&
         torbutton_log(1, "Type is true") &&
         (liveprefs.getCharPref("http")         == torprefs.getCharPref('http_proxy'))   &&
         torbutton_log(1, "Http proxy") &&
         (liveprefs.getIntPref("http_port")     == torprefs.getIntPref('http_port'))     &&
         torbutton_log(1, "Http port") &&
         (liveprefs.getCharPref("ssl")          == torprefs.getCharPref('https_proxy'))  &&
         torbutton_log(1, "ssl proxy") &&
         (liveprefs.getIntPref("ssl_port")      == torprefs.getIntPref('https_port'))    &&
         torbutton_log(1, "ssl port") &&
         (liveprefs.getCharPref("ftp")          == torprefs.getCharPref('ftp_proxy'))    &&
         torbutton_log(1, "ftp proxy") &&
         (liveprefs.getIntPref("ftp_port")      == torprefs.getIntPref('ftp_port'))      &&
         torbutton_log(1, "ftp port") &&
         (liveprefs.getCharPref("gopher")       == torprefs.getCharPref('gopher_proxy')) &&
         torbutton_log(1, "gopher proxy") &&
         (liveprefs.getIntPref("gopher_port")   == torprefs.getIntPref('gopher_port'))   &&
         torbutton_log(1, "gopher port") &&
         (liveprefs.getCharPref("socks")        == torprefs.getCharPref('socks_host'))   &&
         torbutton_log(1, "socks proxy") &&
         (liveprefs.getIntPref("socks_port")    == torprefs.getIntPref('socks_port'))    &&
         torbutton_log(1, "socks port") &&
         (liveprefs.getIntPref("socks_version") == 5)              &&
         torbutton_log(1, "socks version") &&
         (liveprefs.getBoolPref("share_proxy_settings") == false)   &&
         torbutton_log(1, "share proxy settins") &&
         (remote_dns == true) 
         && torbutton_log(1, "remote_dns"));
}

function torbutton_activate_tor_settings()
{
  var liveprefs = false;
  var torprefs = false;

  liveprefs = torbutton_get_prefbranch('network.proxy.');
  torprefs = torbutton_get_prefbranch('extensions.torbutton.');
  if (!liveprefs || !torprefs) {
      torbutton_log(4, 'Prefbranch error');
      return;
  }

  torbutton_log(2, 'Activate tor settings');
  torprefs.setBoolPref("tor_enabled", true);
  liveprefs.setCharPref('http',         torprefs.getCharPref('http_proxy'));
  liveprefs.setIntPref('http_port',     torprefs.getIntPref('http_port'));
  liveprefs.setCharPref('ssl',          torprefs.getCharPref('https_proxy'));
  liveprefs.setIntPref('ssl_port',      torprefs.getIntPref('https_port'));
  liveprefs.setCharPref('ftp',          torprefs.getCharPref('ftp_proxy'));
  liveprefs.setIntPref('ftp_port',      torprefs.getIntPref('ftp_port'));
  torbutton_log(1, 'Half-way there');
  liveprefs.setCharPref('gopher',       torprefs.getCharPref('gopher_proxy'));
  liveprefs.setIntPref('gopher_port',   torprefs.getIntPref('gopher_port'));
  liveprefs.setCharPref('socks',        torprefs.getCharPref('socks_host'));
  liveprefs.setIntPref('socks_port',    torprefs.getIntPref('socks_port'));
  liveprefs.setIntPref('socks_version', 5);
  liveprefs.setBoolPref('share_proxy_settings', false);
  if (torbutton_check_socks_remote_dns()) {
      liveprefs.setBoolPref('socks_remote_dns', true);
  }
  liveprefs.setIntPref('type', 1);
  torbutton_log(2, 'Done activating tor settings');
}

// load localization strings
function torbutton_get_stringbundle()
{
    var o_stringbundle = false;

    try {
        var oBundle = Components.classes["@mozilla.org/intl/stringbundle;1"]
                                .getService(Components.interfaces.nsIStringBundleService);
        o_stringbundle = oBundle.createBundle("chrome://torbutton/locale/torbutton.properties");
    } catch(err) {
        o_stringbundle = false;
    }
    if (!o_stringbundle) {
        torbutton_log(5, 'ERROR (init): failed to find torbutton-bundle');
    }

    return o_stringbundle;
}

