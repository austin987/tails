#!/bin/sh

# Notes on the Thunderbird directory structure:
#   • Mail is stored in mbox format.
#   • Folders which contain other folders are named "FolderName.sbd".
#     There will also be a corresponding file—which may be empty—called
#     "FolderName"

set -e
set -u

OLDIFS=$IFS
IFS="
"
packf="/usr/bin/mh/packf"
ICEDOVE="$HOME/.icedove/profile.default"
SAVEPATH="${ICEDOVE}/Mail/Local Folders"
BACKUPPATH="${ICEDOVE}/Mail/Local Folders Backup $(date +%Y-%m-%d\ %H:%M:%S)"
MAILPATH="$HOME/.claws-mail/Mail"

# Check if Icedove is running
if [ "$(pidof icedove)" ]; then
    echo "Icedove seems to be running. Please close Icedove and run this script again." >&2
    exit 1
fi

# Check if mailpath exists at the expected location
if [ ! -d "$MAILPATH" ]; then
    echo "Cannot find the default Claws Mail email folder ($MAILPATH).
You might not have any emails saved in the persistent storage or you use a different location.
Consider moving your email folder to $MAILPATH.
Exiting." >&2
    exit 1
fi

if [ ! -x /usr/bin/mh/packf ]; then
    echo "Please install the \"nmh\" package by executing \"sudo apt-get update ; sudo apt-get install nmh\".
Then run this script again." >&2
    exit 1
fi

# Create a mh_profile, overwrite if it exists
echo "Path: $MAILPATH" > "$HOME/.mh_profile"

if ! /usr/bin/mh/install-mh -check ; then
    /usr/bin/mh/install-mh -auto
fi

# Do not overwrite existing Inbox
if [ -f "$SAVEPATH/Inbox" ]; then
    echo "Existing mailboxes found for Icedove. Did you run this script already or have other Icedove mailboxes set up?
Do you want to exit or make a backup of the Icedove mailboxes and copy the Claws Mail mailboxes anyway?

Type [b] to back up the existing Icedove folders or any key to exit."
    read confirmbackup
    : ${confirmbackup:="n"} # default is to exit
    if [ "$confirmbackup" = "b" ]; then
       mv $SAVEPATH $BACKUPPATH
    else
        echo "Exiting…">&2
        exit 1
    fi
fi

[ -d "$SAVEPATH" ] || mkdir -p "$SAVEPATH"
echo "Saving mailboxes to $SAVEPATH"

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
        # packf is too verbose for us by default
        yes | $packf +"$FULLPATH" -mbox -file "$MBOX" 2>&1 | grep -v "^packf: no messages in" >&2 || true
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

echo "Migration done. You can now open Icedove and set up your account."
