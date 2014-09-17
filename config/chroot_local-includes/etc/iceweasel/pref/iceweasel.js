// This is the Debian specific preferences file for Iceweasel
// You can make any change in here, it is the purpose of this file.
// You can, with this file and all files present in the
// /etc/iceweasel/pref directory, override any preference that is
// present in /usr/lib/iceweasel/defaults/preferences directory.
// While your changes will be kept on upgrade if you modify files in
// /etc/iceweasel/pref, please note that they won't be kept if you
// do make your changes in /usr/lib/iceweasel/defaults/preferences.
//
// Note that lockPref is allowed in these preferences files if you
// don't want users to be able to override some preferences.

// Use LANG environment variable to choose locale
pref("intl.locale.matchOS", true);

// Extension support
pref("xpinstall.whitelist.add.103", "");

// Unsorted prefs
pref("network.cookie.prefsMigrated", true);
pref("spellchecker.dictionary", "en_US");
