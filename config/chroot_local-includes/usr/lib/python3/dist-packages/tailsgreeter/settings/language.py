# -*- coding: utf-8 -*-
#
# Copyright 2012-2019 Tails developers <tails@boum.org>
# Copyright 2011 Max <govnototalitarizm@gmail.com>
# Copyright 2011 Martin Owens
#
# This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>

import gi
import logging
import locale

from tailsgreeter.settings.localization import LocalizationSetting, \
    language_from_locale, languages_from_locales, country_from_locale

gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')
gi.require_version('GnomeDesktop', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GLib, GObject, GnomeDesktop, Gtk


class LanguageSetting(LocalizationSetting):

    def __init__(self, settings_object):
        super().__init__(settings_object)
        super().set_value('en_US', is_default=True)

    def get_tree(self):
        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        lang_codes = languages_from_locales(
                self._settings.system_locales_list)
        lang_codes.sort(key=lambda x: self._language_name(x).lower())
        for lang_code in lang_codes:
            language_name = self._language_name(lang_code)
            if not language_name:
                # Don't display languages without a name
                continue
            treeiter_language = treestore.append(parent=None)
            treestore.set(treeiter_language,
                          0, self.get_default_locale(lang_code))
            treestore.set(treeiter_language, 1, language_name)
            locale_codes = sorted(
                    self.get_default_locales(lang_code),
                    key=lambda x: self._locale_name(x).lower())
            if len(locale_codes) > 1:
                for locale_code in locale_codes:
                    treeiter_locale = treestore.append(
                            parent=treeiter_language)
                    treestore.set(treeiter_locale, 0, locale_code)
                    treestore.set(treeiter_locale, 1,
                                  self._locale_name(locale_code))
        return treestore

    def get_name(self):
        return self._locale_name(self.get_value())

    def get_default_locales(self, lang_code):
        """Return available locales for given language

        """
        if lang_code in self._settings._system_languages_dict:
            return self._settings._system_languages_dict[lang_code]

    def get_default_locale(self, lang_code=None):
        """Return default locale for given language

        Returns the 1st locale among:
            - the locale whose country name matches language name
            - the 1st locale for the language
            - en_US
        """
        default_locales = self.get_default_locales(lang_code)
        if default_locales:
            for locale_code in default_locales:
                if (country_from_locale(locale_code).lower() ==
                        language_from_locale(locale_code)):
                    return locale_code
            return default_locales[0]
        else:
            return 'en_US'

    def set_value(self, locale, is_default=False):
        super().set_value(locale, is_default)
        self.__apply_locale()
        self._settings.formats.set_default_if_needed()  # XXX: notify
        self._settings.keyboard.set_default_if_needed()   # XXX: notify
        if self._settings._locale_selected_cb:
            self._settings._locale_selected_cb(locale)

    def _language_name(self, lang_code):
        default_locale = 'C'
        local_locale = self.get_default_locale(lang_code)
        try:
            native_name = GnomeDesktop.get_language_from_code(
                    lang_code, local_locale).capitalize()
        except AttributeError:
            return ""
        localized_name = GnomeDesktop.get_language_from_code(
                lang_code, default_locale).capitalize()
        if native_name == localized_name:
            return native_name
        else:
            return "{native} ({localized})".format(
                    native=native_name, localized=localized_name)

    def _locale_name(self, locale_code):
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
                return "{language} - {country}".format(
                        language=language_name_native.capitalize(),
                        country=country_name_native)
            else:
                return "{language} - {country} " \
                       "({local_language} - {local_country})".format(
                        language=language_name_native.capitalize(),
                        country=country_name_native,
                        local_language=language_name_locale.capitalize(),
                        local_country=country_name_locale)
        except AttributeError:
            return locale_code

    def __apply_locale(self):
        locale_code = locale.normalize(
            self.get_value() + '.' + locale.getpreferredencoding())
        logging.debug("Setting session language to %s", locale_code)
        if self._settings._act_user:
            GLib.idle_add(
                lambda: self._settings._act_user.set_language(locale_code))
        else:
            logging.warning("AccountsManager not ready")
