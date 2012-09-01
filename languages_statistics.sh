#!/bin/bash

LANGUAGES="de es fr pt"

for LANG in $LANGUAGES ; do
    PO_FILES="$(mktemp -t XXXXXX.$LANG)"
    find -iname "*.$LANG.po" > $PO_FILES
    PO_MESSAGES="$(mktemp -t XXXXXX.$LANG.po)"
    msgcat --files-from=$PO_FILES --output=$PO_MESSAGES
    TOTAL=`grep ^msgid $PO_MESSAGES | wc -l`
    TRANSLATED=`msgattrib --translated $PO_MESSAGES | grep ^msgid | wc -l`
    echo "$LANG: $(($TRANSLATED*100/$TOTAL))%"
    rm -f $PO_FILES $PO_MESSAGES
done
