#!/bin/sh
# -*- mode: sh; sh-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim: set filetype=sh sw=4 sts=4 expandtab autoindent:

set -e

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
    echo "$lang: $(($TRANSLATED*100/$TOTAL))% strings translated, $(($FUZZY*100/$TOTAL))% strings fuzzy, $(($TRANSLATED_WC*100/$TOTAL_WC))% words translated"
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
