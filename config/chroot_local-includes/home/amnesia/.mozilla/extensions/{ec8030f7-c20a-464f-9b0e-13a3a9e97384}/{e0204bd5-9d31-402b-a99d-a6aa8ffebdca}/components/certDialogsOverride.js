/*************************************************************************
 * Hack to disable CA cert trust dialog popup during CA cert import
 * during Tor toggle (since we save the trust bits to disk).
 *
 *************************************************************************/

// Module specific constants
const kMODULE_NAME = "CA Cert Dialogs";
const kMODULE_CONTRACTID = "@mozilla.org/nsCertificateDialogs;1";
const kMODULE_CID = Components.ID("6AB9E86E-2459-11DD-AEBC-679A55D89593");

/* Mozilla defined interfaces for FF3.0 and 2.0 */
const kREAL_CERTDIALOG_CID = "{518e071f-1dd2-11b2-937e-c45f14def778}";

const kCertDialogsInterfaces2 = [ "nsIBadCertListener", "nsIClientAuthDialogs", 
                             "nsIDOMCryptoDialogs", 
                             "nsICertificateDialogs", "nsITokenPasswordDialogs",
                             "nsITokenDialogs", "nsICertPickDialogs",
                             "nsIGeneratingKeypairInfoDialogs"];

const kCertDialogsInterfaces3 = 
                             [ "nsIClientAuthDialogs", "nsIDOMCryptoDialogs", 
                             "nsICertificateDialogs", "nsITokenPasswordDialogs",
                             "nsITokenDialogs", "nsICertPickDialogs",
                             "nsIGeneratingKeypairInfoDialogs"];

const Cr = Components.results;

function CertDialogsWrapper() {
  // assuming we're running under Firefox
  var appInfo = Components.classes["@mozilla.org/xre/app-info;1"]
      .getService(Components.interfaces.nsIXULAppInfo);
  var versionChecker = Components.classes["@mozilla.org/xpcom/version-comparator;1"]
      .getService(Components.interfaces.nsIVersionComparator);

  this._real_certdlg = Components.classesByID[kREAL_CERTDIALOG_CID];
  if(versionChecker.compare(appInfo.version, "3.0a1") >= 0) {
    this._interfaces = kCertDialogsInterfaces3;
  } else {
    this._interfaces = kCertDialogsInterfaces2;
  }
 
  this._prefs = Components.classes["@mozilla.org/preferences-service;1"]
      .getService(Components.interfaces.nsIPrefBranch);
  this.logger = Components.classes["@torproject.org/torbutton-logger;1"]
      .getService(Components.interfaces.nsISupports).wrappedJSObject;

  this._certdlg = function() {
    var certdlg = this._real_certdlg.getService();
    for (var i = 0; i < this._interfaces.length; i++) {
      certdlg.QueryInterface(Components.interfaces[this._interfaces[i]]);
    }
    return certdlg;
  };

  this.copyMethods(this._certdlg());
}

CertDialogsWrapper.prototype =
{
  QueryInterface: function(iid) {
    if (/*iid.equals(Components.interfaces.nsIClassInfo)
        || */iid.equals(Components.interfaces.nsISupports)) {
      return this;
    }

    var certdlg = this._certdlg().QueryInterface(iid);
    this.copyMethods(certdlg);
    return this;
  },

  /* 
   * Copies methods from the true history object we are wrapping
   */
  copyMethods: function(wrapped) {
    var mimic = function(newObj, method) {
      if(typeof(wrapped[method]) == "function") {
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
          //dump("wrapped: "+method+": "+fun+"\n");
      } else {
          newObj.__defineGetter__(method, function() { return wrapped[method]; });
          newObj.__defineSetter__(method, function(val) { wrapped[method] = val; });
      }
    };
    for (var method in wrapped) {
      if(typeof(this[method]) == "undefined") mimic(this, method);
    }
  },

  confirmDownloadCACert: function(ctx, cert, trust) { 
    this.logger.log(2, "Cert window");
    if(this._prefs.getBoolPref("extensions.torbutton.block_cert_dialogs")) {
      this.logger.log(3, "Blocking cert window");
      return true;
    }
    return this._certdlg().confirmDownloadCACert(ctx, cert, trust);
  }

};
 
var CertDialogsWrapperSingleton = null;
var CertDialogsWrapperFactory = new Object();

CertDialogsWrapperFactory.createInstance = function (outer, iid)
{
  if (outer != null) {
    Components.returnCode = Cr.NS_ERROR_NO_AGGREGATION;
    return null;
  }

  if(!CertDialogsWrapperSingleton)
    CertDialogsWrapperSingleton = new CertDialogsWrapper();

  return CertDialogsWrapperSingleton;
};


/**
 * JS XPCOM component registration goop:
 *
 * Everything below is boring boilerplate and can probably be ignored.
 */

var CertDialogsWrapperModule = new Object();

CertDialogsWrapperModule.registerSelf = 
function (compMgr, fileSpec, location, type) {
  var nsIComponentRegistrar = Components.interfaces.nsIComponentRegistrar;
  compMgr = compMgr.QueryInterface(nsIComponentRegistrar);
  compMgr.registerFactoryLocation(kMODULE_CID,
                                  kMODULE_NAME,
                                  kMODULE_CONTRACTID,
                                  fileSpec, 
                                  location, 
                                  type);
};

CertDialogsWrapperModule.getClassObject = function (compMgr, cid, iid)
{
  if (cid.equals(kMODULE_CID))
    return CertDialogsWrapperFactory;

  Components.returnCode = Cr.NS_ERROR_NOT_REGISTERED;
  return null;
};

CertDialogsWrapperModule.canUnload = function (compMgr)
{
  return true;
};

function NSGetModule(compMgr, fileSpec)
{
  return CertDialogsWrapperModule;
}

