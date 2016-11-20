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

            if [ ! -f ${locale}.po.new -a ! -f ${locale}.po ]; then
                echo "New PO file for ${locale} does not exist. Skipping."
                continue
            fi
            if [ $(diff "${locale}.po" "${locale}.po.new") | grep -Ec ^"?>" -eq 1 && \
                 $(diff "${locale}.po" "${locale}.po.new") | grep -Ec ^"?<" -eq 1 ]; then
                 if diff "${locale}.po" "${locale}.po.new" | grep -E ^'(?:>|<) "POT-Creation-Date:'; then
                    echo "${locale}: Only header changes in potfile, delete new PO file."
                    rm ${locale}.po.new
                fi
            else
                echo "${locale}: Real changes in potfile: substitute old PO file."
                mv ${locale}.po.new ${locale}.po
            fi
        done
    )
}
