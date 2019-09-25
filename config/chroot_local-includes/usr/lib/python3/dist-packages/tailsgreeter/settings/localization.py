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
import pycountry
from typing import TYPE_CHECKING

gi.require_version('GObject', '2.0')
from gi.repository import GObject

if TYPE_CHECKING:
    from tailsgreeter.settings.localization_settings import LocalisationSettings


class LocalizationSetting(GObject.Object):

    value = GObject.property(type=str)
    is_default = GObject.property(type=bool, default=True)

    def __init__(self, settings_object: "LocalisationSettings"):
        super().__init__()
        self._settings = settings_object

    def get_value(self):
        return self.value

    # is_default will be used by subclasses to register default value
    def set_value(self, value, is_default=False):
        self.value = value
        if not is_default:
            self.is_default = False
        self._settings.apply_settings_to_upcoming_session()

    def get_name(self):
        raise NotImplementedError

    def get_tree(self):
        raise NotImplementedError

    def set_default(self):
        raise NotImplementedError

    def set_default_if_needed(self):
        """Update default value if it was not user choosen"""
        if self.is_default:
            self.set_default()


def ln_iso639_tri(ln_CC):
    """get iso639 3-letter code from a language code

    example: en -> eng"""
    return pycountry.languages.get(
            alpha2=language_from_locale(ln_CC)).terminology


def ln_iso639_2_T_to_B(lng):
    """Convert a ISO-639-2/T code (e.g. deu for German) to a 639-2/B one
    (e.g. ger for German)"""
    return pycountry.languages.get(terminology=lng).bibliographic


def language_from_locale(locale):
    """Obtain the language code from a locale code

    example: fr_FR -> fr"""
    return locale.split('_')[0]


def languages_from_locales(locales):
    """Obtain a language code list from a locale code list

    example: [fr_FR, en_GB] -> [fr, en]"""
    language_codes = []
    for l in locales:
        language_code = language_from_locale(l)
        if language_code not in language_codes:
            language_codes.append(language_code)
    return language_codes


def country_from_locale(locale):
    """Obtain the country code from a locale code

    example: fr_FR -> FR"""
    return locale.split('_')[1]


def countries_from_locales(locales):
    """Obtain a country code list from a locale code list

    example: [fr_FR, en_GB] -> [FR, GB]"""
    country_codes = []
    for l in locales:
        country_code = country_from_locale(l)
        if country_code not in country_codes:
            country_codes.append(country_code)
    return country_codes
