import logging

import gi

from tailsgreeter.settings.localization import LocalizationSetting, language_from_locale, country_from_locale

gi.require_version('GObject', '2.0')
gi.require_version('GnomeDesktop', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GObject, GnomeDesktop, Gtk


class FormatsSetting(LocalizationSetting):
    def __init__(self, language_codes: [str]):
        super().__init__()
        self.value = 'en_US'
        self.locales_per_country = self._make_locales_per_country_dict(language_codes)

    def get_tree(self) -> Gtk.TreeStore:
        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        country_codes = list(self.locales_per_country.keys())
        country_codes.sort(key=lambda x: self._country_name(x).lower())
        logging.debug("format_codes=%s", country_codes)
        for country_code in country_codes:
            country_name = self._country_name(country_code)
            if not country_name:
                # Don't display languages without a name
                continue

            treeiter_format = treestore.append(parent=None)
            treestore.set(treeiter_format, 0, self.get_default_locale(country_code))
            treestore.set(treeiter_format, 1, country_name)
            locales = sorted(self.locales_per_country[country_code],
                             key=lambda x: self._locale_name(x).lower())
            if len(locales) > 1:
                for locale in locales:
                    treeiter_locale = treestore.append(parent=treeiter_format)
                    treestore.set(treeiter_locale, 0, locale)
                    treestore.set(treeiter_locale, 1, self._locale_name(locale))
        return treestore

    def get_name(self) -> str:
        return self._locale_name(self.get_value())

    def get_default_locale(self, country_code=None) -> str:
        """Return default locale for given country

        Returns the 1st locale among:
            - the locale whose country name matches country name
            - the 1st locale for the language
            - en_US
        """
        locales = self.locales_per_country[country_code]
        if not locales:
            return 'en_US'

        # Get the default locale for the country
        for locale_code in locales:
            if country_from_locale(locale_code).lower() == language_from_locale(locale_code):
                return locale_code

        return locales[0]

    def _country_name(self, country_code) -> str:
        default_locale = 'C'
        local_locale = self.get_default_locale(country_code)
        native_name = GnomeDesktop.get_country_from_code(
            country_code, local_locale)
        if not native_name:
            return ""
        localized_name = GnomeDesktop.get_country_from_code(
            country_code, default_locale)
        if native_name == localized_name:
            return native_name
        else:
            return "{native} ({localized})".format(
                native=native_name, localized=localized_name)

    @staticmethod
    def _locale_name(locale_code) -> str:
        lang_code = language_from_locale(locale_code)
        country_code = country_from_locale(locale_code)
        language_name_locale = GnomeDesktop.get_language_from_code(lang_code)
        language_name_native = GnomeDesktop.get_language_from_code(
                lang_code, locale_code)
        country_name_locale = GnomeDesktop.get_country_from_code(country_code)
        country_name_native = GnomeDesktop.get_country_from_code(
                country_code, locale_code)
        try:
            if (language_name_native == language_name_locale and
                    country_name_native == country_name_locale):
                return "{country} - {language}".format(
                        language=language_name_native.capitalize(),
                        country=country_name_native)
            else:
                return "{country} - {language} " \
                       "({local_country} - {local_language})".format(
                        language=language_name_native.capitalize(),
                        country=country_name_native,
                        local_language=language_name_locale.capitalize(),
                        local_country=country_name_locale)
        except AttributeError:
            return locale_code

    @staticmethod
    def _make_locales_per_country_dict(language_codes: [str]) -> {str: [str]}:
        """assemble dictionary of country codes to corresponding locales list

        example {FR: [fr_FR, en_FR], ...}"""
        res = {}
        for language_code in language_codes:
            country_code = country_from_locale(language_code)
            if country_code not in res:
                res[country_code] = []
            if language_code not in res[country_code]:
                res[country_code].append(language_code)
        return res

    def on_language_changed(self, language_code: str):
        """Set the formats according to the new language"""
        # Don't overwrite user chosen values
        if self.value_changed_by_user:
            return

        logging.debug("setting formats to %s", language_code)
        self.set_value(language_code)
