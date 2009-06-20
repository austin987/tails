// PREFERences dialog functions
//   torbutton_prefs_set_field_attributes() -- initialize dialog fields
//   torbutton_prefs_init() -- on dialog load
//   torbutton_prefs_save() -- on dialog save

var tor_enabled = false;

function torbutton_prefs_set_field_attributes(doc)
{
    torbutton_log(2, "called prefs_set_field_attributes()");
    var o_torprefs = torbutton_get_prefbranch('extensions.torbutton.');
    var o_customprefs = torbutton_get_prefbranch('extensions.torbutton.custom.');

    doc.getElementById('torbutton_panelStyle').setAttribute("disabled", !doc.getElementById('torbutton_displayStatusPanel').checked);
    doc.getElementById('torbutton_panelStyleText').setAttribute("disabled", !doc.getElementById('torbutton_displayStatusPanel').checked);
    doc.getElementById('torbutton_panelStyleIcon').setAttribute("disabled", !doc.getElementById('torbutton_displayStatusPanel').checked);
    // Privoxy is always recommended for Firefoxes not support socks_remote_dns
    if (!torbutton_check_socks_remote_dns()) {
      doc.getElementById('torbutton_usePrivoxy').setAttribute("disabled", true);
    } else {
      doc.getElementById('torbutton_usePrivoxy').setAttribute("disabled", doc.getElementById('torbutton_settingsMethod').value != 'recommended');
    }
    var proxy_port;
    var proxy_host;
    if (doc.getElementById('torbutton_usePrivoxy').checked) {
        proxy_host = '127.0.0.1';
        proxy_port = 8118;
    } else {
        proxy_host = '';
        proxy_port = 0;
    }

    if (doc.getElementById('torbutton_settingsMethod').value == 'recommended') {
        torbutton_log(2, "using recommended settings");
        if (!torbutton_check_socks_remote_dns()) {
            doc.getElementById('torbutton_httpProxy').value = proxy_host;
            doc.getElementById('torbutton_httpPort').value = proxy_port;
            doc.getElementById('torbutton_httpsProxy').value = proxy_host;
            doc.getElementById('torbutton_httpsPort').value = proxy_port;
            doc.getElementById('torbutton_ftpProxy').value = proxy_host;
            doc.getElementById('torbutton_ftpPort').value = proxy_port;
            doc.getElementById('torbutton_gopherProxy').value = proxy_host;
            doc.getElementById('torbutton_gopherPort').value = proxy_port;
        } else {
            doc.getElementById('torbutton_httpProxy').value = proxy_host;
            doc.getElementById('torbutton_httpPort').value = proxy_port;
            doc.getElementById('torbutton_httpsProxy').value = proxy_host;
            doc.getElementById('torbutton_httpsPort').value = proxy_port;

            doc.getElementById('torbutton_ftpProxy').value = '';
            doc.getElementById('torbutton_ftpPort').value = 0;
            doc.getElementById('torbutton_gopherProxy').value = '';
            doc.getElementById('torbutton_gopherPort').value = 0;
        }
        doc.getElementById('torbutton_socksHost').value = '127.0.0.1';
        doc.getElementById('torbutton_socksPort').value = 9050;

        doc.getElementById('torbutton_httpProxy').disabled = true;
        doc.getElementById('torbutton_httpPort').disabled = true;
        doc.getElementById('torbutton_httpsProxy').disabled = true;
        doc.getElementById('torbutton_httpsPort').disabled = true;
        doc.getElementById('torbutton_ftpProxy').disabled = true;
        doc.getElementById('torbutton_ftpPort').disabled = true;
        doc.getElementById('torbutton_gopherProxy').disabled = true;
        doc.getElementById('torbutton_gopherPort').disabled = true;
        doc.getElementById('torbutton_socksHost').disabled = true;
        doc.getElementById('torbutton_socksPort').disabled = true;
        doc.getElementById('torbutton_socksGroup').disabled = true;
    } else {
        doc.getElementById('torbutton_httpProxy').disabled = false;
        doc.getElementById('torbutton_httpPort').disabled = false;
        doc.getElementById('torbutton_httpsProxy').disabled = false;
        doc.getElementById('torbutton_httpsPort').disabled = false;
        doc.getElementById('torbutton_ftpProxy').disabled = false;
        doc.getElementById('torbutton_ftpPort').disabled = false;
        doc.getElementById('torbutton_gopherProxy').disabled = false;
        doc.getElementById('torbutton_gopherPort').disabled = false;
        doc.getElementById('torbutton_socksHost').disabled = false;
        doc.getElementById('torbutton_socksPort').disabled = false;
        doc.getElementById('torbutton_socksGroup').disabled = false;
        /* Do not reset these on every document update..
        doc.getElementById('torbutton_httpProxy').value    = o_customprefs.getCharPref('http_proxy');
        doc.getElementById('torbutton_httpPort').value     = o_customprefs.getIntPref('http_port');
        doc.getElementById('torbutton_httpsProxy').value   = o_customprefs.getCharPref('https_proxy');
        doc.getElementById('torbutton_httpsPort').value    = o_customprefs.getIntPref('https_port');
        doc.getElementById('torbutton_ftpProxy').value     = o_customprefs.getCharPref('ftp_proxy');
        doc.getElementById('torbutton_ftpPort').value      = o_customprefs.getIntPref('ftp_port');
        doc.getElementById('torbutton_gopherProxy').value  = o_customprefs.getCharPref('gopher_proxy');
        doc.getElementById('torbutton_gopherPort').value   = o_customprefs.getIntPref('gopher_port');
        doc.getElementById('torbutton_socksHost').value    = o_customprefs.getCharPref('socks_host');
        doc.getElementById('torbutton_socksPort').value    = o_customprefs.getIntPref('socks_port');
        */
    }
}

