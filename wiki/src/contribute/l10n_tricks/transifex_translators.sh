#!/bin/sh

set -e
set -u

PROJECTS="liveusb-creator tails-greeter tails-iuk tails-misc tails-perl5lib tails-persistence-setup whisperback"
GIT_TOPLEVEL_DIR=$(git rev-parse --show-toplevel)
TOR_TRANSLATION_DIR="$GIT_TOPLEVEL_DIR/tmp/tor-translation"

(
   cd "$TOR_TRANSLATION_DIR"
   for project in $PROJECTS; do
      for branch in "$project" "${project}_completed"; do
	 git checkout --quiet "$branch"
	 git reset --quiet --hard "origin/$branch"
	 git grep -H 'Last-Translator' | grep -v '^templates/' \
	    | sed -e 's/^\([A-Za-z_]\+\)\/\1\.po:"Last-Translator: \(.\+\)\\n"$/\1 \2/' \
	    | grep -Ev '(FULL NAME|tor-assistants@torproject.org|colin@torproject.org|runa.sandvik@gmail.com|support-team-private@lists.torproject.org|<>)'
      done
   done | sort -u
)
