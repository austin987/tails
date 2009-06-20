/* -*- Mode: javascript; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4; -*- */
/*************************************************************************
 * Content policy to block stuff not handled by other components
 * (such as CSS)
 *   - http://www.w3.org/TR/REC-CSS2/selector.html#dynamic-pseudo-classes
 * 
 * Also serves as a safety net to catch content the other mechanisms 
 * somehow might be tricked into failing to block (this should not happen 
 * in normal operation though).
 *
 * Based on examples from:
 * - http://adblockplus.org/en/faq_internal
 *   - http://developer.mozilla.org/en/docs/How_to_Build_an_XPCOM_Component_in_Javascript
 *   - http://www.xulplanet.com/references/xpcomref/ifaces/nsICategoryManager.html
 *   - http://www.xulplanet.com/references/xpcomref/ifaces/nsIContentPolicy.html
 * - http://greasemonkey.devjavu.com/projects/greasemonkey/browser/trunk/src/components/greasemonkey.js
 *
 * Test cases:
 *   - http://www.tjkdesign.com/articles/css%20pop%20ups/default.asp
 *
 *************************************************************************/

// This is all local scope
const CSSB_CONTRACTID = "@torproject.org/cssblocker;1";
const CSSB_CID = Components.ID("{23f4d9ba-023a-94ab-eb75-67aed7562a18}");

const DNode = Components.interfaces.nsIDOMNode;
const DWindow = Components.interfaces.nsIDOMWindow;
const ok = Components.interfaces.nsIContentPolicy.ACCEPT;
const block = Components.interfaces.nsIContentPolicy.REJECT_REQUEST;
const CPolicy = Components.interfaces.nsIContentPolicy;
const Cr = Components.results;
const Cc = Components.classes;
const Ci = Components.interfaces;

// Retrieves the window object for a node or returns null if it isn't possible
function getWindow(node) {
    if (node && node.nodeType != DNode.DOCUMENT_NODE)
        node = node.ownerDocument;

    if (!node || node.nodeType != DNode.DOCUMENT_NODE)
        return null;

    return node.defaultView;
}

//FIXME: can we kill this noise?
//HACKHACK: need a way to get an implicit wrapper for nodes because of bug 337095 (fixed in Gecko 1.8.0.5)
var fakeFactory = {
	createInstance: function(outer, iid) {
		return outer;
	},

	QueryInterface: function(iid) {
		if (iid.equals(Components.interfaces.nsISupports) ||
				iid.equals(Components.interfaces.nsIFactory))
			return this;

       Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
       return null;
	}
};
var array = Components.classes['@mozilla.org/supports-array;1'].createInstance(Components.interfaces.nsISupportsArray);
array.AppendElement(fakeFactory);
fakeFactory = array.GetElementAt(0).QueryInterface(Components.interfaces.nsIFactory);
array = null;

function wrapNode(insecNode) {
	return fakeFactory.createInstance(insecNode, Components.interfaces.nsISupports);
}

function make_nsIURI(url) {
    var nsiuri = Cc["@mozilla.org/network/standard-url;1"].createInstance(Ci.nsIStandardURL);
    nsiuri.init(Ci.nsIStandardURL.URLTYPE_STANDARD, -1, url, null, null);
    return nsiuri;
}

// Unwraps jar:, view-source: and wyciwyg: URLs, returns the contained URL
function unwrapURL(url, changed) {
	if (!url)
		return url;

	var ret = url.replace(/^view-source:/, "").replace(/^wyciwyg:\/\/\d+\//, "");
	if (/^jar:(.*)!/.test(ret))
		ret = RegExp.$1;

	if (ret == url)
        if(changed) return make_nsIURI(url);
        else return url;
    else
		return unwrapURL(ret, true);
}

var localSchemes = {"about" : true, "chrome" : true, "file" : true, 
    "resource" : true, "x-jsd" : true, "addbook" : true, 
    "mailbox" : true, "moz-icon" : true};

var browserSources = { "browser":true, "mozapps":true, "global":true, 
     "pippki":true, "branding":true};

var hostFreeSchemes = { "resource":true, "data":true, "cid":true, 
     "file":true, "view-source":true, "about":true};

function ContentPolicy() {
    this._prefs = Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefBranch);
    this.wm = Components.classes["@torproject.org/content-window-mapper;1"]
        .getService(Components.interfaces.nsISupports)
        .wrappedJSObject;
    
    this.logger = Components.classes["@torproject.org/torbutton-logger;1"]
        .getService(Components.interfaces.nsISupports).wrappedJSObject;

    // Register observer: 
    var pref_service = Components.classes["@mozilla.org/preferences-service;1"]
        .getService(Components.interfaces.nsIPrefBranchInternal);
    this._branch = pref_service.QueryInterface(Components.interfaces.nsIPrefBranchInternal);
    this._branch.addObserver("extensions.torbutton", this, false);

    this.isolate_content = this._prefs.getBoolPref("extensions.torbutton.isolate_content");
    this.tor_enabled = this._prefs.getBoolPref("extensions.torbutton.tor_enabled");
    this.settings_applied = this._prefs.getBoolPref("extensions.torbutton.settings_applied");
    this.tor_enabling = this.tor_enabled || this.settings_applied; // Catch transition edge cases
    this.block_tor_file_net = this._prefs.getBoolPref("extensions.torbutton.block_tor_file_net");
    this.block_nontor_file_net = this._prefs.getBoolPref("extensions.torbutton.block_nontor_file_net");
    this.no_tor_plugins = this._prefs.getBoolPref("extensions.torbutton.no_tor_plugins");

    return;
}

