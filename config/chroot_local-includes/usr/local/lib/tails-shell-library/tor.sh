#!/bin/sh

TOR_RC_DEFAULTS=/usr/share/tor/tor-service-defaults-torrc
TOR_RC=/etc/tor/torrc
TOR_LOG=/var/log/tor/log
TOR_DIR=/var/lib/tor
TOR_DESCRIPTORS=${TOR_DIR}/cached-microdescs
NEW_TOR_DESCRIPTORS=${TOR_DESCRIPTORS}.new

tor_rc_lookup() {
	grep --no-filename "^${1}\s" "${TOR_RC_DEFAULTS}" "${TOR_RC}" | \
	    sed --regexp-extended "s/^${1}\s+(.+)$/\1/" | tail -n1
}

tor_control_cookie_path() {
	local path
	path="$(tor_rc_lookup CookieAuthFile)"
	[ -e "${path}" ] && echo "${path}"
}

tor_control_send() {
	local control_port cookie_path hexcookie
	control_port="$(tor_rc_lookup ControlPort)"
	cookie_path="$(tor_control_cookie_path)"
	if [ -e "${cookie_path}" ] && [ -n "${control_port}" ]; then
		hexcookie=$(xxd -c 32 -g 0 "${cookie_path}" | cut -d' ' -f2)
		/bin/echo -ne "AUTHENTICATE ${hexcookie}\r\n${1}\r\nQUIT\r\n" | \
		    /bin/nc 127.0.0.1 "${control_port}" | tr -d "\r"
	else
		return 1
	fi
}

# Only handles GETINFO keys with single-line answers
tor_control_getinfo() {
	tor_control_send "GETINFO ${1}" | \
	    sed --regexp-extended -n "s|^250-${1}=(.*)$|\1|p"
}

tor_control_getconf() {
	tor_control_send "GETCONF ${1}" | \
            sed --regexp-extended -n "s|^250 ${1}=(.*)$|\1|p"
}

tor_control_setconf() {
	tor_control_send "SETCONF ${1}" >/dev/null
}

tor_bootstrap_progress() {
       local res
       res=$(tor_control_getinfo status/bootstrap-phase | \
                    sed --regexp-extended 's/^.* BOOTSTRAP PROGRESS=([[:digit:]]+) .*$/\1/')
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
