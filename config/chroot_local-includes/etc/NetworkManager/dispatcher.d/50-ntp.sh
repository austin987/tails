#!/bin/bash

# Rationale: Tor needs a somewhat accurate clock to work, and for that
# NTP is ideal. We then need to get the IPs of a bunch of NTP servers.
# However, since DNS lookups are made through the Tor network, we use
# the local DNS servers obtained through DHCP if possible, or the
# OpenDNS ones, else.

# Note that all network operations (host, ntpdate) are done with the ntpdate
# user, who has an exception in the firewall configuration granting it direct
# access to the network, which is necessary. The ntpdate user doesn't have the
# privilege to run adjtime()/settimeofday() so we only use ntpdate to query
# the time difference/offset and run date as root to set the time.

# Run whenever an interface gets "up", not otherwise:
if [[ $2 != "up" ]]; then
	exit 0
fi

NTP_POOL="pool.ntp.org"

if [[ -n "${DHCP4_DOMAIN_NAME_SERVERS}" ]]; then
	NAME_SERVERS="${DHCP4_DOMAIN_NAME_SERVERS}"
else
	NAME_SERVERS="208.67.222.222 208.67.220.220"
fi

DNS_QUERY_CMD=`for NS in ${NAME_SERVERS}; do
                   echo -n "|| host ${NTP_POOL} ${NS} ";
	       done | \
	       tail --bytes=+4`

I=0
for X in $(sudo -u ntpdate sh -c "${DNS_QUERY_CMD}" | \
	   grep "${NTP_POOL} has address" | \
	   cut -d ' ' -f 4); do
	NTP_ADDR[${I}]="${X}"
	I=$[${I}+1]
done

if [[ ${I} -eq 0 ]]; then
	echo "Failed to resolve pool.ntp.org" >&2
	exit 1
fi

I=0
NTP_OFFSET=""
while [[ -n ${NTP_ADDR[${I}]} ]] && [[ -z ${NTP_OFFSET} ]]; do
	NTP_ANSWER=$(sudo -u ntpdate ntpdate -s -u -q ${NTP_ADDR[${I}]})

	# On success, grep the offset (including sign). Note that it gets
	# truncated -- anything below whole seconds are beyond date's
	# precision anyway.
	if [[ $? -eq 0 ]]; then
		NTP_OFFSET=$(echo ${NTP_ANSWER} | sed -e "s/^.*offset \(-\?[[:digit:]]\+\)\..*$/\1/")
	fi
	I=$[${I}+1]
done

if [[ -z ${NTP_OFFSET} ]]; then
	echo "ntpdate failed" >&2
	exit 1
fi

# Get a date compatible string of the correct time (by current time modified
# by the offset) and then use it to set the system time.
DATE_STRING=$(date --date "${NTP_OFFSET} seconds" +%m%d%H%M%Y.%S) && \
date ${DATE_STRING} &> /dev/null

exit $?
