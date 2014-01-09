#!/bin/sh

TOR_RC=/etc/tor/torrc
TOR_LOG=/var/log/tor/log
TOR_DIR=/var/lib/tor
TOR_DESCRIPTORS=${TOR_DIR}/cached-microdescs
NEW_TOR_DESCRIPTORS=${TOR_DESCRIPTORS}.new

get_tor_control_port() {
	sed -n 's/^ControlPort[[:space:]]\+\([[:digit:]]\+\)/\1/p' "${TOR_RC}"
}

tor_control_send() {
	COOKIE=/var/run/tor/control.authcookie
	HEXCOOKIE=$(xxd -c 32 -g 0 $COOKIE | cut -d' ' -f2)
	/bin/echo -ne "AUTHENTICATE ${HEXCOOKIE}\r\n${1}\r\nQUIT\r\n" | \
	    nc 127.0.0.1 $(get_tor_control_port)
}

# This function may be dangerous to use. See "Potential Tor bug" below.
# Only handles GETINFO keys with single-line answers
tor_control_getinfo() {
	tor_control_send "GETINFO ${1}" | grep -m 1 "^250-${1}=" | \
	    # Note: we have to remove trailing CL+RF to not confuse the shell
	    sed "s|^250-${1}=\(.*\)[[:space:]]\+$|\1|"
}

tor_control_setconf() {
	tor_control_send "SETCONF ${1}" >/dev/null
}

tor_bootstrap_progress() {
	grep -o "\[notice\] Bootstrapped [[:digit:]]\+%:" ${TOR_LOG} | \
	    tail -n1 | sed "s|\[notice\] Bootstrapped \([[:digit:]]\+\)%:|\1|"
}

# Potential Tor bug: it seems like using this version makes Tor get
# stuck at "Bootstrapped 5%" quite often. Is Tor sensitive to opening
# control ports and/or issuing "getinfo status/bootstrap-phase" during
# early bootstrap? Because of this we fallback to greping the log.
#tor_bootstrap_progress() {
#	tor_control_getinfo status/bootstrap-phase | \
#	    sed 's/^.* BOOTSTRAP PROGRESS=\([[:digit:]]\+\) .*$/\1/'
#}

tor_is_working() {
	[ -e $TOR_DESCRIPTORS ] || [ -e $NEW_TOR_DESCRIPTORS ]
}