function torbutton_prefs_init(doc) {
    var checkbox_displayStatusPanel = doc.getElementById('torbutton_displayStatusPanel');
// return; 

    torbutton_log(2, "called prefs_init()");
    sizeToContent();

    // remember if tor settings were enabled when the window was opened
    tor_enabled = torbutton_check_status();

    var o_torprefs = torbutton_get_prefbranch('extensions.torbutton.');

    doc.getElementById('torbutton_displayStatusPanel').checked = o_torprefs.getBoolPref('display_panel');
    var panel_style = doc.getElementById('torbutton_panelStyle');
    var panel_style_pref = o_torprefs.getCharPref('panel_style');
    if (panel_style_pref == 'text')
        panel_style.selectedItem = doc.getElementById('torbutton_panelStyleText');
    else if (panel_style_pref == 'iconic')
        panel_style.selectedItem = doc.getElementById('torbutton_panelStyleIcon');
    // doc.getElementById('torbutton_panelStyle').value = o_torprefs.getCharPref('panel_style');
    var settings_method = doc.getElementById('torbutton_settingsMethod');
    var settings_method_pref = o_torprefs.getCharPref('settings_method');
    if (settings_method_pref == 'recommended')
        settings_method.selectedItem = doc.getElementById('torbutton_useRecommendedSettings');
    else if (settings_method_pref == 'custom')
        settings_method.selectedItem = doc.getElementById('torbutton_useCustomSettings');
    // doc.getElementById('torbutton_settingsMethod').value = o_torprefs.getCharPref('settings_method');
    doc.getElementById('torbutton_usePrivoxy').checked = o_torprefs.getBoolPref('use_privoxy');
    doc.getElementById('torbutton_httpProxy').value    = o_torprefs.getCharPref('http_proxy');
    doc.getElementById('torbutton_httpPort').value     = o_torprefs.getIntPref('http_port');
    doc.getElementById('torbutton_httpsProxy').value   = o_torprefs.getCharPref('https_proxy');
    doc.getElementById('torbutton_httpsPort').value    = o_torprefs.getIntPref('https_port');
    doc.getElementById('torbutton_ftpProxy').value     = o_torprefs.getCharPref('ftp_proxy');
    doc.getElementById('torbutton_ftpPort').value      = o_torprefs.getIntPref('ftp_port');
    doc.getElementById('torbutton_gopherProxy').value  = o_torprefs.getCharPref('gopher_proxy');
    doc.getElementById('torbutton_gopherPort').value   = o_torprefs.getIntPref('gopher_port');
    doc.getElementById('torbutton_socksHost').value    = o_torprefs.getCharPref('socks_host');
    doc.getElementById('torbutton_socksPort').value    = o_torprefs.getIntPref('socks_port');
    if(o_torprefs.getIntPref('socks_version') == 4) {
        doc.getElementById('torbutton_socksGroup').selectedItem =
            doc.getElementById('torbutton_socksv4');    
    } else {
        doc.getElementById('torbutton_socksGroup').selectedItem =
            doc.getElementById('torbutton_socksv5');    
    }
    // doc.getElementById('torbutton_warnUponExcludedSite').checked = o_torprefs.getBoolPref('prompt_before_visiting_excluded_sites');

    doc.getElementById('torbutton_disablePlugins').checked = o_torprefs.getBoolPref('no_tor_plugins');
    doc.getElementById('torbutton_clearHistory').checked = o_torprefs.getBoolPref('clear_history');
    doc.getElementById('torbutton_killBadJS').checked = o_torprefs.getBoolPref('kill_bad_js');
    doc.getElementById('torbutton_resizeOnToggle').checked = o_torprefs.getBoolPref('resize_on_toggle');
   
    if(o_torprefs.getBoolPref('clear_cache')) {
        doc.getElementById('torbutton_cacheGroup').selectedItem =
            doc.getElementById('torbutton_clearCache');
        o_torprefs.setBoolPref('block_cache', false);
    } else {
        doc.getElementById('torbutton_cacheGroup').selectedItem =
            doc.getElementById('torbutton_blockCache');
        o_torprefs.setBoolPref('block_cache', true);
        o_torprefs.setBoolPref('clear_cache', false);
    }

    if(o_torprefs.getBoolPref('clear_cookies')) {
        doc.getElementById('torbutton_cookieGroup').selectedItem = 
            doc.getElementById('torbutton_clearCookies');
        o_torprefs.setBoolPref('cookie_jars', false);
        o_torprefs.setBoolPref('dual_cookie_jars', false);
        o_torprefs.setBoolPref('clear_cookies', true); 

        o_torprefs.setBoolPref('tor_memory_jar', true);
        o_torprefs.setBoolPref('nontor_memory_jar', true);
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = true;
    } else if(o_torprefs.getBoolPref('cookie_jars')) {
        doc.getElementById('torbutton_cookieGroup').selectedItem =
            doc.getElementById('torbutton_cookieJars');
        o_torprefs.setBoolPref('cookie_jars', true);
        o_torprefs.setBoolPref('dual_cookie_jars', false);
        o_torprefs.setBoolPref('clear_cookies', false);

        o_torprefs.setBoolPref('tor_memory_jar', true);
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = false;
    } else if(o_torprefs.getBoolPref('dual_cookie_jars')) {
        doc.getElementById('torbutton_cookieGroup').selectedItem =
            doc.getElementById('torbutton_dualCookieJars');
        o_torprefs.setBoolPref('cookie_jars', false);
        o_torprefs.setBoolPref('dual_cookie_jars', true);
        o_torprefs.setBoolPref('clear_cookies', false); 

        doc.getElementById('torbutton_torMemoryJar').disabled = false;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = false;
    } else {
        doc.getElementById('torbutton_cookieGroup').selectedItem =
            doc.getElementById('torbutton_mmmCookies');
        o_torprefs.setBoolPref('cookie_jars', false);
        o_torprefs.setBoolPref('dual_cookie_jars', false);
        o_torprefs.setBoolPref('clear_cookies', false); 

        o_torprefs.setBoolPref('tor_memory_jar', false);
        o_torprefs.setBoolPref('nontor_memory_jar', false);
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = true;
    }

    doc.getElementById('torbutton_torMemoryJar').checked = o_torprefs.getBoolPref('tor_memory_jar');
    doc.getElementById('torbutton_nonTorMemoryJar').checked = o_torprefs.getBoolPref('nontor_memory_jar');

    doc.getElementById('torbutton_noDomStorage').checked = 
        o_torprefs.getBoolPref('disable_domstorage');
    
    if(o_torprefs.getIntPref('shutdown_method') == 0) {
        doc.getElementById('torbutton_shutdownGroup').selectedItem
            = doc.getElementById('torbutton_noShutdown');
    } else if(o_torprefs.getIntPref('shutdown_method') == 1) {
        doc.getElementById('torbutton_shutdownGroup').selectedItem
            = doc.getElementById('torbutton_torShutdown');
    } else {
        o_torprefs.setIntPref('shutdown_method', 2); 
        doc.getElementById('torbutton_shutdownGroup').selectedItem
            = doc.getElementById('torbutton_allShutdown');
    }

    if(o_torprefs.getBoolPref('restore_tor')) {
        doc.getElementById('torbutton_restoreTorGroup').selectedItem =
            doc.getElementById('torbutton_restoreTor');
    } else {
        doc.getElementById('torbutton_restoreTorGroup').selectedItem =
            doc.getElementById('torbutton_restoreNonTor');
    }

    switch(o_torprefs.getIntPref('startup_state')) {
        case 0: // non-tor
            doc.getElementById("torbutton_startupStateGroup").selectedItem =
                doc.getElementById('torbutton_startNonTor');
            break;
        case 1: // tor
            doc.getElementById("torbutton_startupStateGroup").selectedItem =
                doc.getElementById('torbutton_startTor');
            break;
        case 2: // shutdown state
            doc.getElementById("torbutton_startupStateGroup").selectedItem =
                doc.getElementById('torbutton_startPrevious');
            break;
    }

    doc.getElementById('torbutton_torSessionStore').checked = !o_torprefs.getBoolPref('notor_sessionstore');
    doc.getElementById('torbutton_nonTorSessionStore').checked = !o_torprefs.getBoolPref('nonontor_sessionstore');

    //doc.getElementById('torbutton_reloadCrashedJar').checked = o_torprefs.getBoolPref('reload_crashed_jar');
    
    doc.getElementById('torbutton_blockTorHRead').checked = o_torprefs.getBoolPref('block_thread');
    doc.getElementById('torbutton_blockTorHWrite').checked = o_torprefs.getBoolPref('block_thwrite');
    doc.getElementById('torbutton_blockNonTorHRead').checked = o_torprefs.getBoolPref('block_nthread');
    doc.getElementById('torbutton_blockNonTorHWrite').checked = o_torprefs.getBoolPref('block_nthwrite');
    doc.getElementById('torbutton_blockTorForms').checked = o_torprefs.getBoolPref('block_tforms');
    doc.getElementById('torbutton_blockNonTorForms').checked = o_torprefs.getBoolPref('block_ntforms');
    doc.getElementById('torbutton_isolateContent').checked = o_torprefs.getBoolPref('isolate_content');
    doc.getElementById('torbutton_noSearch').checked = o_torprefs.getBoolPref('no_search');
    doc.getElementById('torbutton_closeTor').checked = o_torprefs.getBoolPref('close_tor');
    doc.getElementById('torbutton_closeNonTor').checked = o_torprefs.getBoolPref('close_nontor');
    doc.getElementById('torbutton_noUpdates').checked = o_torprefs.getBoolPref('no_updates');
    doc.getElementById('torbutton_setUagent').checked = o_torprefs.getBoolPref('set_uagent');
    doc.getElementById('torbutton_noReferer').checked = o_torprefs.getBoolPref('disable_referer');
    doc.getElementById('torbutton_spoofEnglish').checked = o_torprefs.getBoolPref('spoof_english');
    doc.getElementById('torbutton_clearHttpAuth').checked = o_torprefs.getBoolPref('clear_http_auth');
    doc.getElementById('torbutton_blockJSHistory').checked = o_torprefs.getBoolPref('block_js_history');
    doc.getElementById('torbutton_blockTorFileNet').checked = o_torprefs.getBoolPref('block_tor_file_net');
    doc.getElementById('torbutton_blockNonTorFileNet').checked = o_torprefs.getBoolPref('block_nontor_file_net');

    doc.getElementById('torbutton_lockedMode').checked = o_torprefs.getBoolPref('locked_mode');
    /*
    doc.getElementById('torbutton_jarCerts').checked = o_torprefs.getBoolPref('jar_certs');
    doc.getElementById('torbutton_jarCACerts').checked = o_torprefs.getBoolPref('jar_ca_certs');
    */

    torbutton_prefs_set_field_attributes(doc);
}

