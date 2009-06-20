/*************************************************************************
 * ContentWindowMapper (JavaScript XPCOM component)
 *
 * Allows you to find a tabbrowser tab for a top level content window.
 *
 *************************************************************************/

// Module specific constants
const kMODULE_NAME = "Content Window Mapper";
const kMODULE_CONTRACTID = "@torproject.org/content-window-mapper;1";
const kMODULE_CID = Components.ID("b985e49c-12cb-4f29-9d14-b62603332ec4");

const Cr = Components.results;
const Cc = Components.classes;
const Ci = Components.interfaces;
const EXPIRATION_TIME = 60000; // 60 seconds

const nsISupports = Components.interfaces.nsISupports;
const nsIClassInfo = Components.interfaces.nsIClassInfo;
const nsIComponentRegistrar = Components.interfaces.nsIComponentRegistrar;
const nsIObserverService = Components.interfaces.nsIObserverService;

function ContentWindowMapper() {
    this.cache = new Object();
    this.cache["bah"] = 0;

    this.logger = Components.classes["@torproject.org/torbutton-logger;1"]
        .getService(Components.interfaces.nsISupports).wrappedJSObject;
    this.last_expired = Date.now();
    // This JSObject is exported directly to chrome
    this.wrappedJSObject = this;
}

ContentWindowMapper.prototype =
{
  QueryInterface: function(iid)
  {
    if (!iid.equals(nsIClassInfo) &&
        !iid.equals(nsISupports)) {
      Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
      return null;
    }
    return this;
  },

  wrappedJSObject: null,  // Initialized by constructor

  // make this an nsIClassInfo object
  flags: nsIClassInfo.DOM_OBJECT,

  // method of nsIClassInfo
  classDescription: "ContentWindowMapper",

  // method of nsIClassInfo
  getInterfaces: function(count) {
    var interfaceList = [nsIClassInfo];
    count.value = interfaceList.length;
    return interfaceList;
  },

  // method of nsIClassInfo
  getHelperForLanguage: function(count) { return null; },

  checkCache: function(topContentWindow) {
      if(typeof(topContentWindow.ghetto_guid) != "undefined"
         && typeof(this.cache[topContentWindow.ghetto_guid]) != "undefined") {
          return this.cache[topContentWindow.ghetto_guid].browser;
      }

      return null;
  },

  addCache: function(topContentWindow, browser) {
      var insertion = new Object();
      insertion.browser = browser;
      insertion.time = Date.now();
      topContentWindow.ghetto_guid = Math.random().toString()+Math.random().toString();
      this.cache[topContentWindow.ghetto_guid] = insertion; 
  },

  expireOldCache: function() {
      var now = Date.now();

      if((now - this.last_expired) < EXPIRATION_TIME) {
          this.logger.log(3, "Early mapper check.");
          return;
      }

      for(var elem in this.cache) {
          if((now - this.cache[elem].time) > EXPIRATION_TIME) {
              this.logger.log(2, "Deleting cached element: "+elem.location);
              delete this.cache[elem];
          }
      }

      this.last_expired = now;
  },

  getBrowserForContentWindow: function(topContentWindow) {
      if(topContentWindow instanceof Components.interfaces.nsIDOMChromeWindow) {
          if(topContentWindow.browserDOMWindow) {
              var browser = topContentWindow.getBrowser().selectedTab.linkedBrowser;
              this.logger.log(3, "Chrome browser at "
                      +browser.contentWindow.location+" found for: "
                      +topContentWindow.location);
              return browser;
          }
          // Allow strange chrome to go through..
          this.logger.log(3, "Odd chome window"+topContentWindow.location);
          return topContentWindow;
      }

      var cached = this.checkCache(topContentWindow);
      if(cached != null) {
          return cached;
      }

      try {
          this.logger.log(3, "Cache failed for: "+topContentWindow.location);
      } catch(e) {
          this.logger.log(3, "Cache failed for unknown location?");
      }

      var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"]
          .getService(Components.interfaces.nsIWindowMediator);
      var enumerator = wm.getEnumerator("navigator:browser");
      while(enumerator.hasMoreElements()) {
          var win = enumerator.getNext();
          var browser = win.getBrowser(); 
          for (var i = 0; i < browser.browsers.length; ++i) {
              var b = browser.browsers[i];
              if (b && b.contentWindow == topContentWindow) {
                  this.addCache(topContentWindow, b);
                  return b;
              }
          }
      }

      // SpeedDial, google notebook and other extensions can create their 
      // own "<browser>" tag elements. AFAICT, there is no way to enumerate
      // these... Just punt and return the most recently used browser
      try {
          if(topContentWindow.name != "speedDialLoaderBrowser") {
              if(topContentWindow && topContentWindow.location)
                  this.logger.log(4, "No browser found: "+topContentWindow.location);
              else
                  this.logger.log(4, "No browser found: "+topContentWindow.name);
          } else {
              this.logger.log(3, "SpeedDial browser found: "+topContentWindow.name);
          }
      } catch(e) {
          this.logger.log(4, "No browser found.");
      }

      // Punt..
      var wm = Components.classes["@mozilla.org/appshell/window-mediator;1"].
          getService(Components.interfaces.nsIWindowMediator);
      var recentWindow = wm.getMostRecentWindow("navigator:browser");
      return recentWindow ? recentWindow.getBrowser().selectedTab.linkedBrowser : null;
  }
}

/**
 * JS XPCOM component registration goop:
 *
 * Everything below is boring boilerplate and can probably be ignored.
 */

var ContentWindowMapperInstance = null;
var ContentWindowMapperFactory = new Object();

ContentWindowMapperFactory.createInstance = function (outer, iid)
{
  if (outer != null) {
    Components.returnCode = Cr.NS_ERROR_NO_AGGREGATION;
    return null;
  }
  if (!iid.equals(nsIClassInfo) &&
      !iid.equals(nsISupports)) {
    Components.returnCode = Cr.NS_ERROR_NO_INTERFACE;
    return null;
  }
  if(ContentWindowMapperInstance == null)
      ContentWindowMapperInstance = new ContentWindowMapper();

  return ContentWindowMapperInstance;
}

var ContentWindowMapperModule = new Object();

ContentWindowMapperModule.registerSelf = 
function (compMgr, fileSpec, location, type)
{
  compMgr = compMgr.QueryInterface(nsIComponentRegistrar);
  compMgr.registerFactoryLocation(kMODULE_CID,
                                  kMODULE_NAME,
                                  kMODULE_CONTRACTID,
                                  fileSpec, 
                                  location, 
                                  type);
}

ContentWindowMapperModule.getClassObject = function (compMgr, cid, iid)
{
  if (cid.equals(kMODULE_CID))
    return ContentWindowMapperFactory;


  Components.returnCode = Cr.NS_ERROR_NOT_REGISTERED;
  return null;
}

ContentWindowMapperModule.canUnload = function (compMgr)
{
  return true;
}

function NSGetModule(compMgr, fileSpec)
{
  return ContentWindowMapperModule;
}
