#!/bin/sh
# -*- mode: sh; sh-basic-offset: 4; indent-tabs-mode: nil; -*-
# vim: set filetype=sh sw=4 sts=4 expandtab autoindent:

# Usage: check_po.sh [LANGUAGE]

if ! [ -x "`which i18nspector`" ] ; then
    echo "i18nspector: command not found"
    echo "You need to install i18nspector first. See /contribute/l10n_tricks."
    exit 2
fi

ONLY_LANG="$1"

PATTERNS_FILE="$(mktemp -t XXXXXX.patterns)"
echo "
boilerplate-in-date
boilerplate-in-language-team
boilerplate-in-last-translator
boilerplate-in-project-id-version
conflict-marker-in-header-entry
fuzzy-header-entry
incorrect-plural-forms
invalid-content-transfer-encoding
invalid-date
invalid-language
invalid-last-translator
language-team-equal-to-last-translator
no-language-header-field
no-package-name-in-project-id-version
no-report-msgid-bugs-to-header-field
no-version-in-project-id-version
unable-to-determine-language
unknown-poedit-language
" | grep -v '^$' > $PATTERNS_FILE

if [ -n "$ONLY_LANG" ]; then
    FILE_GLOB="*.${ONLY_LANG}.po"
else
    FILE_GLOB="*.po"
fi

find -iname "$FILE_GLOB" -exec i18nspector '{}' \; | grep -v -f $PATTERNS_FILE
