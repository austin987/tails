/***************************************************************************
Name: CS Lite
Description: Control cookie permissions.
Author: Ron Beckman
Homepage: http://addons.mozilla.org

Install.js script inspired by code from MonkeeSage, Pike, Henrik Gemal and Stephen Clavering

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

var XpiInstaller = {

  // --- Editable items begin ---
  extFullName    : 'CS Lite', // The name displayed to the user (don't include the version)
  extShortName   : 'cookiesafe', // The leafname of the JAR file (without the .jar part)
  extVersion     : '1.4',
  extAuthor      : 'Ron Beckman',
  extLocaleNames : ['en-US','bg-BG','de-DE','es-ES','fr-FR','hu-HU','it-IT','ja-JP','ko-KR','nl-NL','pl-PL','pt-BR','ro-RO','ru-RU','uk-UA','zh-CN'],
  extSkinNames   : ['classic'], // e.g., ['classic','modern']
  extPreferences : ['cookiesafe.js'], // e.g., ['extension.js']
  extComponents  : ['nsCSHttpObserver.js','nsCookieSafe.js','nsICookieSafe.xpt','nsCSTempExceptions.js','nsICSTempExceptions.xpt','nsCSHiddenMenuItems.js','nsICSHiddenMenuItems.xpt','nsCSLast10Hosts.js','nsICSLast10Hosts.xpt','nsCSPermManager.js','nsICSPermManager.xpt'],
  extPostInstallMessage: null, // Set to null for no post-install message
  // --- Editable items end ---

  profileInstall : true,
  silentInstall  : false,
  
  install: function() {
  
    var jarName    = this.extShortName + '.jar';
    var profileDir = Install.getFolder('Profile','chrome');
    var globalDir  = Install.getFolder('Chrome');
    
    // Parse HTTP arguments
    this.parseArguments();
    
    // Check if extension is already installed in profile
    if (File.exists(Install.getFolder(profileDir, jarName))) {
       if (!this.silentInstall) {
          Install.alert('Updating existing Profile install of ' + 
                        this.extFullName + ' to version ' + this.extVersion + '.');
       }
       this.profileInstall = true;
    }
    else if (!this.silentInstall) {
       // Ask user for install location, profile or browser dir?
       this.profileInstall = Install.confirm('Install ' + this.extFullName + ' ' + 
                             this.extVersion + ' to the Profile directory [OK] or ' +
                             'the Browser directory [Cancel]?');
    }
    
    // Init install
    var dispName = this.extFullName + ' ' + this.extVersion;
    var regName  = '/' + this.extAuthor + '/' + this.extShortName;
    Install.initInstall(dispName, regName, this.extVersion);
    
    // Find directory to install into
    var installPath;
    if (this.profileInstall) {
       installPath = profileDir;
    }
    else {
       installPath = globalDir;
    }
    
    // Add JAR file
    Install.addFile(null, 'chrome/' + jarName, installPath, null);
    
    // Register chrome
    var jarPath = Install.getFolder(installPath, jarName);
    var installType = (this.profileInstall ? Install.PROFILE_CHROME : Install.DELAYED_CHROME);
    
    // Register content
    Install.registerChrome(Install.CONTENT | installType, jarPath, 
                          'content/' + this.extShortName + '/');
    
    // Register locales
    var regPath;
    for (var i=0; i<this.extLocaleNames.length; ++i) {
       if (confirm('Do you want to install ('+this.extLocaleNames[i]+') locale as default translation?')) {
         regPath = 'locale/' + this.extLocaleNames[i] + '/' + this.extShortName + '/';
         Install.registerChrome(Install.LOCALE | installType, jarPath, regPath);
         break;
       }
    }
    if (!regPath) {
         regPath = 'locale/' + this.extLocaleNames[0] + '/' + this.extShortName + '/';
         Install.registerChrome(Install.LOCALE | installType, jarPath, regPath);
    }
    
    // Register skins
    for (var skin in this.extSkinNames) {
       var regPath = 'skin/' + this.extSkinNames[skin] + '/' + this.extShortName + '/';
       Install.registerChrome(Install.SKIN | installType, jarPath, regPath);
    }

    // Copy component files
    for (var comp in this.extComponents) {
       var compFolder = getFolder('Program','components/');
       addFile(this.extAuthor, 'components/' + 
               this.extComponents[comp], compFolder, null);
    }

    // Copy preference files
    for (var pref in this.extPreferences) {
       var prefFolder = getFolder('Program','defaults/pref/');
       addFile(this.extAuthor, 'defaults/preferences/' + 
               this.extPreferences[pref], prefFolder, null);
    }
  
    // Perform install
    var err = Install.performInstall();
    if (err == Install.SUCCESS || err == Install.REBOOT_NEEDED) {
       if (!this.silentInstall && this.extPostInstallMessage) {
          Install.alert('The ' + this.extFullName + ' ' + this.extVersion     + 
                        ' extension has been ' + 'succesfully installed.\n\n' +
                         jarPath + '\n\n' + this.extPostInstallMessage);
       }
    }
    else   {
       this.handleError(err);
       return;
    }
  },
  
  parseArguments: function()   {
    // Can't use string handling in install, so use if statement instead
    var args = Install.arguments;
    if (args == 'p=0') {
       this.profileInstall = false;
       this.silentInstall = true;
    }
    else if (args == 'p=1')   {
       this.profileInstall = true;
       this.silentInstall = true;
    }
  },
  
  handleError: function(err)   {
    if (!this.silentInstall) {
       Install.alert('Error: Could not install ' + this.extFullName + ' ' + this.extVersion +
                     ' (Error code: ' + err + ')');
    }
    Install.cancelInstall(err);
  }
};

XpiInstaller.install();
