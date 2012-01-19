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
TOR_UNVERIFIED_CONSENSUS=${TOR_DIR}/unverified-consensus
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

has_consensus() {
	grep -qs "^valid-until ${DATE_RE}"'$' ${TOR_CONSENSUS} \
					      ${TOR_UNVERIFIED_CONSENSUS}
}

has_verified_consensus() {
	grep -qs "^valid-until ${DATE_RE}"'$' ${TOR_CONSENSUS}
}

has_only_unverified_consensus() {
	has_consensus && [ ! -e ${TOR_CONSENSUS} ]
}

wait_for_tor_consensus() {
	log "Waiting for a Tor consensus file to contain a valid time interval"
	while ! has_consensus; do
		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to --format %w%f ${TOR_DIR} || log "timeout"
	done
	log "A Tor consensus file now contains a valid time interval."

	if [ -e ${TOR_CONSENSUS} ]; then
		log "Waiting for the Tor verified consensus file to contain a valid time interval..."
		while ! has_verified_consensus; do
			inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to --format %w%f ${TOR_DIR} || log "timeout"
		done
		log "The Tor verified consensus now contains a valid time interval."
	fi
}

wait_for_working_tor() {
	log "Waiting for Tor to be working (i.e. cached descriptors exist)..."
	while ! tor_is_working; do
		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to --format %w%f ${TOR_DIR} || log "timeout"
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

restart_tor() {
	if service tor status >/dev/null; then
		log "Restarting Tor service"
		service tor restart
	fi
}

maybe_set_time_from_tor_consensus() {
	if [ ! -e ${TOR_CONSENSUS} ]; then
		log "We do not have a Tor consensus so we cannot set the system time according to it."
		return
	fi

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
	restart_tor
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
	if [ "$(($release_date_secs + 15552000))" -lt "$current_date_secs" ]; then
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
	# If Tor cannot verify the consensus this is probably because all
	# authority certificates are "expired" due to a clock far off into
	# the future. In that case let's set the clock to the release date.
	if is_clock_way_off && has_only_unverified_consensus; then
		log "It seems the clock is so badly off that Tor couldn't verify the consensus. Setting system time to the release date, restarting Tor and fetching a new consensus..."
		date --set="$(release_date)" > /dev/null
		service tor stop
		rm -f "${TOR_UNVERIFIED_CONSENSUS}"
		service tor start
		wait_for_tor_consensus
	fi
	maybe_set_time_from_tor_consensus
fi

wait_for_working_tor

touch $TORDATE_DONE_FILE

log "Restarting htpdate"
service htpdate restart
log "htpdate service restarted with return code $?"
