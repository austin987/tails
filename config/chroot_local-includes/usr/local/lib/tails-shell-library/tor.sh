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
	    nc 127.0.0.1 $(get_tor_control_port) | tr -d "\r"
}

# This function may be dangerous to use. See "Potential Tor bug" below.
# Only handles GETINFO keys with single-line answers
tor_control_getinfo() {
	tor_control_send "GETINFO ${1}" | \
	    sed -n "s|^250-${1}=\(.*\)$|\1|p"
}

tor_control_getconf() {
	tor_control_send "GETCONF ${1}" | \
            sed -n "s|^250 ${1}=\(.*\)$|\1|p"
}

tor_control_setconf() {
	tor_control_send "SETCONF ${1}" >/dev/null
}

tor_bootstrap_progress() {
	RES=$(grep -o "\[notice\] Bootstrapped [[:digit:]]\+%:" ${TOR_LOG} | \
	    tail -n1 | sed "s|\[notice\] Bootstrapped \([[:digit:]]\+\)%:|\1|")
	if [ -z "$RES" ] ; then
		RES=0
	fi
	echo -n "$RES"
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
	[ -e $TOR_DESCRIPTORS ] || [ -e $NEW_TOR_DESCRIPTORS ] || return 1

	TOR_BOOTSTRAP_PROGRESS=$(tor_bootstrap_progress)
	[ -n "$TOR_BOOTSTRAP_PROGRESS" ] && [ "$TOR_BOOTSTRAP_PROGRESS" -eq 100 ]
}

tor_append_to_torrc () {
	echo "${@}" >> "${TOR_RC}"
}

# Set a (possibly existing) option $1 to $2 in torrc. Shouldn't be
# used for options that can be set multiple times (e.g. the listener
# options). Does not support configuration entries split into multiple
# lines (with the backslash character).
tor_set_in_torrc () {
	sed -i "/^${1}\s/d" "${TOR_RC}"
	tor_append_to_torrc "${1} ${2}"
}
