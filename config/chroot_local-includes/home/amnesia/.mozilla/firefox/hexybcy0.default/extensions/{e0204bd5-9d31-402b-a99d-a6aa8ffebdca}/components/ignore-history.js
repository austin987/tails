/*************************************************************************
 * Ignore History (JavaScript XPCOM component)
 * Disables reading and writing history. This component is implemented as a
 * wrapper around the true history object that sometimes lies about isVisited
 * queries and sometimes ignores addURI commands.
 * Designed as a component of FoxTor, http://cups.cs.cmu.edu/foxtor/
 * Copyright 2006, distributed under the same (open source) license as FoxTor
 *
 * Contributor(s):
 *         Collin Jackson <mozilla@collinjackson.com>
 *
 *************************************************************************/

// Module specific constants
const kMODULE_NAME = "Ignore History";
const kMODULE_CONTRACTID2 = "@mozilla.org/browser/global-history;2";
const kMODULE_CONTRACTID3 = "@mozilla.org/browser/nav-history-service;1";
const kMODULE_CID = Components.ID("bc666d45-a9a1-4096-9511-f6db6f686881");

/* Mozilla defined interfaces for FF3.0 and 2.0 */
const kREAL_HISTORY_CID3 = "{88cecbb7-6c63-4b3b-8cd4-84f3b8228c69}";
const kREAL_HISTORY_CID2 = "{59648a91-5a60-4122-8ff2-54b839c84aed}";

// const kREAL_HISTORY = Components.classesByID[kREAL_HISTORY_CID];

const kHistoryInterfaces2 = [ "nsIBrowserHistory", "nsIGlobalHistory2" ];

const kHistoryInterfaces3 = [ "nsIBrowserHistory", "nsIGlobalHistory2", 
                             "nsIAutoCompleteSearch", "nsIGlobalHistory3",
                             "nsIDownloadHistory", "nsIBrowserHistory",
                             "nsIAutoCompleteSimpleResultListener",
                             "nsINavHistoryService" ];

const Cr = Components.results;

var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
                .getService(Components.interfaces.nsIXULAppInfo);
var versionChecker = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
                       .getService(Components.interfaces.nsIVersionComparator);
var is_ff3 = (versionChecker.compare(appInfo.version, "3.0a1") >= 0);



function HistoryWrapper() {
  this.logger = Components.classes["@torproject.org/torbutton-logger;1"]
      .getService(Components.interfaces.nsISupports).wrappedJSObject;
  this.logger.log(3, "Component Load 3: New HistoryWrapper "+kMODULE_CONTRACTID3);

  // assuming we're running under Firefox
  var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
      .getService(Components.interfaces.nsIXULAppInfo);
  var versionChecker = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
      .getService(Components.interfaces.nsIVersionComparator);

  if(versionChecker.compare(appInfo.version, "3.0a1") >= 0) {
    this._real_history = Components.classesByID[kREAL_HISTORY_CID3];
    this._interfaces = kHistoryInterfaces3;
  } else {
    this._real_history = Components.classesByID[kREAL_HISTORY_CID2];
    this._interfaces = kHistoryInterfaces2;
  }

  this._prefs = Components.classes["@mozilla.org/preferences-service;1"]
      .getService(Components.interfaces.nsIPrefBranch);

  this._history = function() {
    var history = this._real_history.getService();
    for (var i = 0; i < this._interfaces.length; i++) {
      history.QueryInterface(Components.interfaces[this._interfaces[i]]);
    }
    return history;
  };
    
  this.copyMethods(this._history());
}

