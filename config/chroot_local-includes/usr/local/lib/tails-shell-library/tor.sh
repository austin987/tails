#!/bin/sh

TOR_RC=/etc/tor/torrc
TOR_LOG=/var/log/tor/log
TOR_DIR=/var/lib/tor
TOR_DESCRIPTORS=${TOR_DIR}/cached-microdescs
NEW_TOR_DESCRIPTORS=${TOR_DESCRIPTORS}.new

get_tor_control_port() {
	sed -n 's/^ControlPort[[:space:]]\+\([[:digit:]]\+\)/\1/p' "${TOR_RC}"
}

get_tor_control_socket_path() {
	local res
	res=$(sed -n 's/^ControlSocket[[:space:]]\+\(.\+\)$/\1/p' "${TOR_RC}")
	if [ "${res}" -eq 0 ]; then
		echo ""
	elif [ -z "${res}" ] && [ -S /var/run/tor/control ]; then
		echo /var/run/tor/control
	else
		echo "${res}"
	fi
}

tor_control_send() {
	COOKIE=/var/run/tor/control.authcookie
	HEXCOOKIE=$(xxd -c 32 -g 0 $COOKIE | cut -d' ' -f2)
	/bin/echo -ne "AUTHENTICATE ${HEXCOOKIE}\r\n${1}\r\nQUIT\r\n" | \
	    socat - UNIX-CONNECT:$(get_tor_control_socket_path) | tr -d "\r"
}

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
       local res
       res=$(tor_control_getinfo status/bootstrap-phase | \
                    sed 's/^.* BOOTSTRAP PROGRESS=\([[:digit:]]\+\) .*$/\1/')
       echo ${res:-0}
}

tor_is_working() {
	[ "$(tor_bootstrap_progress)" -eq 100 ]
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
