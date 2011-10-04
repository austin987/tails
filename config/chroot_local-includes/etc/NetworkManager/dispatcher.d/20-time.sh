#!/bin/sh

# Rationale: Tor needs a somewhat accurate clock to work.
# If the clock is wrong enough to prevent it from opening circuits,
# we set the time to the middle of the valid time interval found
# in the Tor consensus, and we restart it.
# In any case, we use HTP to ask more accurate time information to
# a few authenticated HTTPS servers.


### Init variables

TORDATE_DIR=/var/run/tordate
TORDATE_DONE_FILE=${TORDATE_DIR}/done
TOR_DIR=/var/lib/tor
TOR_CONSENSUS=${TOR_DIR}/cached-consensus
TOR_DESCRIPTORS=${TOR_DIR}/cached-descriptors
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

tor_is_working() {
	[ -e $TOR_DESCRIPTORS ]
}

wait_for_tor_consensus() {
	log "Waiting for the Tor consensus file to contain a valid time interval"
	while :; do
		if grep -qs "^valid-until ${DATE_RE}"'$' ${TOR_CONSENSUS}; then
			break;
		fi

		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to --format %w%f ${TOR_DIR} || :
	done
}

wait_for_working_tor() {
	log "Waiting for Tor to be working (i.e. cached descriptors exist)"
	while :; do
		if tor_is_working; then
			break;
		fi

		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to --format %w%f ${TOR_DIR} || :
	done
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
	# Get various date points in Tor's format, and do some sanity checks
	vstart=$(sed -n "/^valid-after \(${DATE_RE}\)"'$/s//\1/p; t q; b n; :q q; :n' ${TOR_CONSENSUS})
	vend=$(sed -n "/^valid-until \(${DATE_RE}\)"'$/s//\1/p; t q; b n; :q q; :n' ${TOR_CONSENSUS})
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
	if service tor status >/dev/null; then
		log "Restarting Tor service"
		service tor restart
	fi
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
	        log "Clock is more than 6 months after the release date"
	        return 0
	fi
	return 1
}


### Main

# Delegate time setting to other daemons if Tor connections work
if tor_is_working; then
	log "Tor has already opened a circuit"
else
	wait_for_tor_consensus
	maybe_set_time_from_tor_consensus
fi

wait_for_working_tor

# If Tor is not working and the clock is badly off,
# this is probably because all authority certificates are seen as invalid,
# so there's no valid consensus.
# In that case let's set the clock to the release date.
if ! tor_is_working && is_clock_way_off; then
	log "Clock is badly off. Setting it to the release date, and retrying."
	date --set="$(release_date)" > /dev/null
	if service tor status >/dev/null; then
		log "Restarting Tor service"
		service tor restart
	fi
	wait_for_tor_consensus
	maybe_set_time_from_tor_consensus
fi

touch $TORDATE_DONE_FILE

log "Restarting htpdate"
service htpdate restart
log "htpdate service restarted with return code $?"
