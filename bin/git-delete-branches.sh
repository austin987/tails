#!/bin/sh

#############################
#    Configure as needed    #
#############################
# Set to 1 to remove merged branches from remotes
REMOVE_FROM_REMOTE=1

# If REMOVE_FROM_REMOTE was set to 1 above, set this to the remote
# where branches shall be removed
MANAGED_REMOTE="origin"

# These branches will never be removed
BRANCHES_TO_KEEP="master head devel experimental testing"

######################################################
#  Nothing below this point should need to be edited #
######################################################

generate() {
    # Take in space delimited string, output | delimited
    echo "$1" | sed 's/\s/|/g'
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "${PWD} is not a Git tree. Exiting."
    exit 1
fi

CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT" != 'master' ]; then
    echo "Switch to the master branch before running this script." >&2
    exit 1
fi

echo "Fetching from remote ${MANAGED_REMOTE}..."
git fetch --prune "$MANAGED_REMOTE"

[ $REMOVE_FROM_REMOTE -eq 1 ] && \
   REMOTE_BR=$(git branch -r --merged | grep -v '\->' |\
    grep -vE "^\s+([^/]+)/($(generate "$BRANCHES_TO_KEEP"))$" |\
    grep -E "^\s+$MANAGED_REMOTE/")
LOCAL_BR=$(git branch --merged | grep -Ev "^\s+($(generate "$BRANCHES_TO_KEEP"))$")

if [ -z "$REMOTE_BR" ] && [ -z "$LOCAL_BR" ]; then
    echo "Woohoo! No unmerged branches!" >&2
else
    [ -n "$REMOTE_BR" ] && \
         echo "The following merged remote branches will be removed:" && \
         echo "$REMOTE_BR"

    [ -n "$LOCAL_BR" ] && \
         echo "The following merged local branches will be removed:" && \
         echo "$LOCAL_BR"
    echo -n "Remove these branches? (y/N): "
    read answer
    case $answer in
        y|Y|Yes|yes)
	    REFS=''
            for BRANCH in $REMOTE_BR; do
                echo -n "Remove branch '$BRANCH'? (Y/n): "
                read answer
                case "$answer" in
                    ''|y|Y|Yes|yes)
                        REFS="$REFS $(echo $BRANCH | sed 's/^[^/]\+\/\(.\+\)/:\1/')"
                        ;;
                esac
            done
	    echo "$REFS" | xargs -n30 git push "$MANAGED_REMOTE"
        if [ -n "$LOCAL_BR" ]; then
            git branch --merged | grep -Ev "^\s+($(generate "$BRANCHES_TO_KEEP"))$" | xargs -n30 git branch -d
            fi
            ;;
        *)
            echo "Aborting due to user request." >&2
            exit 0
    esac
fi

