#!/bin/sh

TBB_INSTALL=/usr/local/lib/tor-browser
TBB_PROFILE=/etc/tor-browser/profile
TBB_EXT=/usr/local/share/tor-browser-extensions
TOR_LAUNCHER_LOCALES_DIR=/usr/share/tor-launcher-standalone/chrome/locale

exec_firefox() {
    LD_LIBRARY_PATH="${TBB_INSTALL}"
    export LD_LIBRARY_PATH
    exec "${TBB_INSTALL}"/firefox "${@}"
}

exec_unconfined_firefox() {
    LD_LIBRARY_PATH="${TBB_INSTALL}"
    export LD_LIBRARY_PATH
    exec "${TBB_INSTALL}"/firefox-unconfined "${@}"
}

guess_best_tor_browser_locale() {
    local long_locale short_locale similar_locale
    long_locale="$(echo ${LANG} | sed -e 's/\..*$//' -e 's/_/-/')"
    short_locale="$(echo ${long_locale} | cut -d"-" -f1)"
    if [ -e "${TBB_EXT}/langpack-${long_locale}@firefox.mozilla.org.xpi" ]; then
        echo "${long_locale}"
        return
    elif [ -e "${TBB_EXT}/langpack-${short_locale}@firefox.mozilla.org.xpi" ]; then
        echo "${short_locale}"
        return
    fi
    # If we use locale xx-YY and there is no langpack for xx-YY nor xx
    # there may be a similar locale xx-ZZ that we should use instead.
    similar_locale="$(ls -1 "${TBB_EXT}" | \
        sed -n "s,^langpack-\(${short_locale}-[A-Z]\+\)@firefox.mozilla.org.xpi$,\1,p" | \
        head -n 1)" || :
    if [ -n "${similar_locale}" ]; then
        echo "${similar_locale}"
        return
    fi

    echo 'en-US'
}

guess_best_tor_launcher_locale() {
    local long_locale short_locale
    long_locale="$(echo ${LANG} | sed -e 's/\..*$//' -e 's/_/-/')"
    short_locale="$(echo ${long_locale} | cut -d"-" -f1)"
    if [ -e "${TOR_LAUNCHER_LOCALES_DIR}/${long_locale}" ]; then
        echo ${long_locale}
    elif ls -1 "${TOR_LAUNCHER_LOCALES_DIR}" | grep -q "^${short_locale}\(-[A-Z]\+\)\?$"; then
        # See comment in guess_best_firefox_locale()
        echo ${short_locale}
    else
        echo en-US
    fi
}

configure_xulrunner_app_locale() {
    local profile locale
    profile="${1}"
    locale="${2}"
    mkdir -p "${profile}"/preferences
    echo "pref(\"general.useragent.locale\", \"${locale}\");" > \
        "${profile}"/preferences/0000locale.js
}

configure_best_tor_browser_locale() {
    configure_xulrunner_app_locale "${1}" "$(guess_best_tor_browser_locale)"
}

configure_best_tor_launcher_locale() {
    configure_xulrunner_app_locale "${1}" "$(guess_best_tor_launcher_locale)"
}