HistoryWrapper.prototype =
{
  QueryInterface: function(iid) {
    if (iid.equals(Components.interfaces.nsIClassInfo)
        || iid.equals(Components.interfaces.nsISupports)) {
      return this;
    }

    var history = this._history().QueryInterface(iid);
    this.copyMethods(history);
    return this;
  },

  // make this an nsIClassInfo object
  flags: Components.interfaces.nsIClassInfo.DOM_OBJECT,

  // method of nsIClassInfo
  classDescription: "@mozilla.org/browser/global-history;2",
  contractID: "@mozilla.org/browser/global-history;2",
  classID: kMODULE_CID,

  // method of nsIClassInfo
  getInterfaces: function(count) {
    var interfaceList = [Components.interfaces.nsIClassInfo];
    for (var i = 0; i < this._interfaces.length; i++) {
      interfaceList.push(Components.interfaces[this._interfaces[i]]);
    }

    count.value = interfaceList.length;
    return interfaceList;
  },

  // method of nsIClassInfo  
  getHelperForLanguage: function(count) { return null; },


  /*
   * Determine whether we should hide visited links
   */
  // FIXME: Make observer?
  blockReadHistory: function() {
    return ((this._prefs.getBoolPref("extensions.torbutton.block_thread") 
            && this._prefs.getBoolPref("extensions.torbutton.tor_enabled"))
            || 
           (this._prefs.getBoolPref("extensions.torbutton.block_nthread") 
            && !this._prefs.getBoolPref("extensions.torbutton.tor_enabled")));
  },

  blockWriteHistory: function() {
    return ((this._prefs.getBoolPref("extensions.torbutton.block_thwrite") 
            && this._prefs.getBoolPref("extensions.torbutton.tor_enabled"))
            || 
           (this._prefs.getBoolPref("extensions.torbutton.block_nthwrite") 
            && !this._prefs.getBoolPref("extensions.torbutton.tor_enabled")));
  },


  /* 
   * Copies methods from the true history object we are wrapping
   */
  copyMethods: function(wrapped) {
    // XXX: "Not all histories implement all methods"? wtf?? It's a 
    // damned service. how are there more than one?
    //  - http://developer.mozilla.org/en/docs/nsIGlobalHistory3
    var mimic = function(newObj, method) {
       if(method == "getURIGeckoFlags" || method == "setURIGeckoFlags") {
          // Hack to deal with unimplemented methods.
          // XXX: the API docs say to RETURN the not implemented error
          // for these functions as opposed to throw.. Also,
          // what other "histories" actually DO implement these functions?
          // Did we just break them somehow?
          var fun = "(function (){return Components.results.NS_ERROR_NOT_IMPLEMENTED; })";
          newObj[method] = eval(fun);
       } else if(typeof(wrapped[method]) == "function") {
          // Code courtesy of timeless: 
          // http://www.webwizardry.net/~timeless/windowStubs.js
          var params = [];
          params.length = wrapped[method].length;
          var x = 0;
          var call;
          if(params.length) call = "("+params.join().replace(/(?:)/g,function(){return "p"+(++x)})+")";
          else call = "()";
          var fun = "(function "+call+"{if (arguments.length < "+wrapped[method].length+") throw Components.results.NS_ERROR_XPC_NOT_ENOUGH_ARGS; return wrapped."+method+".apply(wrapped, arguments);})";
          newObj[method] = eval(fun);
       } else {
          newObj.__defineGetter__(method, function() { return wrapped[method]; });
          newObj.__defineSetter__(method, function(val) { wrapped[method] = val; });
      }
    };
    for (var method in wrapped) {
      if(typeof(this[method]) == "undefined") mimic(this, method);
    }
  },

  /* 
   * Maybe lie about whether link was visited
   */ 
  isVisited: function(aURI) {
    return (!this.blockReadHistory() && 
            this._history().isVisited(aURI));
  },

  /*
   * Maybe add the URI to the history
   */
  addURI: function(aURI, redirect, toplevel, referrer) { 
    if(!this.blockWriteHistory())
      this._history().addURI(aURI, redirect, toplevel, referrer);
  },

  /*
   * Maybe set the title of a URI in the history
   */
  setPageTitle: function(URI, title) {
    if(!this.blockWriteHistory())
      this._history().setPageTitle(URI, title);
  },

  markPageAsTyped: function(aUri) {
      if(this.blockWriteHistory()) {
          return;
      }
      return this._history().markPageAsTyped(aUri);
  },

  addPageWithDetails: function(aUri, aTitle, aVisited) { 
      if(this.blockWriteHistory()) {
          return;
      }
      return this._history().addPageWithDetails(aUri, aTitle, aVisited);
  },

  setPageTitle: function(aUri, aTitle) {
      if(this.blockWriteHistory()) {
          return;
      }
      return this._history().setPageTitle(aUri, aTitle);
  },

  count getter: function() { return this._history().count; },
};

