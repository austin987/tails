#!/bin/sh

language_code_from_locale () {
    echo "${1}" | sed "s,\(_\|\.\).*$,,"
}

localize_tails_doc_page () {
    local page="${1}"
    local lang_code="$(language_code_from_locale "${LANG}")"
    local try_page
    for locale in "${lang_code}" "en"; do
        try_page="${page}.${locale}.html"
        if [ -r "${try_page}" ]; then
            echo "${try_page}"
            return 0
        fi
    done
    return 1
}
