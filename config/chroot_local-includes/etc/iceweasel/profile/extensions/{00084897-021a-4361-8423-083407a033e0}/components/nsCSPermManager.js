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


const CSPERMMANAGER_CONTRACTID = '@mozilla.org/CSPermManager;1';
const CSPERMMANAGER_CID = Components.ID('{4b0a4425-e9d8-441c-a34b-1867d8ca2d3b}');
const CSPERMMANAGER_IID = Components.interfaces.nsICSPermManager;
const CSPERMMANAGER_SERVICENAME = 'CSPermManager';

var nsCSPermManager = {

	_DB: null,

	UNKNOWN_ACTION: 0,
	ALLOW_ACTION: 1,
	DENY_ACTION: 2,

	closeDB: function() {
		if (this._DB && 'close' in this._DB) {
			this._DB.close();
		}
	},

	add: function(uri,type,permission) {
		if (!this._DB) this.openDatabaseConnection();

		if (this._DB) {
			var host = (uri.host) ? uri.host : 'scheme:file';
			var found = this.testPermission(uri,type);
			this._DB.beginTransaction();

			if (!found) {
				try {
					this._DB.executeSimpleSQL("INSERT INTO cookies VALUES('"+host+"','"+permission+"')");
				} catch(e) { }
			} else if (found != permission) {
				try {
					this._DB.executeSimpleSQL("REPLACE INTO cookies VALUES('"+host+"','"+permission+"')");
				} catch(e) { }
			}

			this._DB.commitTransaction();
		}
	},

	remove: function(host,type) {
		if (!this._DB) this.openDatabaseConnection();

		if (this._DB) {
			this._DB.beginTransaction();

			try {
				this._DB.executeSimpleSQL("DELETE FROM cookies WHERE host = '"+host+"'");
			} catch(e) { }

			this._DB.commitTransaction();
		}
	},

	removeAll: function() {
		if (!this._DB) this.openDatabaseConnection();

		if (this._DB) {
			this._DB.beginTransaction();

			try {
				this._DB.executeSimpleSQL("DELETE FROM cookies");
			} catch(e) { }

			this._DB.commitTransaction();
		}
	},

	testPermission: function(uri,type) {
		if (!this._DB) this.openDatabaseConnection();
		if (!this._DB) return false;

		var found = 0;
		var host = (uri.host) ? uri.host : 'scheme:file';
		this._DB.beginTransaction();

		var stmt = this._DB.createStatement("SELECT * FROM cookies WHERE host = '"+host+"'");
		while (stmt.executeStep()) {
			if (stmt.getString(1)) found = stmt.getString(1);
			break;
		}
		stmt.reset();

		//if not found then test for base domain
		if (found==0) {
			var cs = this.getCS();
			var base = cs.removeSub(host);
			if (base!=host) {
				var stmt = this._DB.createStatement("SELECT * FROM cookies WHERE host = '"+base+"'");
				while (stmt.executeStep()) {
					if (stmt.getString(1)) found = stmt.getString(1);
					break;
				}
				stmt.reset();
			}
		}

		this._DB.commitTransaction();
		return found;
	},

	getAllPermissions: function() {
		if (!this._DB) this.openDatabaseConnection();
		if (!this._DB) return '';

		var entries = [];
		this._DB.beginTransaction();

		var stmt = this._DB.createStatement("SELECT * FROM cookies");
		while (stmt.executeStep()) {
			if (stmt.getString(0) && stmt.getString(1)) {
				entries.push(stmt.getString(0) + '|' + stmt.getString(1));
			}
		}
		stmt.reset();

		this._DB.commitTransaction();
		return entries.join(' ');
	},

	copyCSDBToProfile: function() {
		//get nsIFile for profile folder
		var profile = this.getProfile();
		profile.append('cshostperm.sqlite');

		//get location of jar file
		var chromeuri = this.getURI('chrome://cookiesafe/content/sqlite/cshostperm.sqlite');
		var jaruri = this.getJarURI(chromeuri);

		//the uri of the base jar file is needed here so query nsIJARURI
		jaruri.QueryInterface(Components.interfaces.nsIJARURI);
		var jarfile = this.urlToFile(jaruri.JARFile.spec);

		var zipReader = this.getZipReaderForFile(jarfile);

		try {
			var entry;
			var entries = zipReader.findEntries('\*cshostperm.sqlite\$');
			if ('init' in zipReader) {
				while (entries.hasMoreElements()) {
					entry = entries.getNext();
					entry.QueryInterface(Components.interfaces.nsIZipEntry);
					zipReader.extract(entry.name,profile);
					break;
				}
			} else {
				while (entries.hasMore()) {
					entry = entries.getNext();
					zipReader.extract(entry,profile);
					break;
				}
			}
		} catch (e) {
			throw e;
		}

		zipReader.close();
	},

	getURI: function(url) {
		return Components.classes["@mozilla.org/network/io-service;1"].
		getService(Components.interfaces.nsIIOService).
		newURI(url,null,null);
	},

	getJarURI: function(uri) {
		return Components.classes['@mozilla.org/chrome/chrome-registry;1'].
		getService(Components.interfaces.nsIChromeRegistry).
		convertChromeURL(uri);
	},

	urlToFile: function(url) {
		return Components.classes['@mozilla.org/network/protocol;1?name=file'].
		createInstance(Components.interfaces.nsIFileProtocolHandler).
		getFileFromURLSpec(url);
	},

	getZipReaderForFile: function(zipFile) {
		try {
			var zipReader = Components.classes["@mozilla.org/libjar/zip-reader;1"].
			createInstance(Components.interfaces.nsIZipReader);

			if ('init' in zipReader) {
				zipReader.init(zipFile);
				zipReader.open();
			} else {
				zipReader.open(zipFile);
			}
		} catch (e) {
			zipReader.close();
			throw e;
		}
		return zipReader;
	},

	getProfile: function() {
		return Components.classes["@mozilla.org/file/directory_service;1"].
		getService(Components.interfaces.nsIProperties).
		get("ProfD", Components.interfaces.nsIFile);
	},

	getDBService: function() {
		return Components.classes["@mozilla.org/storage/service;1"].
		getService(Components.interfaces.mozIStorageService);
	},

	openDatabaseConnection: function() {
		var dbfile = this.getProfile();
		dbfile.append("cshostperm.sqlite");
		if (!dbfile.exists()) {
			this.copyCSDBToProfile();
			if (!dbfile.exists()) return false;
		}

		var dbService = this.getDBService();
		this._DB = dbService.openDatabase(dbfile);

		if (!this._DB.tableExists("cookies")) {
			this._DB.createTable("cookies", "host STRING PRIMARY KEY, type INTEGER");
		}
		return false;
	},

	getCS: function() {
		return Components.classes['@mozilla.org/CookieSafe;1'].
		createInstance(Components.interfaces.nsICookieSafe);
	},

	getCSHiddenMenuItems: function() {
		return Components.classes['@mozilla.org/CSHiddenMenuItems;1'].
		createInstance(Components.interfaces.nsICSHiddenMenuItems);
	},

	getCSLast10Hosts: function() {
		return Components.classes['@mozilla.org/CSLast10Hosts;1'].
		getService(Components.interfaces.nsICSLast10Hosts);
	},

	getCSTempExceptions: function() {
		return Components.classes['@mozilla.org/CSTempExceptions;1'].
		getService(Components.interfaces.nsICSTempExceptions);
	},

	QueryInterface: function(iid) {
		if (!iid.equals(Components.interfaces.nsISupports) &&
		    !iid.equals(CSPERMMANAGER_IID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		return this;
	}
};

var nsCSPermManagerModule = {

	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(CSPERMMANAGER_CID,
						CSPERMMANAGER_SERVICENAME,
						CSPERMMANAGER_CONTRACTID,
						fileSpec,location,type);
	},

	unregisterSelf: function (compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.unregisterFactoryLocation(CSPERMMANAGER_CID,fileSpec);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (!cid.equals(CSPERMMANAGER_CID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		if (!iid.equals(Components.interfaces.nsIFactory))
			throw Components.results.NS_ERROR_NOT_IMPLEMENTED;
		return this.nsCSPermManagerFactory;
	},

	canUnload: function(compMgr) {
		return true;
	},

	nsCSPermManagerFactory: {

		createInstance: function(outer, iid) {
			if (outer != null)
				throw Components.results.NS_ERROR_NO_AGGREGATION;
			if (!iid.equals(CSPERMMANAGER_IID) &&
			    !iid.equals(Components.interfaces.nsISupports))
				throw Components.results.NS_ERROR_INVALID_ARG;
			return nsCSPermManager;
		}
	}
};

function NSGetModule(comMgr, fileSpec) { return nsCSPermManagerModule; }
