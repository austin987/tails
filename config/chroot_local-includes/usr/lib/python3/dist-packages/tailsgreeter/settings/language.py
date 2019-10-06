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

from collections import OrderedDict
import gi
import logging
import locale
from typing import Callable

from tailsgreeter.settings.localization import LocalizationSetting, \
    language_from_locale, country_from_locale

gi.require_version('GLib', '2.0')
gi.require_version('GObject', '2.0')
gi.require_version('GnomeDesktop', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GLib, GObject, GnomeDesktop, Gtk


class LanguageSetting(LocalizationSetting):

    def __init__(self, locales: [str], language_changed_cb: Callable):
        super().__init__()
        self.value = 'en_US'
        self.locales = locales
        self.language_changed_cb = language_changed_cb
        self._user_account = None

        self.lang_codes = self._languages_from_locales(locales)
        self.locales_per_language = self._make_language_to_locale_dict(locales)
        self.language_names_per_language = self._make_language_to_language_name_dict(self.lang_codes)

    def get_tree(self) -> Gtk.TreeStore:
        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        for lang_code, language_name in self.language_names_per_language.items():
            print("%s: %s" % (lang_code, language_name))
            language_name = self._language_name(lang_code)
            if not language_name:
                # Don't display languages without a name
                continue
            treeiter_language = treestore.append(parent=None)
            treestore.set(treeiter_language, 0, self.get_default_locale(lang_code))
            treestore.set(treeiter_language, 1, language_name)
            locales = sorted(self.locales_per_language[lang_code],
                             key=lambda x: self._locale_name(x).lower())
            if len(locales) > 1:
                for locale_code in locales:
                    treeiter_locale = treestore.append(parent=treeiter_language)
                    treestore.set(treeiter_locale, 0, locale_code)
                    treestore.set(treeiter_locale, 1, self._locale_name(locale_code))
        return treestore

    def get_name(self) -> str:
        return self._locale_name(self.get_value())

    def get_default_locale(self, lang_code: str) -> str:
        """Try to find a default locale for the given language

        Returns the 1st locale among:
            - the locale whose country name matches language name
            - the 1st locale for the language
            - en_US
        """
        locales = self.locales_per_language[lang_code]
        if not locales:
            return 'en_US'

        for locale_code in locales:
            if (country_from_locale(locale_code).lower() ==
                    self._language_from_locale(locale_code)):
                return locale_code

        return locales[0]

    def set_value(self, locale_code: str, chosen_by_user=False):
        super().set_value(locale_code, chosen_by_user)
        self._apply_language(locale_code)
        self.language_changed_cb(locale_code)

    def _language_name(self, lang_code: str) -> str:
        default_locale = 'C'

        if lang_code in ("zhs", "zht"):
            custom_lang_code = lang_code
            lang_code = "zh"
            local_locale = "zh_CN" if custom_lang_code == "zhs" else "zh_TW"
        else:
            custom_lang_code = None
            local_locale = self.get_default_locale(lang_code)

        try:
            native_name = GnomeDesktop.get_language_from_code(
                    lang_code, local_locale).capitalize()
        except AttributeError:
            return ""
        localized_name = GnomeDesktop.get_language_from_code(
                lang_code, default_locale).capitalize()

        if custom_lang_code:
            if custom_lang_code == "zhs":
                localized_name = "Chinese, simplified"
            else:
                localized_name = "Chinese, traditional"

        if native_name == localized_name:
            return native_name
        else:
            return "{native} ({localized})".format(
                    native=native_name, localized=localized_name)

    def _locale_name(self, locale_code: str) -> str:
        lang_code = self._language_from_locale(locale_code)

        if lang_code in ("zhs", "zht"):
            custom_lang_code = lang_code
            lang_code = "zh"
        else:
            custom_lang_code = None

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

            if custom_lang_code:
                if custom_lang_code == "zhs":
                    country_name_locale = "simplified, " + country_name_locale
                else:
                    country_name_locale = "traditional, " + country_name_locale

            return "{language} - {country} " \
                   "({local_language} - {local_country})".format(
                    language=language_name_native.capitalize(),
                    country=country_name_native,
                    local_language=language_name_locale.capitalize(),
                    local_country=country_name_locale)
        except AttributeError:
            return locale_code

    def _apply_language(self, language_code: str):
        normalized_code = locale.normalize(language_code + '.' + locale.getpreferredencoding())
        logging.debug("Setting session language to %s", normalized_code)
        if self._user_account:
            # For some reason, this produces the following warning, but
            # the language is actually applied.
            #     AccountsService-WARNING **: 19:29:39.181: SetLanguage for language de_DE.UTF-8 failed:
            #     GDBus.Error:org.freedesktop.Accounts.Error.PermissionDenied: Not authorized
            GLib.idle_add(lambda: self._user_account.set_language(normalized_code))
        else:
            logging.warning("AccountsManager not ready")

    def _make_language_to_locale_dict(self, locale_codes: [str]) -> {str: str}:
        """assemble dictionary of language codes to corresponding locales list

        example {en: [en_US, en_GB], ...}"""
        languages_dict = {}
        for locale_code in locale_codes:
            lang_code = self._language_from_locale(locale_code)
            if lang_code not in languages_dict:
                languages_dict[lang_code] = []
            if locale_code not in languages_dict[lang_code]:
                languages_dict[lang_code].append(locale_code)
        return languages_dict

    def _make_language_to_language_name_dict(self, lang_codes: [str]) -> {str: str}:
        """assemble dictionary of language code to corresponding language name,
         sorted by the language name.

        example: {"en": "English", "it": "Italiano (Italian)", ...}"""
        dict_ = {lang_code: self._language_name(lang_code) for lang_code in lang_codes}
        # Sort the dictionary
        sorted_keys = sorted(dict_.keys(), key=lambda x: dict_[x].lower())
        return OrderedDict([(key, dict_[key]) for key in sorted_keys])

    def _language_from_locale(self, locale_code: str) -> str:
        lang_code = language_from_locale(locale_code)
        if lang_code != "zh":
            return lang_code

        # We treat Chinese differently to have simplified and traditional
        # Chinese in separate groups
        if locale_code in ("zh_CN", "zh_SG"):
            # Our own "language code" for simplified Chinese
            return "zhs"
        if locale_code in ("zh_HK", "zh_TW"):
            # Our own "language code" for traditional Chinese
            return "zht"
        return lang_code

    def _languages_from_locales(self, locale_codes: [str]) -> [str]:
        """Obtain a language code list from a locale code list

        example: [fr_FR, en_GB] -> [fr, en]"""
        return list({self._language_from_locale(l) for l in locale_codes})
