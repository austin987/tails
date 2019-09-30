# -*- coding: utf-8 -*-
#
# Copyright 2012-2016 Tails developers <tails@boum.org>
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
#
"""Localization handling

"""

import logging
import gettext
import os
import locale

import gi
import pycountry
import pytz

gi.require_version('Gio', '2.0')
from gi.repository import Gio                       # NOQA: E402
gi.require_version('GLib', '2.0')
from gi.repository import GLib                      # NOQA: E402
gi.require_version('GObject', '2.0')
from gi.repository import GObject                   # NOQA: E402
gi.require_version('GnomeDesktop', '3.0')
from gi.repository import GnomeDesktop              # NOQA: E402
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk                       # NOQA: E402
gi.require_version('AccountsService', '1.0')
from gi.repository import AccountsService           # NOQA: E402

import tailsgreeter.config                          # NOQA: E402

from tailsgreeter import TRANSLATION_DOMAIN


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


class TranslatableWindow(object):
    """Interface providing functions to translate a window on the fly
    """
    retain_focus = True
    registered_windows = []

    def __init__(self, window):
        self.window = window
        self.translation = gettext.translation(
            TRANSLATION_DOMAIN,
            tailsgreeter.config.locales_path,
            fallback=True
        )

        self.containers = []
        self.labels = {}
        self.placeholder_texts = {}
        self.titles = {}
        self.tooltips = {}

        TranslatableWindow.registered_windows.append(window)

    @staticmethod
    def get_locale_direction(lang):
        """Return Gtk.TextDirection for lang

        This method in basically the same as Gtk.get_locale_direction
        (gtk_get_locale_direction in gtk/gtkmain.c), but it accepts a lang
        parameter rather than using current locale.
        """
        gtk_translation = gettext.translation("gtk30",
                                              languages=[str(lang)],
                                              fallback=True)
        logging.debug("%s has GTK translation: %s" % (lang, gtk_translation))
        # Translators: please do not translate this string (it is read from
        # Gtk translation)
        default_dir = gtk_translation.gettext("default:LTR")
        logging.debug("translation for direction is %s" % (default_dir))
        if default_dir == "default:RTL":
            logging.debug("%s is RTL" % lang)
            return Gtk.TextDirection.RTL
        else:
            return Gtk.TextDirection.LTR

    def store_translations(self, widget):
        """Store the elements that should be localised inside widget

        Go through all children of widget and store the translations
        of labels, tooltips and titles and the containers whose text direction
        should be updated when switching between LTR and RTL.

        This method should be called once the widgets are created"""
        if not isinstance(widget, Gtk.Widget):
            logging.debug("%s is not a Gtk.Widget" % widget)
            return None
        if isinstance(widget, Gtk.Label) or isinstance(widget, Gtk.Button):
            if widget not in self.labels:
                self.labels[widget] = widget.get_label()
                # Wrap set_label to get notified about string changes
                widget.original_set_label = widget.set_label

                def wrapped_set_label(text):
                    self.labels[widget] = text
                    widget.original_set_label(self.gettext(text))
                widget.set_label = wrapped_set_label
        elif isinstance(widget, Gtk.Entry):
            if widget not in self.placeholder_texts:
                self.placeholder_texts[widget] = widget.get_placeholder_text()
        elif isinstance(widget, Gtk.Container):
            self.containers.append(widget)
            if ((isinstance(widget, Gtk.HeaderBar) or
                    isinstance(widget, Gtk.Window)) and
                    widget not in self.titles and
                    widget.get_title()):
                self.titles[widget] = widget.get_title()
            for child in widget.get_children():
                self.store_translations(child)
        else:
            logging.debug("W: unhandled widget: %s" % widget)
        if widget.get_has_tooltip():
            if widget not in self.tooltips:
                self.tooltips[widget] = widget.get_tooltip_text()

    def gettext(self, text):
        """Return text, translated if possible"""
        if self.translation and text:
            text = self.translation.gettext(text)
        return text

    def translate_to(self, lang):
        """Translate registered widgets on the fly

        Loop through widgets registered with store_translations and translate
        them on the fly"""
        logging.debug("translating %s to %s" % (self, lang))
        try:
            self.translation = gettext.translation(
                    TRANSLATION_DOMAIN,
                    tailsgreeter.config.locales_path, [str(lang)])
        except IOError:
            self.translation = None

        text_direction = self.get_locale_direction(lang)
        for container in self.containers:
            container.set_default_direction(text_direction)
        for widget, label in self.labels.items():
            if label:
                widget.original_set_label(self.gettext(label))
        for widget in self.placeholder_texts.keys():
            widget.set_placeholder_text(self.gettext(self.placeholder_texts[widget]))
        for widget in self.titles.keys():
            widget.set_title(self.gettext(self.titles[widget]))
        for widget in self.tooltips.keys():
            widget.set_tooltip_markup(self.gettext(self.tooltips[widget]))
        if (self.window.get_sensitive() and
                self.window.get_visible() and
                self.retain_focus):
            self.window.present()

    @staticmethod
    def translate_all(lang):
        for widget in TranslatableWindow.registered_windows:
            widget.translate_to(lang)


