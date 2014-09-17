#!/bin/bash
# -*- mode: sh; sh-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim: set filetype=sh sw=4 sts=4 expandtab autoindent:

set -eu
set -o pipefail

LANGUAGES=${@:-de fr pt}

count_msgids () {
    cat | grep -E '^msgid\s+' | wc -l
}

count_original_words () {
    cat | grep ^msgid | sed 's/^msgid "//g;s/"$//g' | wc -w
}

count_translated_words () {
    cat | grep ^msgstr | sed 's/^msgstr "//g;s/"$//g' | wc -w
}

statistics () {
    PO_MESSAGES="$(mktemp -t XXXXXX.$lang.po)"
    msgcat --files-from=$PO_FILES --output=$PO_MESSAGES
    TOTAL=$(msgattrib --no-obsolete $PO_MESSAGES | count_msgids)
    TOTAL_WC=$(
        msgattrib --no-obsolete --no-wrap $PO_MESSAGES | count_original_words
    )
    FUZZY=$(msgattrib --only-fuzzy --no-obsolete $PO_MESSAGES | count_msgids)
    TRANSLATED=$(
        msgattrib --translated --no-fuzzy --no-obsolete $PO_MESSAGES \
            | count_msgids
    )
    TRANSLATED_WC=$(
        msgattrib --translated --no-fuzzy --no-obsolete --no-wrap $PO_MESSAGES \
	    | count_translated_words
    )
    echo "  - $lang: $(($TRANSLATED*100/$TOTAL))% ($TRANSLATED) strings translated, $(($FUZZY*100/$TOTAL))% strings fuzzy, $(($TRANSLATED_WC*100/$TOTAL_WC))% words translated"
    rm -f $PO_FILES $PO_MESSAGES
}

# sanity checks

if pwd | grep -qs 'wiki/src$' ; then
    WEBSITE_ROOT_DIR='.'
elif [ -d '.git' ] ; then
    WEBSITE_ROOT_DIR='wiki/src'
else
    echo >&2 "Error: $(basename $0) is meant to be run either from the wiki/src directory,"
    echo >&2 "       or from the root of the source tree"
    exit 1
fi

# all PO files
echo "All website PO files"
echo "===================="
echo ""

for lang in $LANGUAGES ; do
    PO_FILES="$(mktemp -t XXXXXX.$lang)"
    find "$WEBSITE_ROOT_DIR" -iname "*.$lang.po" > $PO_FILES
    find "$WEBSITE_ROOT_DIR" -path "*/locale/$lang/LC_MESSAGES/*.po" >> $PO_FILES
    statistics $PO_FILES
done

# core PO files
echo ""
echo "[[Core PO files|contribute/l10n_tricks/core_po_files.txt]]"
echo "=========================================================="
echo ""

for lang in $LANGUAGES ; do
    PO_FILES="$(mktemp -t XXXXXX.$lang)"
    cat "$WEBSITE_ROOT_DIR"/contribute/l10n_tricks/core_po_files.txt \
        | sed "s/$/.$lang.po/g" \
        | sed "s,^,$WEBSITE_ROOT_DIR/," \
        > $PO_FILES
    statistics $PO_FILES
done
