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


const CSHIDDENMENUITEMS_CONTRACTID = '@mozilla.org/CSHiddenMenuItems;1';
const CSHIDDENMENUITEMS_CID = Components.ID('{a7cdbbe6-4e52-4675-884e-b85bb46dac17}');
const CSHIDDENMENUITEMS_IID = Components.interfaces.nsICSHiddenMenuItems;
const CSHIDDENMENUITEMS_SERVICENAME = 'CS Hidden Menu Items';

var nsCSHiddenMenuItems = {

	testHiddenMenuItems: function(id) {
		var prefs = this.getPrefs();
		var ids = prefs.getCharPref('hiddenMenuItems');
		return (ids.indexOf(id)!=-1) ? true : false;
	},

	getHiddenMenuItems: function() {
		var prefs = this.getPrefs();
		var ids = prefs.getCharPref('hiddenMenuItems');
		return ids;
	},

	addHiddenMenuItems: function(id) {
		var found = this.testHiddenMenuItems(id);
		if (!found) {
			var prefs = this.getPrefs();
			var ids = prefs.getCharPref('hiddenMenuItems').split(' ');
			ids.push(id);

			//filter out all of the null values
			ids = ids.filter(function(value) { return value; });

			prefs.setCharPref('hiddenMenuItems',ids.join(' '));
		}
	},

	removeHiddenMenuItems: function(id) {
		var prefs = this.getPrefs();
		var ids = prefs.getCharPref('hiddenMenuItems').split(' ');
		ids = ids.filter(function(value) { return value != id; });
		prefs.setCharPref('hiddenMenuItems',ids.join(' '));
	},

	clearHiddenMenuItems: function() {
		var prefs = this.getPrefs();
		prefs.setCharPref('hiddenMenuItems','');
	},

	getPrefs: function() {
		return Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefService).
		getBranch("cookiesafe.");
	},

	QueryInterface: function(iid) {
		if (!iid.equals(Components.interfaces.nsISupports) &&
		    !iid.equals(CSHIDDENMENUITEMS_IID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		return this;
	}
};

var nsCSHiddenMenuItemsModule = {

	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(CSHIDDENMENUITEMS_CID,
						CSHIDDENMENUITEMS_SERVICENAME,
						CSHIDDENMENUITEMS_CONTRACTID,
						fileSpec,location,type);
	},

	unregisterSelf: function (compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.unregisterFactoryLocation(CSHIDDENMENUITEMS_CID,fileSpec);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (!cid.equals(CSHIDDENMENUITEMS_CID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		if (!iid.equals(Components.interfaces.nsIFactory))
			throw Components.results.NS_ERROR_NOT_IMPLEMENTED;
		return this.nsCSHiddenMenuItemsFactory;
	},

	canUnload: function(compMgr) {
		return true;
	},

	nsCSHiddenMenuItemsFactory: {

		createInstance: function(outer, iid) {
			if (outer != null)
				throw Components.results.NS_ERROR_NO_AGGREGATION;
			if (!iid.equals(CSHIDDENMENUITEMS_IID) &&
			    !iid.equals(Components.interfaces.nsISupports))
				throw Components.results.NS_ERROR_INVALID_ARG;
			return nsCSHiddenMenuItems;
		}
	}
};

function NSGetModule(comMgr, fileSpec) { return nsCSHiddenMenuItemsModule; }