class RegionSetting(GObject.Object):

    value = GObject.property(type=str)
    is_default = GObject.property(type=bool, default=True)

    def __init__(self, settings_object):
        super().__init__()
        self._settings = settings_object

    def get_value(self):
        return self.value

    # is_default will be used by subclasses to register default value
    def set_value(self, value, is_default=False):
        self.value = value
        if not is_default:
            self.is_default = False
        self._settings._apply_settings_to_upcoming_session()

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


class TextSetting(RegionSetting):

    def __init__(self, settings_object):
        super().__init__(settings_object)
        super().set_value('en_US', is_default=True)

    def get_tree(self, locale_codes=None):
        if not locale_codes:
            locale_codes = self._settings._system_locales_list

        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        lang_codes = languages_from_locales(
                self._settings._system_locales_list)
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
        self._settings.layout.set_default_if_needed()   # XXX: notify
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


class FormatSetting(RegionSetting):
    def __init__(self, settings_object):
        super().__init__(settings_object)
        super().set_value('en_US', is_default=True)

    def get_tree(self, format_codes=None):
        if not format_codes:
            format_codes = self._settings._system_locales_list

        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name

        format_codes = countries_from_locales(
            self._settings._system_locales_list)
        format_codes.sort(key=lambda x: self._country_name(x).lower())
        logging.debug("format_codes=%s" % format_codes)
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
        if country_code in self._settings._system_formats_dict:
            return self._settings._system_formats_dict[country_code]

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
        default_format = self._settings.text.get_value()
        logging.debug("setting default formats to %s" % default_format)
        self.set_value(default_format, is_default=True)


