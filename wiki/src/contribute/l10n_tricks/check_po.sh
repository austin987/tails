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
no-plural-forms-header-field
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

CPUS=$(egrep '^processor[[:space:]]+:' /proc/cpuinfo | wc -l)
OUTPUT=$(find -iname "$FILE_GLOB" -print0 \
                | xargs -0 --max-procs="$CPUS" --max-args=64 i18nspector \
                | grep -v --line-regexp '' \
                | grep -v -f $PATTERNS_FILE)

echo -n "$OUTPUT"

# Exit code: 0 iff. the filtered i18nspector's output was empty
[ $(echo -n "$OUTPUT" | wc -l) -eq 0 ]
