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


const CSTEMPEXCEPTIONS_CONTRACTID = '@mozilla.org/CSTempExceptions;1';
const CSTEMPEXCEPTIONS_CID = Components.ID('{8742629c-8f6a-4787-9c44-2db49b392531}');
const CSTEMPEXCEPTIONS_IID = Components.interfaces.nsICSTempExceptions;
const CSTEMPEXCEPTIONS_SERVICENAME = 'CS Temp Exceptions';

var nsCSTempExceptions = {

	hosts: [],

	testTempExceptions: function(host) {
		for (var i=0; i<this.hosts.length; ++i) {
			if (this.hosts[i]==host) return true;
		}

		return false;
	},

	getTempExceptions: function() {
		return this.hosts.join(' ');
	},

	addTempExceptions: function(host) {
		var found = this.testTempExceptions(host);
		if (!found) {
			this.hosts.push(host);
		}

		//keep track of temp exceptions in a char pref in case browser
		//crashes before all of the temp exceptions have been cleared
		var prefs = this.getPrefs();
		prefs.setCharPref('tempExceptions',this.hosts.join(' '));
	},

	removeTempExceptions: function(host) {
		this.hosts = this.hosts.filter(function(value) {
								return value != host; 
							 });

		//keep track of temp exceptions in a char pref in case browser
		//crashes before all of the temp exceptions have been cleared
		var prefs = this.getPrefs();
		prefs.setCharPref('tempExceptions',this.hosts.join(' '));
	},

	clearTempExceptions: function() {
		this.hosts = [];

		//keep track of temp exceptions in a char pref in case browser
		//crashes before all of the temp exceptions have been cleared
		var prefs = this.getPrefs();
		prefs.setCharPref('tempExceptions','');
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	QueryInterface: function(iid) {
		if (!iid.equals(Components.interfaces.nsISupports) &&
		    !iid.equals(CSTEMPEXCEPTIONS_IID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		return this;
	}
};

var nsCSTempExceptionsModule = {

	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(CSTEMPEXCEPTIONS_CID,
						CSTEMPEXCEPTIONS_SERVICENAME,
						CSTEMPEXCEPTIONS_CONTRACTID,
						fileSpec,location,type);
	},

	unregisterSelf: function (compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.unregisterFactoryLocation(CSTEMPEXCEPTIONS_CID,fileSpec);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (!cid.equals(CSTEMPEXCEPTIONS_CID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		if (!iid.equals(Components.interfaces.nsIFactory))
			throw Components.results.NS_ERROR_NOT_IMPLEMENTED;
		return this.nsCSTempExceptionsFactory;
	},

	canUnload: function(compMgr) {
		return true;
	},

	nsCSTempExceptionsFactory: {

		createInstance: function(outer, iid) {
			if (outer != null)
				throw Components.results.NS_ERROR_NO_AGGREGATION;
			if (!iid.equals(CSTEMPEXCEPTIONS_IID) &&
			    !iid.equals(Components.interfaces.nsISupports))
				throw Components.results.NS_ERROR_INVALID_ARG;
			return nsCSTempExceptions;
		}
	}
};

function NSGetModule(comMgr, fileSpec) { return nsCSTempExceptionsModule; }
