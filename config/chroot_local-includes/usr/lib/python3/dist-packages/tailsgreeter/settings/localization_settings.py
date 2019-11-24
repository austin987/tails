import gi
import logging
import os
from typing import Callable

import tailsgreeter.config
from tailsgreeter.settings.formats import FormatsSetting
from tailsgreeter.settings.keyboard import KeyboardSetting
from tailsgreeter.settings.language import LanguageSetting

gi.require_version('AccountsService', '1.0')
from gi.repository import AccountsService


class LocalisationSettings(object):
    """Controller for localisation settings

    """
    def __init__(self, usermanager_loaded_cb: Callable, locale_selected_cb: Callable):
        self._usermanager_loaded_cb = usermanager_loaded_cb

        self._user_account = None
        self._actusermanager_loadedid = None

        locales = self._get_locales()

        self._actusermanager = AccountsService.UserManager.get_default()
        self._actusermanager_loadedid = self._actusermanager.connect(
            "notify::is-loaded",  self.__on_usermanager_loaded)

        self.language = LanguageSetting(locales, locale_selected_cb)
        self.keyboard = KeyboardSetting()
        self.formats = FormatsSetting(locales)

    def __del__(self):
        if self._actusermanager_loadedid:
            self._actusermanager.disconnect(self._actusermanager_loadedid)

    @staticmethod
    def _get_locales() -> [str]:
        with open(tailsgreeter.config.supported_locales_path, 'r') as f:
            return [line.rstrip('\n') for line in f.readlines()]

    def __on_usermanager_loaded(self, manager, pspec, data=None):
        logging.debug("Received AccountsManager signal is-loaded")
        user_account = manager.get_user(tailsgreeter.config.LUSER)
        if not user_account.is_loaded():
            raise RuntimeError("User manager for %s not loaded"
                               % tailsgreeter.config.LUSER)
        self.language._user_account = user_account

        if self._usermanager_loaded_cb:
            self._usermanager_loaded_cb()

    def apply_to_upcoming_session(self):
        with open(tailsgreeter.config.locale_output_path, 'w') as f:
            os.chmod(tailsgreeter.config.locale_output_path, 0o600)

            f.write('TAILS_LOCALE_NAME=%s\n' % self.language.get_value())
            f.write('TAILS_FORMATS=%s\n' % self.formats.get_value())

            try:
                layout, variant = self.keyboard.get_value().split('+')
            except ValueError:
                layout = self.keyboard.get_value()
                variant = ''
            # XXX: use default value from /etc/default/keyboard
            f.write('TAILS_XKBMODEL=%s\n' % 'pc105')
            f.write('TAILS_XKBLAYOUT=%s\n' % layout)
            f.write('TAILS_XKBVARIANT=%s\n' % variant)
