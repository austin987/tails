#! /bin/sh

# Run only when the interface is not "lo":
if [ -z "$1" ] || [ "$1" = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

# Get LANG
. /etc/default/locale
export LANG

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

while ! /usr/local/sbin/tor-has-bootstrapped; do
   sleep 1
done

# We now know that whatever Tor settings we are using works, so if Tor
# Launcher is still running, we can just kill it and make sure it
# won't start next network reconnect. A reason for this happening is
# if Tor was restarted by tordate, e.g. if the clock was to incorrect.
TOR_LAUNCHER_PROCESS_REGEX="firefox-unconfined -?-app.*tor-launcher-standalone"
if pgrep -f "${TOR_LAUNCHER_PROCESS_REGEX}"; then
   pkill -f "${TOR_LAUNCHER_PROCESS_REGEX}"
   pref=/home/tor-launcher/.tor-launcher/profile.default/prefs.js
   sed -i '/^user_pref("extensions\.torlauncher\.prompt_at_startup"/d' "${pref}"
   echo 'user_pref("extensions.torlauncher.prompt_at_startup", false);' >> "${pref}"
fi

/usr/local/sbin/tails-notify-user \
   "`gettext \"Tor is ready\"`" \
   "`gettext \"You can now access the Internet.\"`"