ContentPolicy.prototype = {
    isLocalScheme: function(scheme) {
        return (scheme in localSchemes);
    },

	// nsIContentPolicy interface implementation
	shouldLoad: function(contentType, contentLocation, requestOrigin, insecNode, mimeTypeGuess, extra) {
        /*. Debugging hack. DO NOT UNCOMMENT IN PRODUCTION ENVIRONMENTS
        if(contentLocation.spec.search("venkman") != -1) {
            this.logger.log(3, "chrome-venk");
            return ok;
        }*/

        if(!insecNode) {
            // Happens on startup
            this.logger.log(3, "Skipping no insec: "+contentLocation.spec);
            return ok;
        }

        if(!this.isolate_content) {
            this.logger.eclog(2, "Content policy disabled");
            return ok;
        }
            
        this.logger.log(1, "Cpolicy load of: "+contentLocation.spec+" from: "+
                        (( null == requestOrigin ) ? "<null>" : requestOrigin.spec));

        var utmp = null;
        try { utmp = unwrapURL(contentLocation.spec, false); } 
        catch(e) { this.logger.log(5, "Exception on unwrap: "+e); }
        
        if(utmp instanceof Ci.nsIURI) {
            utmp = utmp.QueryInterface(Ci.nsIURI);            
            contentLocation = utmp;
            this.logger.log(2, "Unwrapped cpolicy load of: "+contentLocation.spec+" from: "+
                            (( null == requestOrigin ) ? "<null>" : requestOrigin.spec));
        }

        if (!requestOrigin || !requestOrigin.scheme) {
            if (this.tor_enabling) {
                // in FF3, at startup requestOrigin is not set
                if (("chrome" == contentLocation.scheme) && (contentLocation.host in browserSources)) {
                    this.logger.eclog(1, "Allowing browser chrome request from: " +
                                      "<null>" + " for: " +
                                      contentLocation.spec);
                    return ok;
                }
                this.logger.eclog(4, "NO ORIGIN! Blockng request for: "+contentLocation.spec);
                return block;
            }
        } else {
            // rules based on request origin:
            // 1) privileged schemes can access local content but 
            //    must be checked for network access (favicons)
            // 2) locally privileged schemes can access local content
            // 3) forbidden schemes should be blocked
            // 4) all others cannot access any (unwrapped) local content
            //    exceptions:
            //    4a) any content can potentially access 'about:blank'
            //    4b) browser chrome requests are allowed
            // 
            switch (requestOrigin.scheme) {
            case "x-jsd":
            case "chrome":
                // privileged
                if ((contentLocation.scheme in localSchemes) ||
                    (contentLocation.scheme in hostFreeSchemes)) {
                    return ok;
                }
                // Chrome can source favicons from non-local protocols.
                // This needs to be checked below.
                break;
            case "about":
            case "resource":
                // privileged
                return ok;
                break;
            case "view-source":
            case "file":
                // locally privileged
                if ((contentLocation.scheme in localSchemes) ||
                    (contentLocation.scheme in hostFreeSchemes)) {
                    this.logger.eclog(1, "Accepted request from locally privileged scheme: " +
                                      requestOrigin.scheme + " for: " +
                                      contentLocation.spec);
                    return ok;
                } else {
                    if (this.block_tor_file_net && this.tor_enabling ||
                            this.block_nontor_file_net && !this.tor_enabling) {
                        this.logger.eclog(4, "Blocking remote request from: " +
                                          requestOrigin.spec + " for: " +
                                          contentLocation.spec);
                        return block;
                    }
                }
                break;
            case "moz-nullprincipal":
                // forbidden
                if (this.tor_enabling) {
                    this.logger.eclog(4, "Blocking request from: " +
                                      requestOrigin.spec + " for: " +
                                      contentLocation.spec);
                    return block;
                }
                break;
            default:
                if (contentLocation.scheme in localSchemes) {
                    var targetScheme = contentLocation.scheme;
                    var targetHost = "";
                    if ( !(contentLocation.scheme in hostFreeSchemes) ) {
                        try {
                            targetHost = contentLocation.host;
                        } catch(e) {
                            this.logger.eclog(4, "No host from: " +
                                    requestOrigin.spec + " for: " +
                                    contentLocation.spec);
                        }
                    }

                    if (("about:blank" == contentLocation.spec)) {
                        // ok, but don't return
                    } else if (("chrome" == targetScheme) && (targetHost in browserSources)) {
                        this.logger.eclog(1, "Allowing browser chrome request from: " +
                                          requestOrigin.spec + " for: " +
                                          contentLocation.spec);
                        return ok;
                    } else {
                        if (this.tor_enabling || ("torbutton" == targetHost)) {
                            this.logger.eclog(4, "Blocking local request from: "
                                              +requestOrigin.spec+" ("
                                              +requestOrigin.scheme+") for: "+
                                              contentLocation.spec);
                            return block;
                        }
                    }
                }
            }
        }

        var node = wrapNode(insecNode);
        var wind = getWindow(node);

		// For frame elements go to their window
		if (contentType == CPolicy.TYPE_SUBDOCUMENT && node.contentWindow) {
			node = node.contentWindow;
			wind = node;
		}

        if (contentType == 5) { // Object
            // Never seems to happen.. But it would be nice if we 
            // could handle it either here or shouldProcess, instead of in 
            // the webprogresslistener
            if(this.tor_enabling && this.no_tor_plugins) {
                this.logger.log(4, "Blocking object at "+contentLocation.spec);
                return block;
            }
        }

        if (!wind || !wind.top.location || !wind.top.location.href) {
            this.logger.log(4, "Skipping no location: "+contentLocation.spec);
			return ok;
        }


        var doc = wind.top.document;
        if(!doc) {
            // 1st load of a page in a new location
            this.logger.log(3, "Skipping no doc: "+contentLocation.spec);
            return ok;
        }

        var browser;
        if(wind.top.opener && 
            !(wind.top.opener instanceof Components.interfaces.nsIDOMChromeWindow)) {
            this.logger.log(3, "Popup found: "+contentLocation.spec);
            browser = this.wm.getBrowserForContentWindow(wind.top.opener.top)
        } else {
            browser = this.wm.getBrowserForContentWindow(wind.top);
        }

        if(!browser) {
            this.logger.log(5, "No window found: "+contentLocation.spec);
            return block; 
        }

        // For javascript links (and others?) the normal http events
        // for the weblistener in torbutton.js are suppressed
        if(this.tor_enabling && node instanceof Ci.nsIDOMWindow) {
            var wm = Cc["@mozilla.org/appshell/window-mediator;1"]
                         .getService(Components.interfaces.nsIWindowMediator);
            var chrome = wm.getMostRecentWindow("navigator:browser");

            this.logger.eclog(2, "Hooking iframe domwindow");
            // It doesn't really matter which chome window does the hooking.
            chrome.torbutton_hookdoc(node, null);
        }

        // source window of browser chrome window with a document content
        // type means the user entered a new URL.
        if(wind.top instanceof Components.interfaces.nsIDOMChromeWindow) {
            // This happens on non-browser chrome: updates, dialogs, etc
            if (!wind.top.browserDOMWindow 
                    && typeof(browser.__tb_tor_fetched) == 'undefined') {
                this.logger.log(3, "Untagged window for "+contentLocation.spec);
                return ok;
            }

            if(wind.top.browserDOMWindow 
                    && contentType == CPolicy.TYPE_DOCUMENT) {
                this.logger.log(3, "New location for "+contentLocation.spec+" (currently: "+wind.top.location+" and "+browser.currentURI.spec+")");
                // Workaround for Firefox Bug 409737.
                // This disables window.location style redirects if the tor state
                // has changed
                if(requestOrigin) {
                    this.logger.log(3, "Origin: "+requestOrigin.spec);
                    if(!requestOrigin.schemeIs("chrome")) {
                        if(typeof(browser.__tb_tor_fetched) == 'undefined') {
                            // This happens for "open in new window" context menu
                            this.logger.log(3, "Untagged window for redirect "+contentLocation.spec);
                            return ok;
                        }
                        if(browser.__tb_tor_fetched == this.tor_enabled
                                && browser.__tb_tor_fetched == this.settings_applied) {
                            return ok;
                        } else {
                            this.logger.log(4, "Blocking redirect: "+contentLocation.spec);
                            return block;
                        }
                    }
                }
                return ok;
            }
        }

        if(browser.__tb_tor_fetched == this.tor_enabled
                && browser.__tb_tor_fetched == this.settings_applied) {
            return ok;
        } else {
            this.logger.log(4, "Blocking cross state load of: "+contentLocation.spec);
            return block;
        }
	},

	shouldProcess: function(contentType, contentLocation, requestOrigin, insecNode, mimeType, extra) {
        // Were this actually ever called, it might be useful :(
        // Instead, related functionality has been grafted onto the 
        // webprogresslistener :(	
        // See mozilla bugs 380556, 305699, 309524
        if(contentLocation) {
            this.logger.log(2, "Process for "+contentLocation.spec);
        }
        return ok;
	},

    // Pref observer interface implementation
  
    // topic:   what event occurred
    // subject: what nsIPrefBranch we're observing
    // data:    which pref has been changed (relative to subject)
    observe: function(subject, topic, data)
    {
        if (topic != "nsPref:changed") return;
        switch (data) {
            case "extensions.torbutton.isolate_content":
                this.isolate_content = this._prefs.getBoolPref("extensions.torbutton.isolate_content");
                break;
            case "extensions.torbutton.tor_enabled":
                this.tor_enabled = this._prefs.getBoolPref("extensions.torbutton.tor_enabled");
                this.tor_enabling = this.tor_enabled || this.settings_applied; // Catch transition edge cases
                break;
            case "extensions.torbutton.settings_applied":
                this.settings_applied = this._prefs.getBoolPref("extensions.torbutton.settings_applied");
                this.tor_enabling = this.tor_enabled || this.settings_applied; // Catch transition edge cases
                break;
            case "extensions.torbutton.block_tor_file_net":
                this.block_tor_file_net = this._prefs.getBoolPref("extensions.torbutton.block_tor_file_net");
                break;
            case "extensions.torbutton.block_nontor_file_net":
                this.block_nontor_file_net = this._prefs.getBoolPref("extensions.torbutton.block_nontor_file_net");
                break;
            case "extensions.torbutton.no_tor_plugins":
                this.no_tor_plugins = this._prefs.getBoolPref("extensions.torbutton.no_tor_plugins");
                break;
        }
    }
};