function torbutton_cookie_update(doc) {
    var o_torprefs = torbutton_get_prefbranch('extensions.torbutton.');
    doc.getElementById('torbutton_torMemoryJar').checked = o_torprefs.getBoolPref('tor_memory_jar');
    doc.getElementById('torbutton_nonTorMemoryJar').checked = o_torprefs.getBoolPref('nontor_memory_jar');

    if(doc.getElementById('torbutton_cookieGroup').selectedItem 
            == doc.getElementById('torbutton_clearCookies')) {
        doc.getElementById('torbutton_torMemoryJar').checked = true;
        doc.getElementById('torbutton_nonTorMemoryJar').checked = true;
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = true;
    } else if(doc.getElementById('torbutton_cookieGroup').selectedItem
            == doc.getElementById('torbutton_cookieJars')) {
        doc.getElementById('torbutton_torMemoryJar').checked = true;
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = false;
    } else if(doc.getElementById('torbutton_cookieGroup').selectedItem
            == doc.getElementById('torbutton_dualCookieJars')) {
        doc.getElementById('torbutton_torMemoryJar').disabled = false;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = false;
    } else if(doc.getElementById('torbutton_cookieGroup').selectedItem
            == doc.getElementById('torbutton_mmmCookies')) {
        doc.getElementById('torbutton_torMemoryJar').checked = false;
        doc.getElementById('torbutton_nonTorMemoryJar').checked = false;
        doc.getElementById('torbutton_torMemoryJar').disabled = true;
        doc.getElementById('torbutton_nonTorMemoryJar').disabled = true;
    }
}

