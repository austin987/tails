#!/bin/sh

# Rationale: Tor needs a somewhat accurate clock to work.
# If the clock is wrong enough to prevent it from opening circuits,
# we set the time to the middle of the valid time interval found
# in the Tor consensus, and we restart it.
# In any case, we use HTP to ask more accurate time information to
# a few authenticated HTTPS servers.

# Get LIVE_USERNAME
. /etc/live/config.d/username.conf

# Import tor_control_*(), tor_is_working(), TOR_LOG, TOR_DIR
. /usr/local/lib/tails-shell-library/tor.sh

# Import tails_netconf()
. /usr/local/lib/tails-shell-library/tails-greeter.sh

### Init variables

TORDATE_DIR=/var/run/tordate
TORDATE_DONE_FILE=${TORDATE_DIR}/done
TOR_CONSENSUS=${TOR_DIR}/cached-microdesc-consensus
TOR_UNVERIFIED_CONSENSUS=${TOR_DIR}/unverified-microdesc-consensus
TOR_UNVERIFIED_CONSENSUS_HARDLINK=${TOR_UNVERIFIED_CONSENSUS}.bak
INOTIFY_TIMEOUT=60
DATE_RE='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
VERSION_FILE=/etc/amnesia/version

### Exit conditions

# Run only when the interface is not "lo":
if [ "$1" = "lo" ]; then
	exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
	exit 0
fi

# Do not run twice
if [ -e "$TORDATE_DONE_FILE" ]; then
	exit 0
fi


### Create status directory
install -o root -g root -m 0755 -d ${TORDATE_DIR}


### Functions

log() {
	logger -t time "$@"
}

