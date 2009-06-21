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


const CSLAST10HOSTS_CONTRACTID = '@mozilla.org/CSLast10Hosts;1';
const CSLAST10HOSTS_CID = Components.ID('{d4295e7f-ac82-47d5-ab40-a3781cb49980}');
const CSLAST10HOSTS_IID = Components.interfaces.nsICSLast10Hosts;
const CSLAST10HOSTS_SERVICENAME = 'CS Last 10 Hosts';

var nsCSLast10Hosts = {

	hosts: [],

	testLastTenHosts: function(host) {
		for (var i=0; i<this.hosts.length; ++i) {
			if (this.hosts[i]==host) return true;
		}

		return false;
	},

	getLastTenHosts: function() {
		return this.hosts.join(' ');
	},

	addLastTenHosts: function(host) {
		var found = this.testLastTenHosts(host);
		if (!found) {
			this.hosts.unshift(host);
		}

		//make sure the hosts array length does not exceed the numOfHosts pref
		var prefs = this.getPrefs();
		var num = parseInt(prefs.getIntPref('numOfHosts'));
		while (this.hosts.length > num) {
			this.hosts.pop();
		}
	},

	removeLastTenHosts: function(host) {
		this.hosts = this.hosts.filter(function(value) {
								return value != host; 
							 });
	},

	clearLastTenHosts: function() {
		this.hosts = [];
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	QueryInterface: function(iid) {
		if (!iid.equals(Components.interfaces.nsISupports) &&
		    !iid.equals(CSLAST10HOSTS_IID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		return this;
	}
};

var nsCSLast10HostsModule = {

	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(CSLAST10HOSTS_CID,
						CSLAST10HOSTS_SERVICENAME,
						CSLAST10HOSTS_CONTRACTID,
						fileSpec,location,type);
	},

	unregisterSelf: function (compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.unregisterFactoryLocation(CSLAST10HOSTS_CID,fileSpec);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (!cid.equals(CSLAST10HOSTS_CID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		if (!iid.equals(Components.interfaces.nsIFactory))
			throw Components.results.NS_ERROR_NOT_IMPLEMENTED;
		return this.nsCSLast10HostsFactory;
	},

	canUnload: function(compMgr) {
		return true;
	},

	nsCSLast10HostsFactory: {

		createInstance: function(outer, iid) {
			if (outer != null)
				throw Components.results.NS_ERROR_NO_AGGREGATION;
			if (!iid.equals(CSLAST10HOSTS_IID) &&
			    !iid.equals(Components.interfaces.nsISupports))
				throw Components.results.NS_ERROR_INVALID_ARG;
			return nsCSLast10Hosts;
		}
	}
};

function NSGetModule(comMgr, fileSpec) { return nsCSLast10HostsModule; }
