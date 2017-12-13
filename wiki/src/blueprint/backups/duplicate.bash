#!/bin/bash

I_DEV=""
O_DEV=""
OUSB=""
IUSB=""

#
# only root can run 
#
if [ `whoami` != "root" ];then
    zenity --title="Insufficient Permission" \
	--info --text="Only root can run this command; aborting." --timeout=5 2>/dev/null
    exit 1
fi

zenity --title="Close all programs" \
	--info \
	--text="It is strongly recommended you close all programs before starting the duplication process.\nIt typically takes 30 minutes or more to complete.\n\nPlease close any running programs now and Click OK to continue." 2>/dev/null


#
# Find USB drives.  
# default first one is the INPUT and the SECOND is backup
#
for d in `readlink -e /dev/disk/by-id/usb*0:0|sort`; do
    if [ "$I_DEV" = "" ];then
	I_DEV="TRUE $d"
    else
	# If there are more than two USB drives, create a list
	I_DEV="$I_DEV FALSE $d"
    fi
done

#
# select the input device, set IUSB
IUSB=`zenity --title="Select Source Device" \
	--list \
	--radiolist \
	--text="Select Source USB Device" \
	--column="Select" \
	--column="Device" \
	$I_DEV 2>/dev/null`

if [ $? -ne 0 ];then
    zenity --title="Aborting..." \
	--info \
	--text="Duplication Aborted, no source device selected." --timeout=5 2>/dev/null
    exit 1;
fi

# 
# Confirm IUSB is the boot device!
#
udevadm info $IUSB |grep -q "^S: TailsBootDev"
if [ $? -ne 0 ];then
    zenity --title="Invalid Source" \
	--question \
	--text="WARNING: Source Device, $IUSB, is not bootable.\nPlease confirm you want to duplicate another USB drive." 2>/dev/null 
    if [ $? -ne 0 ];then
	zenity --title="Aborting..." \
	    --info --text="Aborted, did not confirm source device: $IUSB" --timeout=5 2>/dev/null
	exit 1
    fi
fi

## Now, get the Output device list
## excluding the selected one from the target
for d in `readlink -e /dev/disk/by-id/usb*0:0|sort`; do
    if [ "$d" = "$IUSB" ];then
	: ;
    elif [ "$O_DEV" = "" ];then
	O_DEV="TRUE $d"
    else
	# If there are more than two USB drives, create a list
	O_DEV="$O_DEV FALSE $d"
    fi
done
if [ "$O_DEV" = "" ];then
    zenity --title="Aborting..." \
	--info \
	--text="Aborted, no valid target device found." \
	--timeout=10 2>/dev/null
    exit 1
fi


OUSB=`zenity --title="Select Target Device" \
	--list \
	--radiolist \
	--text="Select Target USB Device" \
	--column="Select" \
	--column="Device" \
	$O_DEV 2>/dev/null`

if [ $? -ne 0 ];then
    zenity --title="Aborting..." \
	--info \
	--text="Duplication Aborted, no target device selected." \
	--timeout=5 2>/dev/null
    exit 1;
fi

# 
# Check OUSB boot status!
#
udevadm info $OUSB |grep -q "^S: TailsBootDev"
if [ $? -eq 0 ];then
    zenity --title="Invalid Target" \
	--question \
	--text="WARNING: Target Device, $OUSB, is bootable.\nPlease confirm you want to clobber your current boot device!!!\n\nWARNING: NOT RECOMMENDED! Abort Recommended (click No)." 2>/dev/null 
    if [ $? -ne 0 ];then
	zenity --title="Aborting..." \
	    --info --text="Aborted, did not confirm target device: $OUSB" --timeout=5 2>/dev/null
	exit 1
    fi
fi
#
# Confirm , are you sure you want to proceed?  really?
#
zenity	--title="WARNING: Please confirm" \
	--question \
	--default-cancel \
	--text="WARNING! WARNING!! WARNING!!! \n\nAll contents on $OUSB will be lost!\n\nClick 'Yes' to start duplication of $IUSB to $OUSB!\n" 2>/dev/null

if [ $? -eq 0 ];then
    ###
    ### Well ok, HERE WE GO! Let the backup begin!!!
    ###
    sync;
    s=`date`
    (sleep 2;dd if=${IUSB} of=${OUSB} bs=8M) |
	zenity --progress \
	--title="Duplicating $IUSB to $OUSB in progress..." \
	--pulsate \
	--text="Please be patient.\nThe Duplication can take 30 minutes or more.\nStarted at: ${s}" \
	--auto-kill --auto-close 2>/dev/null
    DDRESULT=$?
    e=`date`

    ###
    ### all done!
    ###
    if [ ${DDRESULT} -eq 0 ];then
	result="Succeeded."
    else
	result="Aborted, $OUSB very likely corrupted."
    fi
    # report the resulrts...
    zenity --title="Duplication Complete" \
	--info \
	--text="Duplication ${result}\nStarted: ${s}\nEnded: ${e}"  2>/dev/null
    exit 0
	
elif [ $? -eq 1 ];then
    # phew! dodged a bullet!
    zenity --info \
	--text="Duplication Aborted, no changes were made." \
	--timeout=5 2>/dev/null
    exit 1
fi
