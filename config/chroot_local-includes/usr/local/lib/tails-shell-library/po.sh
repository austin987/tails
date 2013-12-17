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
	 intltool-update --dist --gettext-package=tails $locale
      done
   )
}
