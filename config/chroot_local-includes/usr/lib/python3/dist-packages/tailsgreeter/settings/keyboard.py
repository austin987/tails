import logging
import gi

from tailsgreeter.settings.localization import LocalizationSetting, ln_iso639_tri, \
    ln_iso639_2_T_to_B, language_from_locale, country_from_locale

gi.require_version('Gio', '2.0')
gi.require_version('GLib', '2.0')
gi.require_version('GnomeDesktop', '3.0')
gi.require_version('GObject', '2.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Gio, GLib, GnomeDesktop, GObject, Gtk


class KeyboardSetting(LocalizationSetting):

    def __init__(self):
        super().__init__()
        self.xkbinfo = GnomeDesktop.XkbInfo()
        self.value = 'us'

    def get_tree(self, layout_codes=None) -> Gtk.TreeStore:
        if not layout_codes:
            layout_codes = self.get_all()

        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name
        layouts = self._layouts_split_names(layout_codes)
        for group_name in sorted(layouts.keys()):
            layout_codes = sorted(layouts[group_name],
                                  key=lambda x: self._layout_name(x).lower())
            treeiter_group = treestore.append(parent=None)
            # we fill the title with the 1st layout of the group
            treestore.set(treeiter_group, 0, layout_codes[0])
            treestore.set(treeiter_group, 1, group_name)
            if len(layout_codes) > 1:
                for layout_code in layout_codes:
                    treeiter_layout = treestore.append(parent=treeiter_group)
                    treestore.set(treeiter_layout, 0, layout_code)
                    treestore.set(treeiter_layout, 1, self._layout_name(layout_code))
        return treestore

    def get_name(self) -> str:
        return self._layout_name(self.get_value())

    def get_all(self) -> [str]:
        """Return a list of all keyboard layout codes

        """
        return self.xkbinfo.get_all_layouts()

    def set_value(self, layout, chosen_by_user=False):
        super().set_value(layout)
        self.value_changed_by_user = chosen_by_user
        self._apply_layout_to_current_screen()

    def _layout_name(self, layout_code) -> str:
        layout_exists, display_name, short_name, xkb_layout, xkb_variant = \
                self.xkbinfo.get_layout_info(layout_code)
        if not layout_exists:
            logging.warning("Layout code '%s' does not exist", layout_code)
        return display_name

    def _layouts_split_names(self, layout_codes) -> [str]:
        layouts_names = {}
        for layout_code in layout_codes:
            layout_name = self._layout_name(layout_code)
            country_name, s, v = layout_name.partition(' (')
            if country_name not in layouts_names:
                layouts_names[country_name] = {layout_code}
            else:
                layouts_names[country_name].add(layout_code)
        return layouts_names

    def _layouts_for_language(self, lang_code) -> [str]:
        """Return the list of available layouts for given language
        """
        try:
            t_code = ln_iso639_tri(lang_code)
        except KeyError:
            t_code = lang_code
        if t_code == 'nno' or t_code == 'nob':
            t_code = 'nor'

        layouts = self.xkbinfo.get_layouts_for_language(t_code)

        if t_code == 'hrv':
            layouts.append('hr')

        if len(layouts) == 0:
            b_code = ln_iso639_2_T_to_B(t_code)
            logging.debug(
                "got no layout for ISO-639-2/T code %s, "
                "trying with ISO-639-2/B code %s",
                t_code, b_code)

            layouts = self.xkbinfo.get_layouts_for_language(b_code)

        logging.debug('got %d layouts for %s', len(layouts), lang_code)
        return layouts

    def _layouts_for_country(self, country) -> [str]:
        """Return the list of available layouts for given country
        """
        # XXX: it would be logical to use:
        #     self.__xklinfo.get_layouts_for_language(country)
        # but it doesn't actually return the list of all layouts matching a
        # country.
        def country_filter(layout):
            cc = country.lower()
            return (layout == cc) or ('+' in layout) and (layout.split('+')[0] == cc)

        layouts = list(filter(country_filter, self.get_all()))

        logging.debug('got %d layouts for %s', len(layouts), country)
        return layouts

    @staticmethod
    def _split_variant(layout_code) -> (str, str):
        if '+' in layout_code:
            return layout_code.split('+')
        else:
            return layout_code, None

    def _filter_layouts(self, layouts, country, language):
        """Try to select the best layout in a layout list
        """
        if len(layouts) > 1:
            def variant_filter(layout):
                layout_name, layout_variant = self._split_variant(layout)
                return layout_variant is None
            filtered_layouts = list(filter(variant_filter, layouts))
            logging.debug("Filter by variant: %s", filtered_layouts)
            if len(filtered_layouts) > 0:
                layouts = filtered_layouts
        if len(layouts) > 1:
            def country_filter(layout):
                layout_name, layout_variant = self._split_variant(layout)
                return layout_variant == country.lower()
            filtered_layouts = list(filter(country_filter, layouts))
            logging.debug("Filter by country %s: %s", country,
                          filtered_layouts)
            if len(filtered_layouts) > 0:
                layouts = filtered_layouts
        if len(layouts) > 1:
            def language_filter(layout):
                layout_name, layout_variant = self._split_variant(layout)
                return layout_variant == language
            filtered_layouts = list(filter(language_filter, layouts))
            logging.debug("Filter by language %s: %s", language,
                          filtered_layouts)
            if len(filtered_layouts) > 0:
                layouts = filtered_layouts
        return layouts

    def on_language_changed(self, locale: str):
        """Set the keyboard layout according to the new language"""

        # Don't overwrite a user chosen value
        if self.value_changed_by_user:
            return

        language = language_from_locale(locale)
        country = country_from_locale(locale)

        # First, build a list of layouts to consider for the language
        language_layouts = self._layouts_for_language(language)
        logging.debug("Language %s layouts: %s", language, language_layouts)
        country_layouts = self._layouts_for_country(country)
        logging.debug("Country %s layouts: %s", country, country_layouts)
        layouts = set(language_layouts).intersection(country_layouts)
        logging.debug("Intersection of language %s and country %s: %s",
                      language, country, layouts)

        if not layouts:
            layouts = set(l for l in language_layouts if self._split_variant(l)[0] == country.lower)
            logging.debug("Empty intersection of language and country, filter "
                          "by country %s only: %s", country, layouts)
        if not layouts:
            layouts = set(l for l in language_layouts if self._split_variant(l)[0] == language)
            logging.debug("List still empty, filter by language %s only: %s",
                          language, layouts)
        if not layouts:
            layouts = language_layouts
            logging.debug("List still empty, use all language %s layouts: %s",
                          language, layouts)

        # Then, filter the list
        layouts = self._filter_layouts(layouts, country, language)
        if len(layouts) != 1:
            # Can't find a single result, build a new list for the country
            layouts = country_layouts
            logging.debug("Still not 1 layouts. Try again using all country "
                          "%s layouts: %s", country, layouts)
            layouts = self._filter_layouts(layouts, country, language)
        if len(layouts) == 1:
            default_layout = layouts.pop()
            logging.debug("Selecting single matching layout %s",
                          default_layout)
        elif len(layouts) > 1:
            default_layout = layouts.pop()
            logging.debug("No good layout, arbitrary using layout %s",
                          default_layout)
        else:
            default_layout = 'us'
            logging.debug("Using us as fallback default layout")
        self.set_value(default_layout)

    def _apply_layout_to_current_screen(self):
        layout = self.get_value()
        logging.debug("layout=%s", layout)

        settings = Gio.Settings('org.gnome.desktop.input-sources')
        settings.set_value('sources', GLib.Variant('a(ss)', [('xkb', layout)]))
