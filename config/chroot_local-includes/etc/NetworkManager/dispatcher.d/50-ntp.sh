#!/bin/bash

# Rationale: Tor needs a somewhat accurate clock to work, and for that NTP is
# ideal. However, since DNS lookups are made through the Tor network, and all
# information about local DNS servers obtained through DHCP is discarded, we
# have to do it some other way. OpenDNS comes to mind, but any DNS server that
# we can expect have the same IP address for a long time will do.

# Note that all network operations (host, ntpdate) are done with the ntp user.
# this user has an exception in the iptables configuration granting it direct
# access to the network, which is necessary. the ntp user doesn't have the
# privilege to run adjtime()/settimeofday() so we only use ntpdate to query
# the time difference/offset and run date as root to set the time.

# Run whenever an interface gets "up", not otherwise:
if [[ $2 != "up" ]]; then
	exit 0
fi

if ! which ntpdate; then
	exit 0
fi

DNS_SERVER1="208.67.222.222"
DNS_SERVER2="208.67.220.220"
NTP_POOL="pool.ntp.org"

I=0
for X in $(sudo -u ntp sh -c "host ${NTP_POOL} ${DNS_SERVER1} && \
			      host ${NTP_POOL} ${DNS_SERVER2}" | \
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
	NTP_ANSWER=$(sudo -u ntp ntpdate -s -u -q ${NTP_ADDR[${I}]})

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
