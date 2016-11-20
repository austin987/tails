# This shell library is meant to be used with `set -e` and `set -u`.

po_languages () {
   for po in po/*.po ; do
      rel="${po%.po}"
      echo "${rel#po/}"
   done
}

intltool_update_po () {
   (
        cd po
        for locale in "$@" ; do
            intltool-update --dist --gettext-package=tails $locale -o ${locale}.po.new

            if [ ! -f ${locale}.po.new && ! -f ${locale}.po ]; then
                echo "New PO file for ${locale} does not exist. Skipping."
                continue
            fi
            if [ $(diff "${locale}.po" "${locale}.po.new" | grep ^"> " | wc -l) -eq 1 ]; then
                if diff -aw "${locale}.po" "${locale}.po.new" | grep ^'> "POT-Creation-Date:'; then
                    echo "${locale}: Only header changes in potfile, Delete new PO file."
                    rm -f ${locale}.po.new
                fi
            else
                echo "${locale}: Real changes in potfile: substitute old PO file."
                mv ${locale}.po.new ${locale}.po
            fi
        done
    )
}
