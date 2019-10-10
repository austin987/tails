#!/bin/sh

TBB_INSTALL=/usr/local/lib/tor-browser
TBB_PROFILE=/etc/tor-browser/profile
TBB_EXT=/usr/local/share/tor-browser-extensions
TOR_LAUNCHER_INSTALL=/usr/local/lib/tor-launcher-standalone
TOR_LAUNCHER_LOCALES_DIR="${TOR_LAUNCHER_INSTALL}/chrome/locale"

# For strings it's up to the caller to add double-quotes ("") around
# the value.
set_mozilla_pref() {
    local file name value prefix
    file="${1}"
    name="${2}"
    value="${3}"
    # Sometimes we might want to do e.g. user_pref
    prefix="${4:-pref}"
    [ -e "${file}" ] && sed -i "/^${prefix}(\"${name}\",/d" "${file}"
    echo "${prefix}(\"${name}\", ${value});" >> "${file}"
}

exec_firefox_helper() {
    local binary="${1}"; shift

    export LD_LIBRARY_PATH="${TBB_INSTALL}"
    export FONTCONFIG_PATH="${TBB_INSTALL}/TorBrowser/Data/fontconfig"
    export FONTCONFIG_FILE="fonts.conf"
    export GNOME_ACCESSIBILITY=1

    # Since Tor Browser 9.0 it has become integrated into the browser,
    # so let's make it the responsibility of callers to explicitly set
    # this variable to 0 if they want to enable Tor Launcher.
    if [ -z "${TOR_SKIP_LAUNCH:-}" ]; then
        export TOR_SKIP_LAUNCH=1
    fi

    # The Tor Browser often assumes that the current directory is
    # where the browser lives, e.g. for the fixed set of fonts set by
    # fontconfig above.
    cd "${TBB_INSTALL}"

    # From start-tor-browser:
    unset SESSION_MANAGER

    exec "${TBB_INSTALL}"/"${binary}" "${@}"
}

exec_firefox() {
    exec_firefox_helper firefox.real "${@}"
}

exec_unconfined_firefox() {
    exec_firefox_helper firefox-unconfined "${@}"
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
    if [ -n "${similar_locale:-}" ]; then
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
    set_mozilla_pref "${profile}"/prefs.js \
                     "intl.locale.requested" "\"${locale}\"" \
                     "user_pref"
}

configure_best_tor_browser_locale() {
    local profile best_locale
    profile="${1}"
    best_locale="$(guess_best_tor_browser_locale)"
    configure_xulrunner_app_locale "${profile}" "${best_locale}"
    cat "/etc/tor-browser/locale-profiles/${best_locale}.js" \
        >> "${profile}/prefs.js"
}

configure_best_tor_launcher_locale() {
    configure_xulrunner_app_locale "${1}" "$(guess_best_tor_launcher_locale)"
}

supported_tor_browser_locales() {
    # The default is always supported
    echo en-US
    for langpack in "${TBB_EXT}"/langpack-*@firefox.mozilla.org.xpi; do
        basename "${langpack}" | sed 's,^langpack-\([^@]\+\)@.*$,\1,'
    done
}

set_firefox_content_process_count() {
    local profile="$1"
    local count="$2"

        set_mozilla_pref "${profile}/prefs.js" \
                         "dom.ipc.processCount" "$count" \
                         user_pref
}

configure_tor_browser_memory_usage() {
    local profile="${1}"

    # Unit: KiB
    system_ram=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)

    if [ "$system_ram" -lt "$((3 * 1024 * 1024))" ]; then
        set_firefox_content_process_count "$profile" 2
    fi
}
