#!/bin/sh

# Import is_package_installed
. /usr/local/lib/tails-shell-library/common.sh

install_fake_package() {
    local name version section tmp control_file
    name="${1}"
    version="${2}"
    section="${3:-misc}"
    if ! is_package_installed equivs; then
        apt-get install --yes equivs
    fi
    tmp="$(mktemp -d)"
    control_file="${tmp}/${name}_${version}.control"
    cat > "${control_file}" << EOF
Section: ${section}
Priority: optional
Homepage: https://tails.boum.org/
Standards-Version: 3.9.6

Package: ${name}
Version: ${version}
Maintainer: Tails developers <tails@boum.org>
Architecture: all
Description: (Fake) ${name}
 Dummy packaged used to meet some dependency without installing the
 real ${name} package.
EOF
    (
        cd "${tmp}"
        equivs-build "${control_file}"
        dpkg -i "${tmp}/${name}_${version}_all.deb"
    )
    rm -R "${tmp}"
}