function torbutton_prefs_save(doc) {
    torbutton_log(2, "called prefs_save()");
    var o_torprefs = torbutton_get_prefbranch('extensions.torbutton.');
    var o_customprefs = torbutton_get_prefbranch('extensions.torbutton.custom.');

    o_torprefs.setBoolPref('display_panel',   doc.getElementById('torbutton_displayStatusPanel').checked);
    o_torprefs.setCharPref('panel_style',     doc.getElementById('torbutton_panelStyle').value);
    o_torprefs.setCharPref('settings_method', doc.getElementById('torbutton_settingsMethod').value);
    o_torprefs.setBoolPref('use_privoxy',     doc.getElementById('torbutton_usePrivoxy').checked);
    o_torprefs.setCharPref('http_proxy',      doc.getElementById('torbutton_httpProxy').value);
    o_torprefs.setIntPref('http_port',        doc.getElementById('torbutton_httpPort').value);
    o_torprefs.setCharPref('https_proxy',     doc.getElementById('torbutton_httpsProxy').value);
    o_torprefs.setIntPref('https_port',       doc.getElementById('torbutton_httpsPort').value);
    o_torprefs.setCharPref('ftp_proxy',       doc.getElementById('torbutton_ftpProxy').value);
    o_torprefs.setIntPref('ftp_port',         doc.getElementById('torbutton_ftpPort').value);
    o_torprefs.setCharPref('gopher_proxy',    doc.getElementById('torbutton_gopherProxy').value);
    o_torprefs.setIntPref('gopher_port',      doc.getElementById('torbutton_gopherPort').value);
    o_torprefs.setCharPref('socks_host',      doc.getElementById('torbutton_socksHost').value);
    o_torprefs.setIntPref('socks_port',       doc.getElementById('torbutton_socksPort').value);

    if(doc.getElementById('torbutton_socksGroup').selectedItem ==
            doc.getElementById('torbutton_socksv4')) {
        o_torprefs.setIntPref('socks_version', 4); 
    } else if(doc.getElementById('torbutton_socksGroup').selectedItem ==
            doc.getElementById('torbutton_socksv5')) {
        o_torprefs.setIntPref('socks_version', 5); 
    }

    if (doc.getElementById('torbutton_settingsMethod').value == 'custom') {
        // XXX: Is this even needed anymore? We don't read the
        // custom prefs at all it seems..
        o_customprefs.setCharPref('http_proxy',      doc.getElementById('torbutton_httpProxy').value);
        o_customprefs.setIntPref('http_port',        doc.getElementById('torbutton_httpPort').value);
        o_customprefs.setCharPref('https_proxy',     doc.getElementById('torbutton_httpsProxy').value);
        o_customprefs.setIntPref('https_port',       doc.getElementById('torbutton_httpsPort').value);
        o_customprefs.setCharPref('ftp_proxy',       doc.getElementById('torbutton_ftpProxy').value);
        o_customprefs.setIntPref('ftp_port',         doc.getElementById('torbutton_ftpPort').value);
        o_customprefs.setCharPref('gopher_proxy',    doc.getElementById('torbutton_gopherProxy').value);
        o_customprefs.setIntPref('gopher_port',      doc.getElementById('torbutton_gopherPort').value);
        o_customprefs.setCharPref('socks_host',      doc.getElementById('torbutton_socksHost').value);
        o_customprefs.setIntPref('socks_port',       doc.getElementById('torbutton_socksPort').value);

        if(doc.getElementById('torbutton_socksGroup').selectedItem ==
                doc.getElementById('torbutton_socksv4')) {
            o_customprefs.setIntPref('socks_version', 4); 
        } else if(doc.getElementById('torbutton_socksGroup').selectedItem ==
                doc.getElementById('torbutton_socksv5')) {
            o_customprefs.setIntPref('socks_version', 5); 
        }
    }
    // o_torprefs.setBoolPref('prompt_before_visiting_excluded_sites', doc.getElementById('torbutton_warnUponExcludedSite').checked);

    o_torprefs.setBoolPref('no_tor_plugins', doc.getElementById('torbutton_disablePlugins').checked);
    o_torprefs.setBoolPref('clear_history', doc.getElementById('torbutton_clearHistory').checked);
    o_torprefs.setBoolPref('kill_bad_js', doc.getElementById('torbutton_killBadJS').checked);
    o_torprefs.setBoolPref('resize_on_toggle', doc.getElementById('torbutton_resizeOnToggle').checked);
    o_torprefs.setBoolPref('isolate_content', doc.getElementById('torbutton_isolateContent').checked);

    o_torprefs.setBoolPref('clear_cache', doc.getElementById('torbutton_clearCache').selected);
    o_torprefs.setBoolPref('block_cache', doc.getElementById('torbutton_blockCache').selected);
    o_torprefs.setBoolPref('clear_cookies', doc.getElementById('torbutton_clearCookies').selected);
    o_torprefs.setBoolPref('cookie_jars', doc.getElementById('torbutton_cookieJars').selected);
    o_torprefs.setBoolPref('dual_cookie_jars', doc.getElementById('torbutton_dualCookieJars').selected);
    o_torprefs.setBoolPref('disable_domstorage', doc.getElementById('torbutton_noDomStorage').checked);
    o_torprefs.setBoolPref('clear_http_auth', doc.getElementById('torbutton_clearHttpAuth').checked);
    o_torprefs.setBoolPref('block_js_history', doc.getElementById('torbutton_blockJSHistory').checked);
    o_torprefs.setBoolPref('block_tor_file_net', doc.getElementById('torbutton_blockTorFileNet').checked);
    o_torprefs.setBoolPref('block_nontor_file_net', doc.getElementById('torbutton_blockNonTorFileNet').checked);
    
    o_torprefs.setBoolPref('tor_memory_jar', doc.getElementById('torbutton_torMemoryJar').checked);
    o_torprefs.setBoolPref('nontor_memory_jar', doc.getElementById('torbutton_nonTorMemoryJar').checked);

    if(doc.getElementById('torbutton_shutdownGroup').selectedItem ==
            doc.getElementById('torbutton_noShutdown')) {
        o_torprefs.setIntPref('shutdown_method', 0); 
    } else if(doc.getElementById('torbutton_shutdownGroup').selectedItem ==
            doc.getElementById('torbutton_torShutdown')) {
        o_torprefs.setIntPref('shutdown_method', 1); 
    } else {
        o_torprefs.setIntPref('shutdown_method', 2); 
    }

    /* Reset the shutdown option if the user wants to manage own cookies */
    if(!o_torprefs.getBoolPref('cookie_jars') 
            && !o_torprefs.getBoolPref('clear_cookies')
            && !o_torprefs.getBoolPref('dual_cookie_jars')) {
        o_torprefs.setIntPref('shutdown_method', 0); 
        doc.getElementById('torbutton_shutdownGroup').selectedItem
            = doc.getElementById('torbutton_noShutdown');
    }
    

    o_torprefs.setBoolPref('restore_tor', 
            doc.getElementById('torbutton_restoreTorGroup').selectedItem ==
            doc.getElementById('torbutton_restoreTor'));

    if(doc.getElementById('torbutton_startupStateGroup').selectedItem ==
            doc.getElementById('torbutton_startNonTor')) {
        o_torprefs.setIntPref('startup_state', 0);
    } else if(doc.getElementById('torbutton_startupStateGroup').selectedItem ==
            doc.getElementById('torbutton_startTor')) {
        o_torprefs.setIntPref('startup_state', 1);
    } else {
        o_torprefs.setIntPref('startup_state', 2);
    }

    o_torprefs.setBoolPref('notor_sessionstore', !doc.getElementById('torbutton_torSessionStore').checked);
    o_torprefs.setBoolPref('nonontor_sessionstore', !doc.getElementById('torbutton_nonTorSessionStore').checked);
    //o_torprefs.setBoolPref('reload_crashed_jar', doc.getElementById('torbutton_reloadCrashedJar').checked);
    o_torprefs.setBoolPref('block_thread', doc.getElementById('torbutton_blockTorHRead').checked);
    o_torprefs.setBoolPref('block_thwrite', doc.getElementById('torbutton_blockTorHWrite').checked);
    o_torprefs.setBoolPref('block_nthread', doc.getElementById('torbutton_blockNonTorHRead').checked);
    o_torprefs.setBoolPref('block_nthwrite', doc.getElementById('torbutton_blockNonTorHWrite').checked);
    o_torprefs.setBoolPref('block_tforms', doc.getElementById('torbutton_blockTorForms').checked);
    o_torprefs.setBoolPref('block_ntforms', doc.getElementById('torbutton_blockNonTorForms').checked);
    o_torprefs.setBoolPref('no_search', doc.getElementById('torbutton_noSearch').checked);
    o_torprefs.setBoolPref('close_tor', doc.getElementById('torbutton_closeTor').checked);
    o_torprefs.setBoolPref('close_nontor', doc.getElementById('torbutton_closeNonTor').checked);
    o_torprefs.setBoolPref('no_updates', doc.getElementById('torbutton_noUpdates').checked);
    
    o_torprefs.setBoolPref('set_uagent', doc.getElementById('torbutton_setUagent').checked);
    o_torprefs.setBoolPref('disable_referer', doc.getElementById('torbutton_noReferer').checked);
    o_torprefs.setBoolPref('spoof_english', doc.getElementById('torbutton_spoofEnglish').checked);
    
    o_torprefs.setBoolPref('locked_mode', doc.getElementById('torbutton_lockedMode').checked);
    /*
    o_torprefs.setBoolPref('jar_certs', doc.getElementById('torbutton_jarCerts').checked);
    o_torprefs.setBoolPref('jar_ca_certs',
            o_torprefs.getBoolPref('jar_certs') &&
            doc.getElementById('torbutton_jarCACerts').checked);
    */

    // if tor settings were initially active, update the active settings to reflect any changes
    if (tor_enabled) torbutton_activate_tor_settings();
}

