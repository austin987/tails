#!/bin/sh

# Manage initscripts

# Including common functions
. "${LH_BASE:-/usr/share/live-helper}"/scripts/build.sh

# Get LH_DISTRIBUTION
Read_conffiles config/bootstrap

# Setting static variables
DESCRIPTION="$(Echo 'managing initscripts')"
HELP=""
USAGE="${PROGRAM}"

Set_defaults

Echo_message "managing initscripts"

disable_service () {
   local INITSCRIPT="$1"
   case "${LH_DISTRIBUTION}" in
      squeeze|sid)
	 update-rc.d ${INITSCRIPT} disable
	 ;;
      *)
	 for startlink in /etc/rc[S2-5].d/S[0-9][0-9]${INITSCRIPT} ; do
	    stoplink=`echo "${startlink}" | sed -e 's,^\(/etc/rc[S2-5].d/\)S,\1K,'`
	    mv "${startlink}" "${stoplink}"
	 done
	 ;;
   esac
}

# enable custom initscripts
update-rc.d tails-detect-virtualization defaults
update-rc.d tails-wifi defaults

# we run Tor ourselves after HTP via NetworkManager hooks
disable_service tor