// Block firefox3 history writes..
if(is_ff3) {
    // addDocumentRedirect() - currently not needed. It does not touch the DB


    // XXX: hrmm...
    HistoryWrapper.prototype.setPageDetails = function(aUri, aTitle, aVisitCnt, aHidden, aTyped) {
        if(this.blockWriteHistory()) {
            return;
        }
        return this._history().setPageDetails(aUri, aTitle, aVisitCnt, aHidden, aTyped);
    };

    HistoryWrapper.prototype.markPageAsFollowedBookmark = function(aUri) {
        if(this.blockWriteHistory()) {
            return;
        }
        return this._history().markPageAsFollowedBookmark(aUri);
    };

    // This gets addVisited
    HistoryWrapper.prototype.canAddURI = function(aUri) {
        if(this.blockWriteHistory()) {
            return false;
        }
        return this._history().canAddURI(aUri);
    };

}
 
var HistoryWrapperSingleton = null;
var HistoryWrapperFactory = new Object();

HistoryWrapperFactory.createInstance = function (outer, iid)
{
  if (outer != null) {
    Components.returnCode = Cr.NS_ERROR_NO_AGGREGATION;
    return null;
  }
  /*
  if (!iid.equals(Components.interfaces.nsIGlobalHistory2) &&
      !iid.equals(Components.interfaces.nsIBrowserHistory) &&
    !iid.equals(Components.interfaces.nsISupports)) {

    dump("Holla noint: "+iid.toString() +"\n");
    Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
    return null;
  }*/

  if(!HistoryWrapperSingleton)
    HistoryWrapperSingleton = new HistoryWrapper();

  return HistoryWrapperSingleton;
};


/**
 * JS XPCOM component registration goop:
 *
 * Everything below is boring boilerplate and can probably be ignored.
 */

var HistoryWrapperModule = new Object();

HistoryWrapperModule.registerSelf = 
function (compMgr, fileSpec, location, type) {
  var nsIComponentRegistrar = Components.interfaces.nsIComponentRegistrar;
  compMgr = compMgr.QueryInterface(nsIComponentRegistrar);
  compMgr.registerFactoryLocation(kMODULE_CID,
                                  kMODULE_NAME,
                                  kMODULE_CONTRACTID2,
                                  fileSpec, 
                                  location, 
                                  type);

  var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
      .getService(Components.interfaces.nsIXULAppInfo);
  var versionChecker = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
      .getService(Components.interfaces.nsIVersionComparator);
  if(versionChecker.compare(appInfo.version, "3.0a1") >= 0) {
      compMgr.registerFactoryLocation(kMODULE_CID,
              kMODULE_NAME,
              kMODULE_CONTRACTID3,
              fileSpec, 
              location, 
              type);
  }
};

HistoryWrapperModule.getClassObject = function (compMgr, cid, iid)
{
  if (cid.equals(kMODULE_CID))
    return HistoryWrapperFactory;

  Components.returnCode = Cr.NS_ERROR_NOT_REGISTERED;
  return null;
};

HistoryWrapperModule.canUnload = function (compMgr)
{
  return true;
};

function NSGetModule(compMgr, fileSpec)
{
  return HistoryWrapperModule;
}

