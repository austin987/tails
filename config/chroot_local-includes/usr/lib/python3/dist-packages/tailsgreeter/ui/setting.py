from typing import TYPE_CHECKING
import gi

from tailsgreeter import TRANSLATION_DOMAIN
import tailsgreeter.config
from tailsgreeter.ui.popover import Popover, Union

if TYPE_CHECKING:
    from tailsgreeter.ui.main_window import GreeterMainWindow

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk


SETTING_UI_FILE = "setting.ui"


class GreeterSetting(object):
    """Base class of all settings in the greeter"""
    @property
    def id(self) -> str:
        return str()

    @property
    def title(self) -> str:
        return str()

    @property
    def icon_name(self) -> str:
        return str()

    @property
    def value_for_display(self) -> str:
        return str()

    def __init__(self):
        self.accel_key = None
        self.popover = None  # type: Union[None, Popover]
        self.main_window = None  # type:  Union[None, GreeterMainWindow]

        self.builder = Gtk.Builder()
        self.builder.set_translation_domain(TRANSLATION_DOMAIN)
        self.builder.add_from_file((tailsgreeter.config.data_path + SETTING_UI_FILE))
        self.listboxrow = self.builder.get_object("listboxrow")  # type: Gtk.ListBoxRow
        image = self.builder.get_object("image")  # type: Gtk.Image
        image.set_from_icon_name(self.icon_name, Gtk.IconSize.LARGE_TOOLBAR)
        self.title_label = self.builder.get_object("label_caption")
        self.value_label = self.builder.get_object("label_value")
        self.title_label.set_label(self.title)
        self.update_value_label()

    def update_value_label(self):
        self.value_label.set_label(self.value_for_display)

    def has_popover(self) -> bool:
        return self.popover is not None
