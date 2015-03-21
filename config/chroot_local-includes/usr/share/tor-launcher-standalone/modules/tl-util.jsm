// Copyright (c) 2014, The Tor Project, Inc.
// See LICENSE for licensing information.
//
// vim: set sw=2 sts=2 ts=8 et syntax=javascript:

/*************************************************************************
 * Tor Launcher Util JS Module
 *************************************************************************/

let EXPORTED_SYMBOLS = [ "TorLauncherUtil" ];

const Cc = Components.classes;
const Ci = Components.interfaces;
const kPropBundleURI = "chrome://torlauncher/locale/torlauncher.properties";
const kPropNamePrefix = "torlauncher.";

let TorLauncherUtil =  // Public
{
  get isMac()
  {
    return ("Darwin" == TLUtilInternal._OS);
  },

  get isWindows()
  {
    return ("WINNT" == TLUtilInternal._OS);
  },

  isAppVersionAtLeast: function(aVersion)
  {
    var appInfo = Cc["@mozilla.org/xre/app-info;1"]
                    .getService(Ci.nsIXULAppInfo);
    var vc = Cc["@mozilla.org/xpcom/version-comparator;1"]
               .getService(Ci.nsIVersionComparator);
    return (vc.compare(appInfo.version, aVersion) >= 0);
  },

  // Error Reporting / Prompting
  showAlert: function(aParentWindow, aMsg)
  {
    // TODO: alert() does not always resize correctly to fit the message.
    try
    {
      if (!aParentWindow)
      {
        var wm = Cc["@mozilla.org/appshell/window-mediator;1"]
                   .getService(Ci.nsIWindowMediator);
        aParentWindow = wm.getMostRecentWindow("TorLauncher:NetworkSettings");
        if (!aParentWindow)
          aParentWindow = wm.getMostRecentWindow("navigator:browser");
      }

      var ps = Cc["@mozilla.org/embedcomp/prompt-service;1"]
                 .getService(Ci.nsIPromptService);
      var title = this.getLocalizedString("error_title");
      ps.alert(aParentWindow, title, aMsg);
    }
    catch (e)
    {
      alert(aMsg);
    }
  },

  // Returns true if user confirms; false if not.
  // Note that no prompt is shown (and false is returned) if the Network Settings
  // window is open.
  showConfirm: function(aParentWindow, aMsg, aDefaultButtonLabel,
                        aCancelButtonLabel)
  {
    try
    {
      if (!aParentWindow)
      {
        var wm = Cc["@mozilla.org/appshell/window-mediator;1"]
                   .getService(Ci.nsIWindowMediator);
        aParentWindow = wm.getMostRecentWindow("TorLauncher:NetworkSettings");
        if (aParentWindow)
          return false; // Don't show prompt if Network Settings window is open.

        aParentWindow = wm.getMostRecentWindow("navigator:browser");
      }

      var ps = Cc["@mozilla.org/embedcomp/prompt-service;1"]
                 .getService(Ci.nsIPromptService);
      var title = this.getLocalizedString("error_title");
      var btnFlags = (ps.BUTTON_POS_0 * ps.BUTTON_TITLE_IS_STRING)
                     + ps.BUTTON_POS_0_DEFAULT
                     + (ps.BUTTON_POS_1 * ps.BUTTON_TITLE_IS_STRING);

      var notUsed = { value: false };
      var btnIndex =  ps.confirmEx(aParentWindow, title, aMsg, btnFlags,
                                   aDefaultButtonLabel, aCancelButtonLabel,
                                   null, null, notUsed);
      return (0 == btnIndex);
    }
    catch (e)
    {
      return confirm(aMsg);
    }

    return false;
  },

  showSaveSettingsAlert: function(aParentWindow, aDetails)
  {
    if (!aDetails)
      aDetails = TorLauncherUtil.getLocalizedString("ensure_tor_is_running");

    var s = TorLauncherUtil.getFormattedLocalizedString(
                                  "failed_to_save_settings", [aDetails], 1);
    this.showAlert(aParentWindow, s);
  },

  // Localized Strings

  // "torlauncher." is prepended to aStringName.
  getLocalizedString: function(aStringName)
  {
    if (!aStringName)
      return aStringName;

    try
    {
      var key = kPropNamePrefix + aStringName;
      return TLUtilInternal._stringBundle.GetStringFromName(key);
    } catch(e) {}

    return aStringName;
  },

  // "torlauncher." is prepended to aStringName.
  getFormattedLocalizedString: function(aStringName, aArray, aLen)
  {
    if (!aStringName || !aArray)
      return aStringName;

    try
    {
      var key = kPropNamePrefix + aStringName;
      return TLUtilInternal._stringBundle.formatStringFromName(key,
                                                               aArray, aLen);
    } catch(e) {}

    return aStringName;
  },

  getLocalizedBootstrapStatus: function(aStatusObj, aKeyword)
  {
    if (!aStatusObj || !aKeyword)
      return "";

    var result;
    var fallbackStr;
    if (aStatusObj[aKeyword])
    {
      var val = aStatusObj[aKeyword].toLowerCase();
      var key;
      if (aKeyword == "TAG")
      {
        if ("onehop_create" == val)
          val = "handshake_dir";
        else if ("circuit_create" == val)
          val = "handshake_or";

        key = "bootstrapStatus." + val;
        fallbackStr = aStatusObj.SUMMARY;
      }
      else if (aKeyword == "REASON")
      {
        if ("connectreset" == val)
          val = "connectrefused";

        key = "bootstrapWarning." + val;
        fallbackStr = aStatusObj.WARNING;
      }

      result = TorLauncherUtil.getLocalizedString(key);
      if (result == key)
        result = undefined;
    }

    if (!result)
      result = fallbackStr;

    return (result) ? result : "";
  },

  // Preferences
  getBoolPref: function(aPrefName, aDefaultVal)
  {
    var rv = (undefined != aDefaultVal) ? aDefaultVal : false;

    try
    {
      rv = TLUtilInternal.mPrefsSvc.getBoolPref(aPrefName);
    } catch (e) {}

    return rv;
  },

  setBoolPref: function(aPrefName, aVal)
  {
    var val = (undefined != aVal) ? aVal : false;
    try
    {
      TLUtilInternal.mPrefsSvc.setBoolPref(aPrefName, val);
    } catch (e) {}
  },

  getIntPref: function(aPrefName, aDefaultVal)
  {
    var rv = aDefaultVal ? aDefaultVal : 0;

    try
    {
      rv = TLUtilInternal.mPrefsSvc.getIntPref(aPrefName);
    } catch (e) {}

    return rv;
  },

  getCharPref: function(aPrefName, aDefaultVal)
  {
    var rv = aDefaultVal ? aDefaultVal : "";

    try
    {
      rv = TLUtilInternal.mPrefsSvc.getCharPref(aPrefName);
    } catch (e) {}

    return rv;
  },

  setCharPref: function(aPrefName, aVal)
  {
    try
    {
      TLUtilInternal.mPrefsSvc.setCharPref(aPrefName, aVal ? aVal : "");
    } catch (e) {}
  },

  get shouldStartAndOwnTor()
  {
    const kPrefStartTor = "extensions.torlauncher.start_tor";
    try
    {
      const kEnvSkipLaunch = "TOR_SKIP_LAUNCH";

      var env = Cc["@mozilla.org/process/environment;1"]
                  .getService(Ci.nsIEnvironment);
      if (env.exists(kEnvSkipLaunch))
        return ("1" != env.get(kEnvSkipLaunch));
    } catch(e) {}

    return this.getBoolPref(kPrefStartTor, true);
  },

  get shouldShowNetworkSettings()
  {
    const kPrefPromptAtStartup = "extensions.torlauncher.prompt_at_startup";
    try
    {
      const kEnvForceShowNetConfig = "TOR_FORCE_NET_CONFIG";

      var env = Cc["@mozilla.org/process/environment;1"]
                  .getService(Ci.nsIEnvironment);
      if (env.exists(kEnvForceShowNetConfig))
        return ("1" == env.get(kEnvForceShowNetConfig));
    } catch(e) {}

    return this.getBoolPref(kPrefPromptAtStartup, true);
  },

  get shouldOnlyConfigureTor()
  {
    const kPrefOnlyConfigureTor = "extensions.torlauncher.only_configure_tor";
    try
    {
      const kEnvOnlyConfigureTor = "TOR_CONFIGURE_ONLY";

      var env = Cc["@mozilla.org/process/environment;1"]
                  .getService(Ci.nsIEnvironment);
      if (env.exists(kEnvOnlyConfigureTor))
        return ("1" == env.get(kEnvOnlyConfigureTor));
    } catch(e) {}

    return this.getBoolPref(kPrefOnlyConfigureTor, false);
  },

  // Returns an array of strings or undefined if none are available.
  get defaultBridgeTypes()
  {
    try
    {
      var prefBranch = Cc["@mozilla.org/preferences-service;1"]
                           .getService(Ci.nsIPrefService)
                           .getBranch("extensions.torlauncher.default_bridge.");
      var childPrefs = prefBranch.getChildList("", []);
      var typeArray = [];
      for (var i = 0; i < childPrefs.length; ++i)
      {
        var s = childPrefs[i].replace(/\..*$/, "");
        if (-1 == typeArray.lastIndexOf(s))
          typeArray.push(s);
      }

      return typeArray.sort();
    } catch(e) {};

    return undefined;
  },

  // Returns an array of strings or undefined if none are available.
  // The list is filtered by the default_bridge_type pref value.
  get defaultBridges()
  {
    const kPrefName = "extensions.torlauncher.default_bridge_type";
    var filterType = this.getCharPref(kPrefName);
    if (!filterType)
      return undefined;

    try
    {
      var prefBranch = Cc["@mozilla.org/preferences-service;1"]
                           .getService(Ci.nsIPrefService)
                           .getBranch("extensions.torlauncher.default_bridge.");
      var childPrefs = prefBranch.getChildList("", []);
      var bridgeArray = [];
      // The pref service seems to return the values in reverse order, so
      // we compensate by traversing in reverse order.
      for (var i = childPrefs.length - 1; i >= 0; --i)
      {
        var bridgeType = childPrefs[i].replace(/\..*$/, "");
        if (bridgeType == filterType)
        {
          var s = prefBranch.getCharPref(childPrefs[i]);
          if (s)
            bridgeArray.push(s);
        }
      }

      return bridgeArray;
    } catch(e) {};

    return undefined;
  },
};


Object.freeze(TorLauncherUtil);


let TLUtilInternal =  // Private
{
  mPrefsSvc : null,
  mStringBundle : null,
  mOS : "",

  _init: function()
  {
    this.mPrefsSvc = Cc["@mozilla.org/preferences-service;1"]
                       .getService(Ci.nsIPrefBranch);
  },

  get _stringBundle()
  {
    if (!this.mStringBundle)
    {
      this.mStringBundle = Cc["@mozilla.org/intl/stringbundle;1"]
                             .getService(Ci.nsIStringBundleService)
                             .createBundle(kPropBundleURI);
    }

    return this.mStringBundle;
  },

  get _OS()
  {
    if (!this.mOS) try
    {
      var xr = Cc["@mozilla.org/xre/app-info;1"].getService(Ci.nsIXULRuntime);
      this.mOS = xr.OS;
    } catch (e) {}

    return this.mOS;
  },
};


TLUtilInternal._init();
