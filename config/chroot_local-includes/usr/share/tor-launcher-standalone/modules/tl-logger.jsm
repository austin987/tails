// Copyright (c) 2013, The Tor Project, Inc.
// See LICENSE for licensing information.
// TODO: Based on torbutton-logger.js (pull in copyright and license?)
//
// vim: set sw=2 sts=2 ts=8 et syntax=javascript:

/*************************************************************************
 * Tor Launcher Logger JS Module
 *
 * Allows loglevel-based logging to different logging mechanisms.
 *************************************************************************/

let EXPORTED_SYMBOLS = [ "TorLauncherLogger" ];

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cr = Components.results;
const Cu = Components.utils;

const kLogString = { 1:"VERB", 2:"DBUG", 3: "INFO", 4:"NOTE", 5:"WARN" };

Cu.import("resource://gre/modules/XPCOMUtils.jsm");
XPCOMUtils.defineLazyModuleGetter(this, "TorLauncherUtil",
                          "resource://torlauncher/modules/tl-util.jsm");


let TorLauncherLogger = // Public
{
  formatLog: function(str, level)
  {
    var d = new Date();
    var logLevelStr = kLogString[level];
    if (!logLevelStr)
      logLevelStr = "-";
    var now = TLLoggerInternal.padInt(d.getUTCMonth() + 1) + "-" +
              TLLoggerInternal.padInt(d.getUTCDate()) + " " +
              TLLoggerInternal.padInt(d.getUTCHours()) + ":" +
              TLLoggerInternal.padInt(d.getUTCMinutes()) + ":" +
              TLLoggerInternal.padInt(d.getUTCSeconds());
    return "[" + now + "] TorLauncher " + logLevelStr + ": " + str;
  },

  // error console log
  eclog: function(level, str)
  {
    switch (TLLoggerInternal.mLogMethod)
    {
      case 0: // stderr
        if (TLLoggerInternal.mLogLevel <= level)
          dump(this.formatLog(str, level) + "\n");
        break;

      default: // errorconsole
        if (TLLoggerInternal.mLogLevel <= level)
          TLLoggerInternal.mConsole.logStringMessage(this.formatLog(str,level));
        break;
    }
  },

  safelog: function(level, str, scrub)
  {
    if (TLLoggerInternal.mLogLevel < 4)
      this.eclog(level, str + scrub);
    else
      this.eclog(level, str + " [scrubbed]");
  },

  log: function(level, str)
  {
    switch (TLLoggerInternal.mLogMethod)
    {
      case 2: // debuglogger
        if (TLLoggerInternal.mDebugLog)
        {
          TLLoggerInternal.mDebugLog.log((6-level), this.formatLog(str,level));
          break;
        }
        // fallthrough

      case 0: // stderr
        if (TLLoggerInternal.mLogLevel <= level) 
          dump(this.formatLog(str,level) + "\n");
        break;

      default:
        dump("Bad log method: " + TLLoggerInternal.mLogMethod);
        // fallthrough

      case 1: // errorconsole
        if (TLLoggerInternal.mLogLevel <= level)
          TLLoggerInternal.mConsole.logStringMessage(this.formatLog(str,level));
        break;
    }
  },
};

Object.freeze(TorLauncherLogger);


let TLLoggerInternal = // Private
{
  mLogLevel : 0,
  mLogMethod : 1,
  mDebugLog : false,
  mConsole : null,

  _init: function()
  {
    // Register observer
    var prefs = Cc["@mozilla.org/preferences-service;1"]
                  .getService(Ci.nsIPrefBranchInternal)
                  .QueryInterface(Ci.nsIPrefBranchInternal);
    prefs.addObserver("extensions.torlauncher", this, false);

    this.mLogLevel = TorLauncherUtil.getIntPref(
                                     "extensions.torlauncher.loglevel", 0);
    this.mLogMethod = TorLauncherUtil.getIntPref(
                                     "extensions.torlauncher.logmethod", 1);

    // Get loggers.
    try
    {
      var logMngr = Cc["@mozmonkey.com/debuglogger/manager;1"]
                      .getService(Ci.nsIDebugLoggerManager); 
      this.mDebugLog = logMngr.registerLogger("torlauncher");
    }
    catch (e)
    {
      this.mDebugLog = false;
    }

    this.mConsole = Cc["@mozilla.org/consoleservice;1"]
                      .getService(Ci.nsIConsoleService);

    TorLauncherLogger.log(3, "debug output ready");
  },

  padInt: function(i)
  {
    return (i < 10) ? '0' + i : i;
  },

  // Pref Observer Implementation ////////////////////////////////////////////
  // topic:   what event occurred
  // subject: what nsIPrefBranch we're observing
  // data:    which pref has been changed (relative to subject)
  observe: function(subject, topic, data)
  {
    if (topic != "nsPref:changed") return;
    switch (data) {
      case "extensions.torlauncher.logmethod":
        this.mLogMethod = TorLauncherUtil.getIntPref(
                                       "extensions.torlauncher.logmethod");
        break;
      case "extensions.torlauncher.loglevel":
        this.mLogLevel = TorLauncherUtil.getIntPref(
                                       "extensions.torlauncher.loglevel");
        break;
    }
  }
};


TLLoggerInternal._init();