function torbutton_prefs_test_settings() {

    // Reset Tor state to disabled.
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
        .getService(Components.interfaces.nsIWindowMediator);
    var chrome = wm.getMostRecentWindow("navigator:browser");

    var strings = torbutton_get_stringbundle();
    if(chrome.m_tb_ff3) {
        // FIXME: This is kind of ghetto.. can we make a progress 
        // bar or a window that updates itself?
        var warning = strings.GetStringFromName("torbutton.popup.test.ff3_notice");
        window.alert(warning);
    }
    var ret = chrome.torbutton_test_settings();
    // Strange errors are not worth translating. Our english users will
    // tell us they happen and we will (presumably) make them not happen.
    if(ret < 0) {
        ret = -ret;
        window.alert("Tor proxy test: HTTP error for check.torproject.org: "+ret);
        return;
    }
            
    switch(ret) {
        case 0:
            window.alert("Tor proxy test: Internal error");
            break;
        case 1:
            window.alert("Tor proxy test: Result not mimetype text/xml");
            break;
        case 3: // Can't seem to happen
            window.alert("Tor proxy test: Can't find result target!");
            break;
        case 2:
            window.alert("Tor proxy test: No TorCheckResult id found (response not valid XHTML)");
            break;
        case 4:
            var warning = strings.GetStringFromName("torbutton.popup.test.success");
            window.alert(warning);
            break;
        case 5:
            var warning = strings.GetStringFromName("torbutton.popup.test.failure");
            window.alert(warning);
            break;
        case 6:
            window.alert("Tor proxy test: TorDNSEL failure. Results unknown.");
            break;
        case 7:
            window.alert("Tor proxy test: check.torproject.org returned bad result");
            break;
    }
}