class LayoutSetting(RegionSetting):

    def __init__(self, settings_object):
        super().__init__(settings_object)
        super().set_value('en+us', is_default=True)
        self.__xklinfo = GnomeDesktop.XkbInfo()

    def get_tree(self, layout_codes=None):
        if not layout_codes:
            layout_codes = self.get_all()

        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name
        layouts = self._layouts_split_names(layout_codes)
        for group_name in sorted(layouts.keys()):
            layout_codes = sorted(
                    layouts[group_name],
                    key=lambda x: self._layout_name(x).lower())
            treeiter_group = treestore.append(parent=None)
            # we fill the title with the 1st layout of the group
            treestore.set(treeiter_group, 0, layout_codes[0])
            treestore.set(treeiter_group, 1, group_name)
            if len(layout_codes) > 1:
                for layout_code in layout_codes:
                    treeiter_layout = treestore.append(parent=treeiter_group)
                    treestore.set(treeiter_layout, 0, layout_code)
                    treestore.set(treeiter_layout, 1,
                                  self._layout_name(layout_code))
        return treestore

    def get_name(self):
        return self._layout_name(self.get_value())

    def get_all(self):
        """Return a list of all keyboard layout codes

        """
        return self.__xklinfo.get_all_layouts()

    def get_defaults(self):
        """Return list of supported keyboard layouts for current language

        """
        lang_code = language_from_locale(self._settings.text.get_value())
        layouts = self._layouts_for_language(lang_code)
        if not layouts:
            country_code = country_from_locale(self._settings.text.get_value())
            layouts = self._layouts_for_country(country_code)
        if not layouts:
            layouts = ['us']
        return layouts

    def set_value(self, layout, is_default=False):
        super().set_value(layout, is_default)
        self._apply_layout_to_current_screen()

    def _layout_name(self, layout_code):
        id, display_name, short_name, xkb_layout, xkb_variant = \
                self.__xklinfo.get_layout_info(layout_code)
        return display_name

    def _layouts_split_names(self, layout_codes):
        layouts_names = {}
        for layout_code in layout_codes:
            layout_name = self._layout_name(layout_code)
            country_name, s, v = layout_name.partition(' (')
            if country_name not in layouts_names:
                layouts_names[country_name] = set([layout_code])
            else:
                layouts_names[country_name].add(layout_code)
        return layouts_names

    def _layouts_for_language(self, lang_code):
        """Return the list of available layouts for given language
        """
        layouts = []
        try:
            t_code = ln_iso639_tri(lang_code)
        except KeyError:
            t_code = lang_code
        if t_code == 'nno' or t_code == 'nob':
            t_code = 'nor'

        layouts = self.__xklinfo.get_layouts_for_language(t_code)

        if t_code == 'hrv':
            layouts.append('hr')

        if len(layouts) == 0:
            b_code = ln_iso639_2_T_to_B(t_code)
            logging.debug(
                "got no layout for ISO-639-2/T code %s, "
                "trying with ISO-639-2/B code %s",
                t_code, b_code)

            layouts = self.__xklinfo.get_layouts_for_language(b_code)

        logging.debug('got %d layouts for %s', len(layouts), lang_code)
        return layouts

    def _layouts_for_country(self, country):
        """Return the list of available layouts for given country
        """
        # XXX: it would be logical to use:
        #     self.__xklinfo.get_layouts_for_language(country)
        # but it doesn't actually return the list of all layouts matching a
        # country.
        def country_filter(layout):
            cc = country.lower()
            return ((layout == cc)
                    or ('+' in layout) and (layout.split('+')[0] == cc))

        layouts = list(filter(country_filter, self.get_all()))

        logging.debug('got %d layouts for %s', len(layouts), country)
        return layouts

    @staticmethod
    def _split_variant(layout_code):
        if '+' in layout_code:
            return layout_code.split('+')
        else:
            return (layout_code, None)

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

    def set_default(self):
        """Sets the best default layout for the current locale
        """
        default_layout = False

        language = language_from_locale(self._settings.text.get_value())
        country = country_from_locale(self._settings.text.get_value())

        # First, build a list of layouts to consider for the language
        language_layouts = self._layouts_for_language(language)
        logging.debug("Language %s layouts: %s", language, language_layouts)
        country_layouts = self._layouts_for_country(country)
        logging.debug("Country %s layouts: %s", country, country_layouts)
        layouts = set(language_layouts).intersection(country_layouts)
        logging.debug("Intersection of language %s and country %s: %s",
                      language, country, layouts)
        if not len(layouts) > 0:
            def country_filter(layout):
                layout_name, layout_variant = self._split_variant(layout)
                return layout_name == country.lower()
            layouts = list(filter(country_filter, language_layouts))
            logging.debug("Empty intersection of language and country, filter "
                          "by country %s only: %s", country, layouts)
        if not len(layouts) > 0:
            def language_filter(layout):
                layout_name, layout_variant = self._split_variant(layout)
                return layout_name == language
            layouts = list(filter(language_filter, language_layouts))
            logging.debug("List still empty, filter by language %s only: %s",
                          language, layouts)
        if not len(layouts) > 0:
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
        self.set_value(default_layout, is_default=True)

    def _apply_layout_to_current_screen(self):
        layout = self.get_value()
        logging.debug("layout=%s" % layout)

        settings = Gio.Settings('org.gnome.desktop.input-sources')
        settings.set_value('sources', GLib.Variant('a(ss)', [('xkb', layout)]))


class TimezoneSetting(RegionSetting):

    def get_tree(self):
        timezones = self.get_all()
        treestore = Gtk.TreeStore(GObject.TYPE_STRING,  # id
                                  GObject.TYPE_STRING)  # name
        areas = self._timezone_split_area(timezones)
        for area in sorted(areas.keys()):
            locations = sorted(
                    areas[area],
                    key=lambda x: self._timezone_name(x).lower())
            treeiter_area = treestore.append(parent=None)
            # we fill the title with the 1st layout of the group
            treestore.set(treeiter_area, 0, locations[0])
            treestore.set(treeiter_area, 1, area)
            if len(locations) > 1:
                for location in locations:
                    treeiter_location = treestore.append(parent=treeiter_area)
                    treestore.set(treeiter_location, 0, location)
                    treestore.set(treeiter_location, 1,
                                  self._timezone_name(location))
        return treestore

    def get_name(self):
        return self._timezone_name(self.get_value())

    def get_all(self):
        """Return a list of all timezones

        """
        return pytz.common_timezones

    def _timezone_name(self, timezone):
        if '/' in timezone:
            area, s, location = timezone.partition('/')
            return location
        else:
            return timezone

    def _timezone_split_area(self, timezones):
        timezone_areas = {}
        for timezone in timezones:
            area, s, v = timezone.partition('/')
            if area not in timezone_areas:
                timezone_areas[area] = set([timezone])
            else:
                timezone_areas[area].add(timezone)
        return timezone_areas


