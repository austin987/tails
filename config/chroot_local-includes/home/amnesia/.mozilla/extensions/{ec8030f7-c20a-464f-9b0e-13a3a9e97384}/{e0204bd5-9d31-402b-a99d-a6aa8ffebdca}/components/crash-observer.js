/*************************************************************************
 * Crash observer (JavaScript XPCOM component)
 *
 * Provides the chrome with a notification ("extensions.torbutton.crashed"
 * pref event) that the browser in fact crashed. Does this by hooking
 * the sessionstore.
 *
 *************************************************************************/

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cr = Components.results;

// Module specific constants
const kMODULE_NAME = "Session crash detector";
const kMODULE_CONTRACTID = "@mozilla.org/browser/sessionstartup;1";
const kMODULE_CID = Components.ID("9215354b-1787-4aef-9946-780f046c75a9");

/* Mozilla defined interfaces */
const kREAL_STORE_CID = "{ec7a6c20-e081-11da-8ad9-0800200c9a66}";
const kREAL_STORE = Components.classesByID[kREAL_STORE_CID];
const kStoreInterfaces = ["nsISessionStartup", "nsIObserver", 
                          "nsISupportsWeakReference"];

var StartupObserver = {
    observe: function(aSubject, aTopic, aData) {
      if(aTopic == "final-ui-startup") {
          Components.classes["@mozilla.org/preferences-service;1"]
              .getService(Components.interfaces.nsIPrefBranch)
              .setBoolPref("extensions.torbutton.startup", true);
      } 
    },
};

function StoreWrapper() {
  this._prefs = Components.classes["@mozilla.org/preferences-service;1"]
      .getService(Components.interfaces.nsIPrefBranch);

  this.logger = Components.classes["@torproject.org/torbutton-logger;1"]
      .getService(Components.interfaces.nsISupports).wrappedJSObject;
  //dump("New crash observer\n");
  this.logger.log(3, "New StoreWrapper");

  this._store = function() {
    var store = kREAL_STORE.getService();
    for (var i = 0; i < kStoreInterfaces.length; i++) {
      store.QueryInterface(Components.interfaces[kStoreInterfaces[i]]);
    }
    return store;
  };

  this.copyMethods(this._store());
}

StoreWrapper.prototype =
{
  QueryInterface: function(iid) {

    if (iid.equals(Components.interfaces.nsISupports)) {
        return this;
    }

    if(iid.equals(Components.interfaces.nsIClassInfo)) {
      var ret = this._store().QueryInterface(iid);
      //dump("classInfo: "+ret.classID);
      return ret;
    }

    try {
        var store = this._store().QueryInterface(iid);
        if (store) this.copyMethods(store);
    } catch(e) {
        //dump("Exception on QI for crash detector\n");
        Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
        return null;
    }
    return this;
  },

  /* 
   * Copies methods from the true sessionstore object we are wrapping
   */
  copyMethods: function(wrapped) {
    var mimic = function(newObj, method) {
      if(typeof(wrapped[method]) == "function") {
          // Code courtesy of timeless: 
          // http://www.webwizardry.net/~timeless/windowStubs.js
          var params = [];
          params.length = wrapped[method].length;
          var x = 0;
          if(params.length) call = "("+params.join().replace(/(?:)/g,function(){return "p"+(++x)})+")";
          else call = "()";
          var fun = "(function "+call+"{if (arguments.length < "+wrapped[method].length+") throw Components.results.NS_ERROR_XPC_NOT_ENOUGH_ARGS; return wrapped."+method+".apply(wrapped, arguments);})";
          // already in scope
          //var Components = this.Components;
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

  observe: function(aSubject, aTopic, aData) {
    if(aTopic == "app-startup") {
      //dump("App startup\n");
      this.logger.log(3, "Got app-startup");
      this._startup = true;
      var observerService = Cc["@mozilla.org/observer-service;1"].
          getService(Ci.nsIObserverService);

      observerService.addObserver(StartupObserver, "final-ui-startup", false);
    } 
    this._store().observe(aSubject, aTopic, aData);
  },

  doRestore: function() {
    var ret = false;
    // FIXME: This happens right after an extension upgrade too. But maybe
    // that's what we want.

    // This is so lame. But the exposed API is braindead so it 
    // must be hacked around
    //dump("new doRestore\n");
    this.logger.log(3, "Got doRestore");
    ret = this._store().doRestore();
    if(this._startup) {
        if(ret) {
           this._prefs.setBoolPref("extensions.torbutton.crashed", true);
        } else {
           this._prefs.setBoolPref("extensions.torbutton.noncrashed", true);
        }
    } 
    this._startup = false;
    return ret;
  },
};
 
const StoreWrapperFactory = {

  createInstance: function(aOuter, aIID) {
    if (aOuter != null) {
      Components.returnCode = Cr.NS_ERROR_NO_AGGREGATION;
      return null;
    }
    
    return (new StoreWrapper()).QueryInterface(aIID);
  },
  
  lockFactory: function(aLock) { },
  
  QueryInterface: function(aIID) {
    if (!aIID.equals(Ci.nsISupports) && !aIID.equals(Ci.nsIModule) &&
        !aIID.equals(Ci.nsIFactory) && !aIID.equals(Ci.nsISessionStore)) {
      Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
      return null;
    }
    
    return this;
  }
};



/**
 * JS XPCOM component registration goop:
 *
 * Everything below is boring boilerplate and can probably be ignored.
 */

var StoreWrapperModule = new Object();

StoreWrapperModule.registerSelf = 
function (compMgr, fileSpec, location, type){
  var nsIComponentRegistrar = Components.interfaces.nsIComponentRegistrar;
  compMgr = compMgr.QueryInterface(nsIComponentRegistrar);
  compMgr.registerFactoryLocation(kMODULE_CID,
                                  kMODULE_NAME,
                                  kMODULE_CONTRACTID,
                                  fileSpec, 
                                  location, 
                                  type);
  //dump("Registered crash observer\n");
};

StoreWrapperModule.getClassObject = function (compMgr, cid, iid)
{
  if (cid.equals(kMODULE_CID)) {
      return StoreWrapperFactory;
  }
  Components.returnCode = Cr.NS_ERROR_NOT_REGISTERED;
  return null;
};

StoreWrapperModule.canUnload = function (compMgr)
{
  return true;
};

function NSGetModule(compMgr, fileSpec)
{
  return StoreWrapperModule;
}

