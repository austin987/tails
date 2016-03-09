user_pref("extensions.enigmail.configuredVersion", "1.8.2");

// TorBirdy tries to set values on the first run which forces us to
// set the following unless we want our settings of it to be
// overwritten...
user_pref("extensions.torbirdy.first_run", false);a
// ... and for the same reason we cannot store the following value in
// the global "seed" preferences, /etc/icedove/pref/icedove.js.
user_pref("extensions.torbirdy.emailwizard", true);
