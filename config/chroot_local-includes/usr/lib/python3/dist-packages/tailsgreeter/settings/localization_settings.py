import gi
import logging
import os

import tailsgreeter.config
from tailsgreeter.settings.localization import language_from_locale, country_from_locale
from tailsgreeter.settings.formats import FormatsSetting
from tailsgreeter.settings.keyboard import KeyboardSetting
from tailsgreeter.settings.language import LanguageSetting

gi.require_version('AccountsService', '1.0')
from gi.repository import AccountsService


class LocalisationSettings(object):
    """Controller for localisation settings

    """
    def __init__(self, usermanager_loaded_cb=None, locale_selected_cb=None):
        self._usermanager_loaded_cb = usermanager_loaded_cb
        self._locale_selected_cb = locale_selected_cb

        self._act_user = None
        self._actusermanager_loadedid = None

        self.system_locales_list = self.__get_langcodes()
        self._system_languages_dict = self.__fill_languages_dict(
                self.system_locales_list)
        self.system_formats_dict = self.__fill_formats_dict(
                self.system_locales_list)

        self._actusermanager = AccountsService.UserManager.get_default()
        self._actusermanager_loadedid = self._actusermanager.connect(
            "notify::is-loaded",  self.__on_usermanager_loaded)

        self.language = LanguageSetting(self)
        self.keyboard = KeyboardSetting(self)
        self.formats = FormatsSetting(self)

    def __del__(self):
        if self._actusermanager_loadedid:
            self._actusermanager.disconnect(self._actusermanager_loadedid)

    @staticmethod
    def __get_langcodes():
        with open(tailsgreeter.config.language_codes_path, 'r') as f:
            return [line.rstrip('\n') for line in f.readlines()]

    def __on_usermanager_loaded(self, manager, pspec, data=None):
        logging.debug("Received AccountsManager signal is-loaded")
        act_user = manager.get_user(tailsgreeter.config.LUSER)
        if not act_user.is_loaded():
            raise RuntimeError("User manager for %s not loaded"
                               % tailsgreeter.config.LUSER)
        self._act_user = act_user
        if self._usermanager_loaded_cb:
            self._usermanager_loaded_cb()

    @staticmethod
    def __fill_languages_dict(locale_codes):
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

    @staticmethod
    def __fill_formats_dict(locale_codes):
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

    def apply_settings_to_upcoming_session(self):
        with open(tailsgreeter.config.locale_output_path, 'w') as f:
            os.chmod(tailsgreeter.config.locale_output_path, 0o600)
            if hasattr(self, "text"):
                f.write('TAILS_LOCALE_NAME=%s\n' % self.language.get_value())
            if hasattr(self, "formats"):
                f.write('TAILS_FORMATS=%s\n' % self.formats.get_value())
            if hasattr(self, "layout"):
                try:
                    layout, variant = self.keyboard.get_value().split('+')
                except ValueError:
                    layout = self.keyboard.get_value()
                    variant = ''
                # XXX: use default value from /etc/default/keyboard
                f.write('TAILS_XKBMODEL=%s\n' % 'pc105')
                f.write('TAILS_XKBLAYOUT=%s\n' % layout)
                f.write('TAILS_XKBVARIANT=%s\n' % variant)
