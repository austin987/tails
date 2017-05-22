# This shell library is meant to be used with `set -e` and `set -u`.

po_languages () {
   for po in po/*.po ; do
      rel="${po%.po}"
      echo "${rel#po/}"
   done
}

diff_without_pot_creation_date () {
   old="$1"
   new="$2"

   [ $(diff "$old" "$new" | grep -Ec '^>') -eq 1 -a \
     $(diff "$old" "$new" | grep -Ec '^<') -eq 1 -a \
     $(diff "$old" "$new" | grep -Ec '^[<>] "POT-Creation-Date:') -eq 2 ]
}

intltool_update_po () {
   (
        cd po
        for locale in "$@" ; do
            intltool-update --dist --gettext-package=tails $locale -o ${locale}.po.new

            [ -f ${locale}.po ]     || continue
            [ -f ${locale}.po.new ] || continue

            if diff_without_pot_creation_date "${locale}.po" "${locale}.po.new"; then
                    echo "${locale}: Only header changes in potfile, delete new PO file."
                    rm ${locale}.po.new
            else
                echo "${locale}: Real changes in potfile: substitute old PO file."
                mv ${locale}.po.new ${locale}.po
            fi
        done
    )
}
