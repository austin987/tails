#!/bin/sh

# Notes on the Thunderbird directory structure:
#   • Mail is stored in mbox format.
#   • Folders which contain other folders are named "FolderName.sbd".
#     There will also be a corresponding file—which may be empty—called
#     "FolderName"

set -eu

OLDIFS=$IFS
IFS="
"
packf="/usr/bin/mh/packf"
ICEDOVE="$HOME/.icedove/profile.default"
SAVEPATH="${ICEDOVE}/Mail/Local Folders"
BACKUPPATH="${ICEDOVE}/Mail/Local Folders Backup"
MAILPATH="$HOME/.claws-mail/Mail"

# Check if Icedove is running
if [ "$(pidof icedove)" ]; then
    echo "Icedove seems to be running. Please close Icedove, then run this script again." >&2
    exit 1
fi

if [ ! -x /usr/bin/mh/packf ]; then
    echo "Please install the \"nmh\" package by running \"sudo apt-get update ; sudo apt-get install nmh\"
	then run this script again." >&2
    exit 1
fi

if ! /usr/bin/mh/install-mh -check ; then
    /usr/bin/mh/install-mh -auto
fi

# Do not overwrite existing Inbox
if [ -f "$SAVEPATH/Inbox" ]; then
    #echo "Existing mail folders found. Exiting…" >&2
    echo "Existing mail folders for Icedove found. Did you run this script already or have mailboxes set up?\n
          Do you want to exit or make a backup and copy anyway? Type y for Yes or any key to exit."
    read confirmbackup
    : ${confirmbackup:="n"} # default is to exit
    if [ "$confirmbackup" = "y" ]; then
       mv $SAVEPATH $BACKUPPATH
    else
        echo "Exiting…">&2
        exit 1
    fi
fi

[ -d "$SAVEPATH" ] || mkdir -p "$SAVEPATH"
echo "Saving Mailboxes to $SAVEPATH"

cd "$MAILPATH"
for FULLPATH in $(find . -type d)
do
    FOLDER="$(basename ${FULLPATH})"
    if [ "$(dirname $FULLPATH)"  != "." ]; then
        DIR="$(dirname $FULLPATH | sed -e 's;^\./;;' -e 's;/;.sbd/;g')"
        SBDDIR="$(echo ${DIR}.sbd | sed 's;^\./;;')"
        MBOX="$SAVEPATH/$SBDDIR/${FOLDER}"
        mkdir -p "$SAVEPATH/$SBDDIR"
    else
        MBOX="$SAVEPATH/${FOLDER}"
    fi

    set +u
    if [ "$DIR" != "." ]; then
        [ ! -f "$SAVEPATH/$DIR" ] || touch "$SAVEPATH/$DIR"
        set -u
        touch "$MBOX"
        # packf will exit nonzero if a folder only contains other folders
        yes | $packf +"$FULLPATH" -mbox -file "$MBOX" || true
    fi
done

cd "$SAVEPATH"
for folder in inbox inbox.sbd trash sent
do
    if [ -e "$folder" ]; then
        # Capitalize the first letter, matching what Icedove expects
        mv "$folder" "$(echo $folder | sed -re 's/^\b(.)/\u\1/')"
    fi
done

# Rename to match Icedove defaults
mv -f draft Drafts
mv -f queue "Unsent Messages"
