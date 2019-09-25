import logging
from typing import TYPE_CHECKING

import gi

from tailsgreeter.settings.localization import LocalizationSetting, language_from_locale, country_from_locale, \
    countries_from_locales

gi.require_version('GObject', '2.0')
gi.require_version('GnomeDesktop', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GObject, GnomeDesktop, Gtk

if TYPE_CHECKING:
    from tailsgreeter.settings.localization_settings import LocalisationSettings


class FormatsSetting(LocalizationSetting):
    def __init__(self, settings_object: "LocalisationSettings"):
        super().__init__(settings_object)
        super().set_value('en_US', is_default=True)

    def get_tree(self):
        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        format_codes = countries_from_locales(
            self._settings.system_locales_list)
        format_codes.sort(key=lambda x: self._country_name(x).lower())
        logging.debug("format_codes=%s", format_codes)
        for format_code in format_codes:
            format_name = self._country_name(format_code)
            if not format_name:
                # Don't display languages without a name
                continue
            treeiter_format = treestore.append(parent=None)
            treestore.set(treeiter_format,
                          0, self.get_default_locale(format_code))
            treestore.set(treeiter_format, 1, format_name)
            locale_codes = sorted(
                    self.get_default_locales(format_code),
                    key=lambda x: self._locale_name(x).lower())
            if len(locale_codes) > 1:
                for locale_code in locale_codes:
                    treeiter_locale = treestore.append(
                            parent=treeiter_format)
                    treestore.set(treeiter_locale, 0, locale_code)
                    treestore.set(treeiter_locale, 1,
                                  self._locale_name(locale_code))
        return treestore

    def get_name(self):
        return self._locale_name(self.get_value())

    def get_default_locales(self, country_code):
        """Return available locales for given country

        """
        if country_code in self._settings.system_formats_dict:
            return self._settings.system_formats_dict[country_code]

    def get_default_locale(self, country_code=None):
        """Return default locale for given country

        Returns the 1st locale among:
            - the locale whose country name matches country name
            - the 1st locale for the language
            - en_US
        """
        default_locales = self.get_default_locales(country_code)
        if default_locales:
            for locale_code in default_locales:
                if (country_from_locale(locale_code).lower() ==
                        language_from_locale(locale_code)):
                    return locale_code
            return default_locales[0]
        else:
            return 'en_US'

    def _country_name(self, country_code):
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
    def _locale_name(locale_code):
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

    def set_default(self):
        """Set default format for current language

        Select the same locale for formats that the language
        """
        default_format = self._settings.language.get_value()
        logging.debug("setting default formats to %s", default_format)
        self.set_value(default_format, is_default=True)