function torbutton_prefs_reset_defaults() {
    var o_torprefs = torbutton_get_prefbranch('extensions.torbutton.');
    var o_proxyprefs = torbutton_get_prefbranch('network.proxy.');
    var tmpcnt = new Object();
    var children;
    var i;
    var was_enabled = false;
    var loglevel = o_torprefs.getIntPref("loglevel");
    var logmthd = o_torprefs.getIntPref("logmethod");
    
    torbutton_log(3, "Starting Pref reset");

    //  0. Disable tor
    //  1. Clear proxy settings
    //  2. Restore saved prefs
    //  3. Clear torbutton settings
    //  4. Enable tor if was previously enabled

    // Reset Tor state to disabled.
    var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
        .getService(Components.interfaces.nsIWindowMediator);
    var chrome = wm.getMostRecentWindow("navigator:browser");

    // XXX Warning: The only reason this works is because of Firefox's 
    // threading model. As soon as a pref is changed, all observers
    // are notified by that same thread, immediately. Since torbutton's
    // security state is driven by proxy pref observers, this
    // causes everything to be reset in a linear order. If firefox 
    // ever makes pref observers asynchonous, this will all break.
    if(o_torprefs.getBoolPref("tor_enabled")) {
        chrome.torbutton_disable_tor();
        was_enabled = true;
    }
    
    torbutton_log(3, "Tor disabled for pref reset");

    children = o_torprefs.getChildList("" , tmpcnt);
    for(i = 0; i < children.length; i++) {
        if(o_torprefs.prefHasUserValue(children[i]))
            o_torprefs.clearUserPref(children[i]);
    }

    // Keep logging the same.
    o_torprefs.setIntPref("loglevel", loglevel);
    o_torprefs.setIntPref("logmethod", logmthd);

    children = o_proxyprefs.getChildList("" , tmpcnt);
    for(i = 0; i < children.length; i++) {
        if(o_proxyprefs.prefHasUserValue(children[i]))
            o_proxyprefs.clearUserPref(children[i]);
    }
    
    torbutton_log(3, "Resetting browser prefs");

    // Reset browser prefs that torbutton touches just in case
    // they get horked. Better everything gets set back to default
    // than some arcane pref gets wedged with no clear way to fix it.
    // Technical users who tuned these by themselves will be able to fix it.
    // It's the non-technical ones we should make it easy for
    torbutton_reset_browser_prefs();

    chrome.torbutton_init_prefs();
    chrome.torbutton_do_fresh_install();
    torbutton_log(3, "Prefs reset");

    if(was_enabled) {
        // Hack for torbrowser/others where tor proxies are the same
        // as non-tor.
        if(chrome.torbutton_check_status()) {
            torbutton_log(4, "Tor still enabled after reset. Attempting to restore sanity");
            chrome.torbutton_set_status();
        } else {
            chrome.torbutton_enable_tor(true);
        }
    }

    torbutton_log(4, "Preferences reset to defaults");
    torbutton_prefs_init(window.document);
}