/*
 * Factory object
 */

var ContentPolicyInstance = null;

const factory = {
	// nsIFactory interface implementation
	createInstance: function(outer, iid) {
		if (outer != null) {
           Components.returnCode = Cr.NS_ERROR_NO_AGGREGATION;
           return null;
       }

        if (!iid.equals(Components.interfaces.nsIContentPolicy) &&
                !iid.equals(Components.interfaces.nsISupports)) {
            Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;          
            return null;
        }

        if(!ContentPolicyInstance)
            ContentPolicyInstance = new ContentPolicy();

		return ContentPolicyInstance;
	},

	// nsISupports interface implementation
	QueryInterface: function(iid) {
		if (iid.equals(Components.interfaces.nsISupports) ||
				iid.equals(Components.interfaces.nsIModule) ||
				iid.equals(Components.interfaces.nsIFactory))
			return this;

        /*
		if (!iid.equals(Components.interfaces.nsIClassInfo))
			dump("CSS Blocker: factory.QI to an unknown interface: " + iid + "\n");
        */

        Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;          
        return null;   
	}
};


/*
 * Module object
 */
const module = {
	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(CSSB_CID, 
										"Torbutton content policy",
										CSSB_CONTRACTID,
										fileSpec, location, type);

		var catman = Components.classes["@mozilla.org/categorymanager;1"]
					 .getService(Components.interfaces.nsICategoryManager);
		catman.addCategoryEntry("content-policy", CSSB_CONTRACTID,
							CSSB_CONTRACTID, true, true);
	},

	unregisterSelf: function(compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);

		compMgr.unregisterFactoryLocation(CSSB_CID, fileSpec);
		var catman = Components.classes["@mozilla.org/categorymanager;1"]
					   .getService(Components.interfaces.nsICategoryManager);
		catman.deleteCategoryEntry("content-policy", CSSB_CONTRACTID, true);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (cid.equals(CSSB_CID))
            return factory;

        Components.returnCode = Cr.NS_ERROR_NOT_REGISTERED;
        return null;
	},

	canUnload: function(compMgr) {
		return true;
	}
};

function NSGetModule(comMgr, fileSpec) {
	return module;
}


