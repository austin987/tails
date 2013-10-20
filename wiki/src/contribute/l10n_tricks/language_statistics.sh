#!/bin/sh
# -*- mode: sh; sh-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim: set filetype=sh sw=4 sts=4 expandtab autoindent:

set -e

LANGUAGES=${@:-de es fr pt}

count_msgids () {
    cat | grep -E '^msgid\s+' | wc -l
}

statistics () {
    PO_MESSAGES="$(mktemp -t XXXXXX.$lang.po)"
    msgcat --files-from=$PO_FILES --output=$PO_MESSAGES
    TOTAL=$(msgattrib --no-obsolete $PO_MESSAGES | count_msgids)
    FUZZY=$(msgattrib --only-fuzzy --no-obsolete $PO_MESSAGES | count_msgids)
    TRANSLATED=$(
        msgattrib --translated --no-fuzzy --no-obsolete $PO_MESSAGES \
            | count_msgids
    )
    echo "$lang: $(($TRANSLATED*100/$TOTAL))% translated, $(($FUZZY*100/$TOTAL))% fuzzy"
    rm -f $PO_FILES $PO_MESSAGES
}

# all PO files
echo "All PO files"
echo "============"
echo ""

for lang in $LANGUAGES ; do
    PO_FILES="$(mktemp -t XXXXXX.$lang)"
    find -iname "*.$lang.po" > $PO_FILES
    find -path "*/locale/$lang/LC_MESSAGES/*.po" >> $PO_FILES
    statistics $PO_FILES
done

# core PO files
echo ""
echo "Core PO files"
echo "============="
echo ""

for lang in $LANGUAGES ; do
    PO_FILES="$(mktemp -t XXXXXX.$lang)"
    cat contribute/l10n_tricks/core_po_files.txt | sed "s/$/.$lang.po/g" > $PO_FILES
    statistics $PO_FILES
done
