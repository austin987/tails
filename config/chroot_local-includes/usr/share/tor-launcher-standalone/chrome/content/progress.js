// Copyright (c) 2014, The Tor Project, Inc.
// See LICENSE for licensing information.
//
// vim: set sw=2 sts=2 ts=8 et syntax=javascript:

const Cc = Components.classes;
const Ci = Components.interfaces;
const Cu = Components.utils;

const kTorProcessExitedTopic = "TorProcessExited";
const kBootstrapStatusTopic = "TorBootstrapStatus";
const kTorLogHasWarnOrErrTopic = "TorLogHasWarnOrErr";

Cu.import("resource://gre/modules/XPCOMUtils.jsm");
XPCOMUtils.defineLazyModuleGetter(this, "TorLauncherUtil",
                          "resource://torlauncher/modules/tl-util.jsm");

var gObsSvc;
var gOpenerCallbackFunc; // Set when opened from network settings.


function initDialog()
{
  // If tor bootstrap has already finished, just close the progress dialog.
  // This situation can occur if bootstrapping is very fast and/or if this
  // window opens slowly (observed with Adblock Plus installed).
  try
  {
    var processSvc = Cc["@torproject.org/torlauncher-process-service;1"]
                .getService(Ci.nsISupports).wrappedJSObject;
    if (processSvc.TorIsBootstrapDone || processSvc.TorBootstrapErrorOccurred)
    {
      closeThisWindow(processSvc.TorIsBootstrapDone);
      return;
    }
  }
  catch (e) { dump(e + "\n"); }

  try
  {
    gObsSvc = Cc["@mozilla.org/observer-service;1"]
                  .getService(Ci.nsIObserverService);
    gObsSvc.addObserver(gObserver, kTorProcessExitedTopic, false);
    gObsSvc.addObserver(gObserver, kBootstrapStatusTopic, false);
    gObsSvc.addObserver(gObserver, kTorLogHasWarnOrErrTopic, false);
  }
  catch (e) {}

  var isBrowserStartup = false;
  if (window.arguments)
  {
    isBrowserStartup = window.arguments[0];

    if (window.arguments.length > 1)
      gOpenerCallbackFunc = window.arguments[1];
  }

  if (gOpenerCallbackFunc)
  {
    // Dialog was opened from network settings: hide Open Settings button.
    var extraBtn = document.documentElement.getButton("extra2");
    extraBtn.setAttribute("hidden", true);
  }
  else
  {
    // Dialog was not opened from network settings: change Cancel to Quit.
    var cancelBtn = document.documentElement.getButton("cancel");
    var quitKey = (TorLauncherUtil.isWindows) ? "quit_win" : "quit";
    cancelBtn.label = TorLauncherUtil.getLocalizedString(quitKey);
  }

  // If opened during browser startup, display the "please wait" message.
  if (isBrowserStartup)
  {
    var pleaseWait = document.getElementById("progressPleaseWait");
    if (pleaseWait)
      pleaseWait.removeAttribute("hidden");
  }
}


function cleanup()
{
  if (gObsSvc)
  {
    gObsSvc.removeObserver(gObserver, kTorProcessExitedTopic);
    gObsSvc.removeObserver(gObserver, kBootstrapStatusTopic);
    gObsSvc.removeObserver(gObserver, kTorLogHasWarnOrErrTopic);
  }
}


function closeThisWindow(aBootstrapDidComplete)
{
  cleanup();

  if (gOpenerCallbackFunc)
    gOpenerCallbackFunc(aBootstrapDidComplete);

  window.close();
}


function onCancel()
{
  cleanup();

  if (gOpenerCallbackFunc)
  {
    // TODO: stop the bootstrapping process?
    gOpenerCallbackFunc(false);
  }
  else try
  {
    var obsSvc = Cc["@mozilla.org/observer-service;1"]
                   .getService(Ci.nsIObserverService);
    obsSvc.notifyObservers(null, "TorUserRequestedQuit", null);
  } catch (e) {}

  return true;
}


function onOpenSettings()
{
  cleanup();
  window.close();
}


var gObserver = {
  // nsIObserver implementation.
  observe: function(aSubject, aTopic, aParam)
  {
    if (kTorProcessExitedTopic == aTopic)
    {
      // TODO: provide a way to access tor log e.g., leave this dialog open
      //       and display the open settings button.
      cleanup();
      window.close();
    }
    else if (kBootstrapStatusTopic == aTopic)
    {
      var statusObj = aSubject.wrappedJSObject;
      var labelText =
                TorLauncherUtil.getLocalizedBootstrapStatus(statusObj, "TAG");
      var percentComplete = (statusObj.PROGRESS) ? statusObj.PROGRESS : 0;

      var meter = document.getElementById("progressMeter");
      if (meter)
        meter.value = percentComplete;

      var bootstrapDidComplete = (percentComplete >= 100);
      if (percentComplete >= 100)
      {
        // To ensure that 100% progress is displayed, wait a short while
        // before closing this window.
        window.setTimeout(function() { closeThisWindow(true); }, 250);
      }
      else if (statusObj._errorOccurred)
      {
        var s = TorLauncherUtil.getLocalizedBootstrapStatus(statusObj, "REASON");
        if (s)
          labelText = s;

        if (meter)
          meter.setAttribute("hidden", true);

        var pleaseWait = document.getElementById("progressPleaseWait");
        if (pleaseWait)
          pleaseWait.setAttribute("hidden", true);
      }

      var desc = document.getElementById("progressDesc");
      if (labelText && desc)
        desc.textContent = labelText;
    }
    else if (kTorLogHasWarnOrErrTopic == aTopic)
    {
      var extra2Btn = document.documentElement.getButton("extra2");
      var clz = extra2Btn.getAttribute("class");
      extra2Btn.setAttribute("class", clz ? clz + " torWarning" : "torWarning");

      // TODO: show error / warning message in this dialog?
    }
  },
};
