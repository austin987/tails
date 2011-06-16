// This is the Debian specific preferences file for Mozilla Firefox
// You can make any change in here, it is the purpose of this file.
// You can, with this file and all files present in the
// /etc/thunderbird/pref directory, override any preference that is
// present in /usr/lib/thunderbird/defaults/pref directory.
// While your changes will be kept on upgrade if you modify files in
// /etc/thunderbird/pref, please note that they won't be kept if you
// do them in /usr/lib/thunderbird/defaults/pref.

pref("extensions.update.enabled", true);

// Use LANG environment variable to choose locale
pref("intl.locale.matchOS", true);

// Disable default mail checking (gnome).
pref("mail.shell.checkDefaultMail", false);

// if you are not using gnome
pref("network.protocol-handler.app.http", "x-www-browser");
pref("network.protocol-handler.app.https", "x-www-browser");

// Stop leaks in the HELO/EHLO headers
pref("mail.smtpserver.default.hello_argument", "localhost");

// Stop DNS leaks
pref("network.proxy.socks_remote_dns", True);

// Disable HTML when showing message bodies
pref("mailnews.display.disallow_mime_handlers", 1);
pref("mailnews.display.html_as", 1);
pref("mailnews.display.prefer_plaintext", True);

// Disable HTML email composing
pref("mail.html_compose", False);
pref("mail.identity.default.compose_html", False);
pref("mail.default_html_action", 1);

// FIXME: Set general.useragent.override equal to that of the most recent Thunderbird from the time of the firefox version specified in current Torbutton. We probably want to script this...