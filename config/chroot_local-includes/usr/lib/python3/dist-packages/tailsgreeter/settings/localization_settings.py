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
    def __init__(self, usermanager_loaded_cb: Callable):
        self._usermanager_loaded_cb = usermanager_loaded_cb

        self._user_account = None
        self._actusermanager_loadedid = None

        locales = self._get_locales()

        self._actusermanager = AccountsService.UserManager.get_default()
        self._actusermanager_loadedid = self._actusermanager.connect(
            "notify::is-loaded",  self.__on_usermanager_loaded)

        self.language = LanguageSetting(locales)
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
