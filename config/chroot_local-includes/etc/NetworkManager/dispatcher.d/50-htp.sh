#!/bin/sh

# Rationale: Tor needs a somewhat accurate clock to work, and for that
# HTP is currently the only practically usable solution when one wants
# to authenticate the servers providing the time. We then need to get
# the IPs of a bunch of HTTPS servers.

# However, since all DNS lookups are normally made through the Tor
# network, which we are not connected to at this point, we use the
# local DNS servers obtained through DHCP, if possible, or the OpenDNS
# ones otherwise.

# To limit fingerprinting possibilities, we do not want to send HTTP
# requests aimed at an IP-based virtualhost such as https://IP/, but
# rather to the usual hostname (e.g. https://www.eff.org/) as any
# "normal" user would do. Once we have got the HTTPS servers IPs, we
# write these to /etc/hosts so the system resolver knows about them.
# htpdate is then run, and we eventually remove the added entries from
# /etc/hosts.

# Note that all network operations (host, htpdate) are done with the
# htp user, who has an exception in the firewall configuration
# granting it direct access to the needed network ports.

# That's why we tell the htpdate script to drops priviledges and run
# as the htp user all operations but the actual setting of time, which
# has to be done as root.


### Init variables

LOG=/var/log/htpdate.log
DONE_FILE=/var/lib/live/htp-done
SUCCESS_FILE=/var/lib/live/htp-success
VERSION_FILE=/etc/amnesia/version

HTP_POOL="
	www.torproject.org
	mail.riseup.net
	encrypted.google.com
	ssl.scroogle.org
"

BEGIN_MAGIC='### BEGIN HTP HOSTS'
END_MAGIC='### END HTP HOSTS'

if [ -n "$DHCP4_DOMAIN_NAME_SERVERS" ]; then
	NAME_SERVERS="$DHCP4_DOMAIN_NAME_SERVERS"
else
	NAME_SERVERS="208.67.222.222 208.67.220.220"
fi


### Exit conditions

# Run only when the interface is not "lo":
if [ "$1" = "lo" ]; then
	exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
	exit 0
fi

# Do not run if we already successed:
if [ -e "$SUCCESS_FILE" ]; then
	exit 0
fi


### Delete previous state file
rm -f "$DONE_FILE"


### Create log file

# The htp user needs to write to this file.
# The $LIVE_USERNAME user needs to read this file.
touch "$LOG"
chown htp:nogroup "$LOG"
chmod 644 "$LOG"


### Run tails-htp-notify-user (the sooner, the better)

# Get LIVE_USERNAME
. /etc/live/config.d/username

export DISPLAY=':0.0'
export XAUTHORITY="$(echo /var/run/gdm3/auth-for-$LIVE_USERNAME-*/database)"
exec /bin/su -c /usr/local/bin/tails-htp-notify-user "$LIVE_USERNAME" &


### Functions

log() {
	echo "$@" >> "${LOG}"
}

quit() {
	local exit_code="$1"
	shift
	local message="$@"

	echo "$exit_code" >> "$DONE_FILE"
	if [ "$exit_code" -eq 0 ]; then
		touch "$SUCCESS_FILE"
	fi
	log "$message"
	exit $exit_code
}

cleanup_etc_hosts() {
	log "Cleaning /etc/hosts"

	# remove all lines between markers
	sed -e "/$BEGIN_MAGIC/,/$END_MAGIC/d" -i /etc/hosts
}

dns_query_cmd() {
	local host="$1"
	local ns cmd

	cmd=""
	for ns in $NAME_SERVERS; do
		cmd="${cmd:+$cmd || }host '$host' '$ns'"
	done
	echo "$cmd"
}

add_nameservers_to_etc_hosts() {
	trap "cleanup_etc_hosts" EXIT

	echo "$BEGIN_MAGIC" >> /etc/hosts

	for HTP_HOST in $HTP_POOL; do
		# ensure we only get the domain if given a true url
		HTP_HOST=${HTP_HOST%%/*}
		IP=$(sudo -u htp sh -c "$(dns_query_cmd "$HTP_HOST")" |
		     awk '/ has address / { print $4 ; quit }')
		if [ -z "$IP" ]; then
			echo "$END_MAGIC" >> /etc/hosts
			quit 17 "Failed to resolve $HTP_HOST"
		fi
		echo "$IP	$HTP_HOST" >> /etc/hosts
	done

	echo "$END_MAGIC" >> /etc/hosts
}

run_htpdate() {
	/usr/local/sbin/htpdate \
		-d \
		-l "$LOG" \
		-a "$HTTP_USER_AGENT" \
		-f \
		-p \
		-u htp \
		-t 1 \
		$HTP_POOL
}

release_date() {
	# outputs something like 20111013
	sed -n -e '1s/^.* - \([0-9]\+\)$/\1/p;q' "$VERSION_FILE"
}

is_clock_way_off() {
	local release_date_secs="$(date -d "$(release_date)" '+%s')"
	local current_date_secs="$(date '+%s')"

	if [ "$current_date_secs" -lt "$release_date_secs" ]; then
		log "Clock is before the release date"
		return 0
	fi
	if [ "$(($release_date_secs + 259200))" -lt "$current_date_secs" ]; then
		log "Clock is approx. 6 months after the release date"
		return 0
	fi
	return 1
}

### Main

HTTP_USER_AGENT="$(/usr/local/bin/getTorbuttonUserAgent)"

if [ -z "$HTTP_USER_AGENT" ]; then
	quit 1 "getTorbuttonUserAgent failed."
fi

# Beware: this string is used and parsed in tails-htp-notify-user
log "HTP NetworkManager hook: here we go"
log "Will use these nameservers: $NAME_SERVERS"

add_nameservers_to_etc_hosts

run_htpdate
HTPDATE_RET=$?

# If the clock is already too badly off, htpdate might have fail because
# SSL certificates will not be verifiable. In that case let's set the clock to
# the release date and try again.
if [ "$HTPDATE_RET" -ne 0 ] && is_clock_way_off; then
	date --set="$(release_date)" > /dev/null
	run_htpdate
	HTPDATE_RET=$?
fi

quit $HTPDATE_RET "htpdate exited with return code $HTPDATE_RET"
