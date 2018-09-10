#!/bin/sh
#
# Heavily inspired by tor-browser.sh, needed since TB60 and the demise
# of the intl.locale.matchOS setting.
#
# Instead of configuring a specific file in the profile directory, just
# implement returning the appropriate locale, so that the caller can
# save it along with other settings in a single file.

TB_EXT=/usr/share/thunderbird/extensions

guess_best_thunderbird_locale() {
    local long_locale short_locale similar_locale
    long_locale="$(echo ${LANG} | sed -e 's/\..*$//' -e 's/_/-/')"
    short_locale="$(echo ${long_locale} | cut -d"-" -f1)"
    if [ -e "${TB_EXT}/langpack-${long_locale}@firefox.mozilla.org.xpi" ]; then
        echo "${long_locale}"
        return
    elif [ -e "${TB_EXT}/langpack-${short_locale}@firefox.mozilla.org.xpi" ]; then
        echo "${short_locale}"
        return
    fi
    # If we use locale xx-YY and there is no langpack for xx-YY nor xx
    # there may be a similar locale xx-ZZ that we should use instead.
    similar_locale="$(ls -1 "${TB_EXT}" | \
        sed -n "s,^langpack-\(${short_locale}-[A-Z]\+\)@firefox.mozilla.org.xpi$,\1,p" | \
        head -n 1)" || :
    if [ -n "${similar_locale:-}" ]; then
        echo "${similar_locale}"
        return
    fi

    echo 'en-US'
}
