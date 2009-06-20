/***************************************************************************
Name: CS Lite
Description: Control cookie permissions.
Author: Ron Beckman
Homepage: http://addons.mozilla.org

Copyright (C) 2007  Ron Beckman

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to:

Free Software Foundation, Inc.
51 Franklin Street
Fifth Floor
Boston, MA  02110-1301
USA
***************************************************************************/


var cookiesafeCookieObserver = {

	init: function() {
		var os = this.getObserver();
		os.addObserver(this, 'cookie-changed', false);
		os.addObserver(this, 'cookie-rejected', false);
	},

	uninit: function() {
		var os = this.getObserver();
		os.removeObserver(this, 'cookie-changed');
		os.removeObserver(this, 'cookie-rejected');
	},

	QueryInterface : function(aIID) {
		if (aIID.equals(Components.interfaces.nsISupports) ||
		    aIID.equals(Components.interfaces.nsIObserver))
			return this;
		throw Components.results.NS_NOINTERFACE;
	},

	getObserver: function() {
		return Components.classes["@mozilla.org/observer-service;1"].
		getService(Components.interfaces.nsIObserverService);
	},

	getCS: function() {
		return Components.classes['@mozilla.org/CookieSafe;1'].
		createInstance(Components.interfaces.nsICookieSafe);
	},

	getCSLast10Hosts: function() {
		return Components.classes['@mozilla.org/CSLast10Hosts;1'].
		getService(Components.interfaces.nsICSLast10Hosts);
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	getConsole: function() {
		return Components.classes["@mozilla.org/consoleservice;1"].
		getService(Components.interfaces.nsIConsoleService);
	},

	getStrBundle: function() {
		return Components.classes['@mozilla.org/intl/stringbundle;1'].
		getService(Components.interfaces.nsIStringBundleService).
		createBundle('chrome://cookiesafe/locale/cookiesafe.properties');
	},

	observe: function(aSubject, aTopic, aData) {
		var cs = this.getCS();
		var lastten = this.getCSLast10Hosts();
		var prefs = this.getPrefs();
		var console = prefs.getBoolPref('logNotifications');

		if (aSubject) {
			if (aTopic=='cookie-rejected') {
				aSubject.QueryInterface(Components.interfaces.nsIURI);
			}

			if (aSubject instanceof Components.interfaces.nsIURI ||
			    aSubject instanceof Components.interfaces.nsICookie) {
				var host = (aSubject.host) ? aSubject.host : 'scheme:file';
				var base = cs.removeSub(host);
				lastten.addLastTenHosts(base);
			}
		}

		if (console) {
			this.logCookie(aSubject,aData,host);
		}
	},

	logCookie: function(aSubject,aData,host) {
		var bdl = this.getStrBundle();

		//create title
		var title;
		if (!aData) {
			title = bdl.GetStringFromName('cookiesafe.lCookieBlocked');
		} else if (aData=='added') {
			title = bdl.GetStringFromName('cookiesafe.lCookieAdded');
		} else if (aData=='changed') {
			title = bdl.GetStringFromName('cookiesafe.lCookieChanged');
		} else if (aData=='deleted') {
			title = bdl.GetStringFromName('cookiesafe.lCookieDeleted');
		} else if (aData=='cleared') {
			title = bdl.GetStringFromName('cookiesafe.lCookiesCleared');
		}

		//create message
		var msg = title;
		if (aData=='added' || aData=='changed' || aData=='deleted') {
			var exp = new Date();
			if (aSubject.expires) {
				exp.setTime(aSubject.expires * 1000);
			} else {
				exp = bdl.GetStringFromName('cookiesafe.lSession');
			}
			msg += '\n'+bdl.GetStringFromName('cookiesafe.lHost')+': '+host+'\n'+
				    bdl.GetStringFromName('cookiesafe.lName')+': '+aSubject.name+'\n'+
				    bdl.GetStringFromName('cookiesafe.lValue')+': '+aSubject.value+'\n'+
				    bdl.GetStringFromName('cookiesafe.lExpires')+': '+exp;
		} else if (!aData) {
			msg += '\n'+bdl.GetStringFromName('cookiesafe.lHost')+': '+host+'\n'+
				    bdl.GetStringFromName('cookiesafe.lUrl')+': '+aSubject.spec;
		}

		var csl = this.getConsole();
		csl.logStringMessage(msg);
	}
};

var cookiesafeShutdown = {

	QueryInterface : function(aIID) {
		if (aIID.equals(Components.interfaces.nsISupports) ||
		    aIID.equals(Components.interfaces.nsIObserver))
			return this;
		throw Components.results.NS_NOINTERFACE;
	},

	getObserver: function() {
		return Components.classes["@mozilla.org/observer-service;1"].
		getService(Components.interfaces.nsIObserverService);
	},

	init: function() {
		var os = this.getObserver();
		os.addObserver(this, 'quit-application', false);
	},

	uninit: function() {
		var os = this.getObserver();
		os.removeObserver(this, 'quit-application');
	},

	observe: function(aSubject, aTopic, aData) {
		if (aTopic == 'quit-application') {
			//unregister observer for quit-application notifications
			this.uninit();

			//unregister the cookie observers
			cookiesafeCookieObserver.uninit();

			//only uninit the http observer for Thunderbird
			var brows = this.getAppInfo();
			if (brows.name=='Thunderbird') csHttpObserver.uninit();

			//perform cleanup for CS Lite shutdown
			this.exit();
		}
	},

	exit: function() {
		//remove temp exceptions
		this.removeTempExceptions();

		//clear last 10 hosts array
		var lastten = this.getCSLast10Hosts();
		lastten.clearLastTenHosts();

		//clear all cookies and exceptions
		var prefs = this.getPrefs();
		var clck = prefs.getBoolPref('clearCookies');
		var clex = prefs.getBoolPref('clearExceptions');
		if (clck) this.clearCookies2();
		if (clex) this.clearExceptions2();

		//check if browser is TB2 and close db connection if possible
		var brows = this.getAppInfo();
		var num = parseInt(brows.version);
		if (brows.name=='Thunderbird' && num==2) {
			var permMngr = this.getPermManager();
			permMngr.closeDB();
		}
	},

	getCSLast10Hosts: function() {
		return Components.classes['@mozilla.org/CSLast10Hosts;1'].
		getService(Components.interfaces.nsICSLast10Hosts);
	},

	getCSTempExceptions: function() {
		return Components.classes['@mozilla.org/CSTempExceptions;1'].
		getService(Components.interfaces.nsICSTempExceptions);
	},

	getAppInfo: function() {
		return Components.classes['@mozilla.org/xre/app-info;1'].
		createInstance(Components.interfaces.nsIXULAppInfo);
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	getCookieManager: function() {
		return Components.classes["@mozilla.org/cookiemanager;1"].
		getService(Components.interfaces.nsICookieManager);
	},

	getPermManager: function() {
		//check if browser is TB2
		var brows = this.getAppInfo();
		var num = parseInt(brows.version);
		if (brows.name=='Thunderbird' && num==2) {
			return Components.classes["@mozilla.org/CSPermManager;1"].
			getService(Components.interfaces.nsICSPermManager);
		} else {
			return Components.classes["@mozilla.org/permissionmanager;1"].
			getService(Components.interfaces.nsIPermissionManager);
		}
	},

	removeTempExceptions: function() {
		var tempExc = this.getCSTempExceptions();
		var perms = tempExc.getTempExceptions();
		if (!perms) return false;

		//remove temp exceptions
		perms = perms.split(' ');
		var mngr = this.getPermManager();
		for (var i=0; i<perms.length; ++i) {
			if (!perms[i]) continue;
			try {
				mngr.remove(perms[i],'cookie');
			} catch(e) {
				continue;
			}
		}

		//this clears the temp array and the tempExceptions char pref
		tempExc.clearTempExceptions();
		return false;
	},

	clearCookies2: function() {
		var mngr = this.getCookieManager();
		mngr.removeAll();
	},

	clearExceptions2: function() {
		var exc,perms,temp;
		var mngr = this.getPermManager();
		if (mngr instanceof Components.interfaces.nsIPermissionManager) {
			perms = mngr.enumerator;
			while (('hasMoreElements' in perms && perms.hasMoreElements()) ||
				 ('hasMore' in perms && perms.hasMore())) {
				exc = perms.getNext();
				exc.QueryInterface(Components.interfaces.nsIPermission);
				if (exc.type=='cookie') {
					mngr.remove(exc.host,'cookie');
				}
			}
		} else { //for TB2 only
			mngr.removeAll();
		}
	}
};

var csHttpObserver = {

	QueryInterface : function(aIID) {
		if (aIID.equals(Components.interfaces.nsISupports) ||
		    aIID.equals(Components.interfaces.nsIObserver))
			return this;
		throw Components.results.NS_NOINTERFACE;
	},

	getObserver: function() {
		return Components.classes["@mozilla.org/observer-service;1"].
		getService(Components.interfaces.nsIObserverService);
	},

	getAppInfo: function() {
		return Components.classes['@mozilla.org/xre/app-info;1'].
		createInstance(Components.interfaces.nsIXULAppInfo);
	},

	getCS: function() {
		return Components.classes['@mozilla.org/CookieSafe;1'].
		createInstance(Components.interfaces.nsICookieSafe);
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	getGlobalPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("network.cookie.");
	},

	getCookieManager2: function() {
		return Components.classes["@mozilla.org/cookiemanager;1"].
		getService(Components.interfaces.nsICookieManager2);
	},

	getCookieService: function() {
		return Components.classes["@mozilla.org/cookieService;1"].
		getService(Components.interfaces.nsICookieService);
	},

	testPermission: function(host) {
		var url = (host=='scheme:file') ? 'file:///cookiesafe' : 'http://'+host;
		var uri = this.getURI(url);
		var mngr = this.getPermManager();
		var action = mngr.testPermission(uri,'cookie');
		return action;
	},

	getURI: function(url) {
		return Components.classes["@mozilla.org/network/io-service;1"].
		getService(Components.interfaces.nsIIOService).
		newURI(url,null,null);
	},

	getPermManager: function() {
		//check if browser is TB2
		var brows = this.getAppInfo();
		var num = parseInt(brows.version);
		if (brows.name=='Thunderbird' && num==2) {
			return Components.classes["@mozilla.org/CSPermManager;1"].
			getService(Components.interfaces.nsICSPermManager);
		} else {
			return Components.classes["@mozilla.org/permissionmanager;1"].
			getService(Components.interfaces.nsIPermissionManager);
		}
	},

	init: function() {
		var os = this.getObserver();
		os.addObserver(this, 'http-on-modify-request', false);
		os.addObserver(this, 'http-on-examine-response', false);
		os.addObserver(this, 'http-on-examine-merged-response', false);
	},

	uninit: function() {
		var os = this.getObserver();
		os.removeObserver(this, 'http-on-modify-request');
		os.removeObserver(this, 'http-on-examine-response');
		os.removeObserver(this, 'http-on-examine-merged-response');
	},

	observe: function(aSubject, aTopic, aData) {
		if (aTopic == 'app-startup') {
			//register quit-application observer for cookiesafe shutdown tasks
			cookiesafeShutdown.init();

			//register cookie observers for last 10 hosts and cookie logging
			cookiesafeCookieObserver.init();

			//only init the http observer for Thunderbird
			var brows = this.getAppInfo();
			if (brows.name=='Thunderbird') this.init();
			return false;
		}

		try {
			var httpChannel = aSubject.QueryInterface(Components.interfaces.nsIHttpChannel);
			var channelInternal = aSubject.QueryInterface(Components.interfaces.nsIHttpChannelInternal);
			var channel = aSubject.QueryInterface(Components.interfaces.nsIChannel);
		} catch(e) {
			return false;
		}

		/*Thunderbird will automatically strip cookie headers from channels using the https
		protocol.  There is presently NO solution for https uris so we can just return
		instead of trying to process the https cookie headers which will stripped anyway.*/

		if (channel.URI.scheme.substr(0,4) != 'http') return false;

		//make sure user wants CS to process cookies in TB, if more than one http
		//observer is active at a time there could be conflicts with other extensions
		var prefs = this.getPrefs();
		if (!prefs.getBoolPref('processTBCookies')) return false;

		//test whether uri host has permission to set or receive cookies
		var action = this.testPermission(channel.URI.host);

		var gPrefs = this.getGlobalPrefs();
		var behavior = gPrefs.getIntPref('cookieBehavior');

		if (aTopic=='http-on-modify-request') {
			try {
				var reqHead = httpChannel.getRequestHeader("Cookie");
			} catch(e) {
				return false;
			}

			if (!reqHead) {
				if (action==1 || action==8 || (behavior==0 && !action)) {
					var cksrv = this.getCookieService();
					var ckstr = cksrv.getCookieString(channel.URI,null);
					httpChannel.setRequestHeader("Cookie",ckstr,false);
				}
			}
		}

		if (aTopic=='http-on-examine-response' || aTopic=='http-on-examine-merged-response') {
			try {
				var resHead = httpChannel.getResponseHeader("Set-Cookie");
			} catch(e) {
				return false;
			}

			if (resHead) {
				if (action==1 || action==8 || (behavior==0 && !action)) {
					var ck,exp;
					var cs = this.getCS();
					var mngr = this.getCookieManager2();
					var dt = new Date();
					var time = dt.getTime();
					var cookies = resHead.split('\n');
					for (var i=0; i<cookies.length; ++i) {
						ck = cs.formatCookieString(cookies[i],channel.URI);
						exp = (action==8) ? 0 : ck.expires; //ck.expires is readonly so we use a new variable here
						if ('cookieExists' in mngr) {
							mngr.add(ck.host,ck.path,ck.name,ck.value,ck.isSecure,true,
								(!exp) ? true : false,
								(!exp) ? parseInt(time / 1000) + 86400 : exp);
						} else {
							mngr.add(ck.host,ck.path,ck.name,ck.value,ck.isSecure,
								(!exp) ? true : false,
								(!exp) ? parseInt(time / 1000) + 86400 : exp);
						}
					}
					httpChannel.setResponseHeader("Set-Cookie","",false);
				}
			}
		}
		return false;
	}
};

var csHttpModule = {

	registerSelf: function (compMgr, fileSpec, location, type) {
		var compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(this.myCID,
		this.myName,
		this.myProgID,
		fileSpec,
		location,
		type);

		var catMgr = Components.classes["@mozilla.org/categorymanager;1"].
		getService(Components.interfaces.nsICategoryManager);
		catMgr.addCategoryEntry("app-startup", this.myName, this.myProgID, true, true);
	},

	getClassObject: function (compMgr, cid, iid) {
		return this.csHttpFactory;
	},

	myCID: Components.ID("{559f36d9-ef06-42ae-8378-846d452cd244}"),

	myProgID: "@mozilla.org/csHttpObserver;1",

	myName: "CookieSafe Http Observer",

	csHttpFactory: {
		QueryInterface: function (aIID) {
			if (!aIID.equals(Components.interfaces.nsISupports) &&
			    !aIID.equals(Components.interfaces.nsIFactory))
				throw Components.results.NS_ERROR_NO_INTERFACE;
			return this;
		},

		createInstance: function (outer, iid) {
			return csHttpObserver;
		}
	},

	canUnload: function(compMgr) {
		return true;
	}
};

function NSGetModule(compMgr, fileSpec) {
	return csHttpModule;
}
