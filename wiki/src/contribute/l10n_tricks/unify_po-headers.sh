#!/bin/sh
# -*- mode: sh; sh-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim: set filetype=sh sw=4 sts=4 expandtab autoindent:
# This file unifies PO headers and rewraps PO files to 79 chars.

set -e

if [ $# -ge 1 ] ; then
    FILE_GLOB="*.${1}.po"
else
    FILE_GLOB='*.po'
fi

CPUS=$(egrep '^processor[[:space:]]+:' /proc/cpuinfo | wc -l)

# FNAME is full path (./pathto/file.inital.de.po)
# BASENAME is only the name of the file (file.inital.de.po)
# BASENAME1 is the name without po (file.inital.de)
# LANG the language we expect (de)

find -wholename ./tmp -prune -o \( -iname "$FILE_GLOB" -print0 \) \
            | xargs -0 --max-procs="$CPUS" --max-args=64 -I {} \
            sh -c 'FNAME="{}"; BASENAME="${FNAME#*/}"; BASENAME1="${BASENAME%.*}"; LANG="${BASENAME1##*.}"; sed -i -e "s/^\"Language: .*$/\"Language: ${LANG}\\\n\"/" {}'

# unfortunately the syntax of po headers can expand to different lines,
# that's why we need to treat sed to parse correctly multilines.
# the way we use is to merge all lines together (1h;1!H) and search/replace in the whole string
# another option would be to call python/perl to get a reex that is easier to read.
# python: '^.*<Key>:(.*\n)*.*\\n.*$'

# Unify Project-Id-Version
find -wholename ./tmp -prune -o \( -iname "$FILE_GLOB" -print0 \) \
        | xargs -0 --max-procs="$CPUS" --max-args=64 -I {} \
	sed -i -n '1h;1!H;${;g;s/[^\n]*Project-Id-Version: [^\\]*\\n[^\n]*/"Project-Id-Version: \\n"/g;p;}' {}

# Unify Language-Team
find -wholename ./tmp -prune -o \( -iname "$FILE_GLOB" -print0 \) \
        | xargs -0 --max-procs="$CPUS" --max-args=64 -I {} \
        sed -i -n '1h;1!H;${;g;s/[^\n]*Language-Team: [^\\]*\\n[^\n]*/"Language-Team: Tails translators <tails-l10n@boum.org>\\n"/g;p;}' {}

# Unify Last-Translator
find -wholename ./tmp -prune -o \( -iname "$FILE_GLOB" -print0 \) \
        | xargs -0 --max-procs="$CPUS" --max-args=64 -I {} \
	sed -i -n '1h;1!H;${;g;s/[^\n]*Last-Translator: [^\\]*\\n[^\n]*/"Last-Translator: Tails translators\\n"/g;p;}' {}

# Rewrap po file to 79 chars
find -wholename ./tmp -prune -o \( -iname "$FILE_GLOB" -print0 \) \
        | xargs -0 --max-procs="$CPUS" --max-args=64 -I {} \
        msgcat -w 79 "{}" -o "{}"