class LocalisationSettings(object):
    """Controller for localisation settings

    """
    def __init__(self, usermanager_loaded_cb=None, locale_selected_cb=None):
        self._usermanager_loaded_cb = usermanager_loaded_cb
        self._locale_selected_cb = locale_selected_cb

        self._act_user = None
        self.__actusermanager_loadedid = None

        self._system_locales_list = self.__get_langcodes()
        self._system_languages_dict = self.__fill_languages_dict(
                self._system_locales_list)
        self._system_formats_dict = self.__fill_formats_dict(
                self._system_locales_list)

        actusermanager = AccountsService.UserManager.get_default()
        self.__actusermanager_loadedid = actusermanager.connect(
            "notify::is-loaded",  self.__on_usermanager_loaded)

        self.text = TextSetting(self)
        self.formats = FormatSetting(self)
        self.layout = LayoutSetting(self)
        self.timezone = TimezoneSetting(self)

    def __del__(self):
        if self.__actusermanager_loadedid:
            self.__actusermanager.disconnect(self.__actusermanager_loadedid)

    def __get_langcodes(self):
        with open(tailsgreeter.config.default_langcodes_path, 'r') as f:
            defcodes = [line.rstrip('\n') for line in f.readlines()]
        with open(tailsgreeter.config.language_codes_path, 'r') as f:
            langcodes = [line.rstrip('\n') for line in f.readlines()]
        logging.debug('%s languages found', len(langcodes))
        return defcodes + langcodes

    def __on_usermanager_loaded(self, manager, pspec, data=None):
        logging.debug("Received AccountsManager signal is-loaded")
        act_user = manager.get_user(tailsgreeter.config.LUSER)
        if not act_user.is_loaded():
            raise RuntimeError("User manager for %s not loaded"
                               % tailsgreeter.config.LUSER)
        self._act_user = act_user
        if self._usermanager_loaded_cb:
            self._usermanager_loaded_cb()

    def __fill_languages_dict(self, locale_codes):
        """assemble dictionary of language codes to corresponding locales list

        example {en: [en_US, en_GB], ...}"""
        languages_dict = {}
        for locale_code in locale_codes:
            lang_code = language_from_locale(locale_code)
            if lang_code not in languages_dict:
                languages_dict[lang_code] = []
            if locale_code not in languages_dict[lang_code]:
                languages_dict[lang_code].append(locale_code)
        return languages_dict

    def __fill_formats_dict(self, locale_codes):
        """assemble dictionary of country codes to corresponding locales list

        example {FR: [fr_FR, en_FR], ...}"""
        formats_dict = {}
        for locale_code in locale_codes:
            country_code = country_from_locale(locale_code)
            if country_code not in formats_dict:
                formats_dict[country_code] = []
            if locale_code not in formats_dict[country_code]:
                formats_dict[country_code].append(locale_code)
        return formats_dict

    def _apply_settings_to_upcoming_session(self):
        with open(tailsgreeter.config.locale_output_path, 'w') as f:
            os.chmod(tailsgreeter.config.locale_output_path, 0o600)
            if hasattr(self, "text"):
                f.write('TAILS_LOCALE_NAME=%s\n' % self.text.get_value())
            if hasattr(self, "formats"):
                f.write('TAILS_FORMATS=%s\n' % self.formats.get_value())
            if hasattr(self, "layout"):
                try:
                    layout, variant = self.layout.get_value().split('+')
                except ValueError:
                    layout = self.layout.get_value()
                    variant = ''
                # XXX: use default value from /etc/default/keyboard
                f.write('TAILS_XKBMODEL=%s\n' % 'pc105')
                f.write('TAILS_XKBLAYOUT=%s\n' % layout)
                f.write('TAILS_XKBVARIANT=%s\n' % variant)