has_consensus() {
	local files="${TOR_CONSENSUS} ${TOR_UNVERIFIED_CONSENSUS}"

	if [ $# -ge 1 ]; then
		files="$@"
	fi
	grep -qs "^valid-until ${DATE_RE}"'$' ${files}
}

has_only_unverified_consensus() {
	[ ! -e ${TOR_CONSENSUS} ] && has_consensus ${TOR_UNVERIFIED_CONSENSUS}
}

wait_for_tor_consensus_helper() {
	tries=0
	while ! has_consensus && [ $tries -lt 5 ]; do
		inotifywait -q -t 30 -e close_write -e moved_to ${TOR_DIR} || log "timeout"
		tries=$(expr $tries + 1)
	done

	# return some kind of success measurement
	has_consensus
}

wait_for_tor_consensus() {
	log "Waiting for a Tor consensus file to contain a valid time interval"
	if ! has_consensus && ! wait_for_tor_consensus_helper; then
		log "Unsuccessfully waited for Tor consensus, restarting Tor and retrying."
		restart-tor
	fi
	if ! has_consensus && ! wait_for_tor_consensus_helper; then
		log "Unsuccessfully retried waiting for Tor consensus, aborting."
	fi
	if has_consensus; then
		log "A Tor consensus file now contains a valid time interval."
	else
		log "Waited for too long, let's stop waiting for Tor consensus."
		# FIXME: gettext-ize
		/usr/local/sbin/tails-notify-user "Synchronizing the system's clock" \
			"Could not fetch Tor consensus."
		exit 2
	fi
}

wait_for_working_tor() {
	local waited=0

	log "Waiting for Tor to be working..."
	while ! tor_is_working; do
		if [ "$waited" -lt ${INOTIFY_TIMEOUT} ]; then
			sleep 2
			waited=$(($waited + 2))
		else
			log "Timed out waiting for Tor to be working"
			return 1
		fi
	done
	log "Tor is now working."
}

date_points_are_sane() {
	local vstart="$1"
	local vend="$2"

	vendchk=$(date -ud "${vstart} -0300" +'%F %T')
	[ "${vend}" = "${vendchk}" ]
}

time_is_in_valid_tor_range() {
	local curdate="$1"
	local vstart="$2"

	vendcons=$(date -ud "${vstart} -0230" +'%F %T')
	order="${vstart}
${curdate}
${vendcons}"
	ordersrt=$(echo "${order}" | sort)

	[ "${order}" = "${ordersrt}" ]
}

maybe_set_time_from_tor_consensus() {
	local consensus=${TOR_CONSENSUS}

	if has_only_unverified_consensus \
	   && ln -f ${TOR_UNVERIFIED_CONSENSUS} ${TOR_UNVERIFIED_CONSENSUS_HARDLINK}; then
		consensus=${TOR_UNVERIFIED_CONSENSUS_HARDLINK}
		log "We do not have a Tor verified consensus, let's use the unverified one."
	fi

	log "Waiting for the chosen Tor consensus file to contain a valid time interval..."
	while ! has_consensus ${consensus}; do
		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to ${TOR_DIR} || log "timeout"
	done
	log "The chosen Tor consensus now contains a valid time interval, let's use it."


	# Get various date points in Tor's format, and do some sanity checks
	vstart=$(sed -n "/^valid-after \(${DATE_RE}\)"'$/s//\1/p; t q; b; :q q' ${consensus})
	vend=$(sed -n "/^valid-until \(${DATE_RE}\)"'$/s//\1/p; t q; b; :q q' ${consensus})
	vmid=$(date -ud "${vstart} -0130" +'%F %T')
	log "Tor: valid-after=${vstart} | valid-until=${vend}"

	if ! date_points_are_sane "${vstart}" "${vend}"; then
		log "Unexpected valid-until: [${vend}] is not [${vstart} + 3h]"
		return
	fi

	curdate=$(date -u +'%F %T')
	log "Current time is ${curdate}"

	if time_is_in_valid_tor_range "${curdate}" "${vstart}"; then
		log "Current time is in valid Tor range"
		return
	fi

	log "Current time is not in valid Tor range, setting to middle of this range: [${vmid}]"
	date -us "${vmid}" 1>/dev/null

	# Tor is unreliable with picking a circuit after time change
	restart-tor
}

tor_cert_valid_after() {
	# Only print the last = freshest match
	sed -n 's/^.*certificate lifetime runs from \(.*\) through.*$/\1/p' \
	    ${TOR_LOG} | tail -n 1
}

tor_cert_lifetime_invalid() {
	# To be sure that we only grep relevant information, we
	# should delete the log when Tor is started, which we do
	# in 10-tor.sh.
	# The log severity will be "warn" if bootstrapping with
	# authorities and "info" with bridges.
	grep -q "\[\(warn\|info\)\] Certificate \(not yet valid\|already expired\)\." \
	    ${TOR_LOG}
}

# This check is blocking until Tor reaches either of two states:
# 1. Tor completes a handshake with an authority (or bridge).
# 2. Tor fails the handshake with all authorities (or bridges).
# Since 2 essentially is the negation of 1, one of them will happen,
# so it won't block forever. Hence we shouldn't need a timeout.
is_clock_way_off() {
	log "Checking if system clock is way off"
	until [ "$(tor_bootstrap_progress)" -gt 10 ]; do
		if tor_cert_lifetime_invalid; then
			return 0
		fi
		sleep 1
	done
	return 1
}

start_notification_helper() {
	export DISPLAY=':0.0'
	export XAUTHORITY="$(echo /var/run/gdm3/auth-for-$LIVE_USERNAME-*/database)"
	exec /bin/su -c /usr/local/bin/tails-htp-notify-user "$LIVE_USERNAME" &
}


### Main

# When the network is obstacled (e.g. we need a bridge) we wait until
# Tor Launcher has unset DisableNetwork, since Tor's bootstrapping
# won't start until then.
if [ "$(tails_netconf)" = "obstacle" ]; then
	until [ "$(tor_control_getconf DisableNetwork)" = 0 ]; do
		sleep 1
	done
fi

start_notification_helper

# Delegate time setting to other daemons if Tor connections work
if tor_is_working; then
	log "Tor has already opened a circuit"
else
	# Since Tor 0.2.3.x Tor doesn't download a consensus for
	# clocks that are more than 30 days in the past or 2 days in
	# the future.  For such clock skews we set the time to the
	# authority's cert's valid-after date.
	if is_clock_way_off; then
		log "The clock is so badly off that Tor cannot download a consensus. Setting system time to the authority's cert's valid-after date and trying to fetch a consensus again..."
		date --set="$(tor_cert_valid_after)" > /dev/null
		service tor reload
	fi
	wait_for_tor_consensus
	maybe_set_time_from_tor_consensus
fi

wait_for_working_tor

# Disable "info" logging workaround from 10-tor.sh
if [ "$(tails_netconf)" = "obstacle" ]; then
	tor_control_setconf "Log=\"notice file ${TOR_LOG}\""
fi

touch $TORDATE_DONE_FILE

log "Restarting htpdate"
service htpdate restart
log "htpdate service restarted with return code $?"
