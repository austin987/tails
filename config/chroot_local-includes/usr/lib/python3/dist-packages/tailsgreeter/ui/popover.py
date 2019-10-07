import gi
from typing import Callable, Union

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk


class Popover(object):
    def __init__(self, relative_widget, content_widget: Gtk.Popover):
        self.widget = Gtk.Popover.new(relative_widget)
        self.widget.set_position(Gtk.PositionType.BOTTOM)
        self.widget.add(content_widget)
        self.closed_cb = None  # type: Union[None, Callable]
        self.closed_cb_user_data = None
        self.opened_cb = None  # type: Union[None, Callable]
        self.opened_cb_user_data = None
        self.closed_signal_handler = None
        self.response = None  # type: Union[None, Gtk.ResponseType]

    def on_closed(self, widget):
        if self.closed_cb:
            self.closed_cb(self, self.closed_cb_user_data)
        # Make sure we only call the callback once
        self.closed_cb = None
        self.widget.disconnect(self.closed_signal_handler)

    def open(self, closed_cb: Callable, user_data=None):
        self.closed_cb = closed_cb
        self.closed_cb_user_data = user_data
        self.closed_signal_handler = self.widget.connect('closed', self.on_closed)
        self.widget.set_visible(True)
        if self.opened_cb:
            self.opened_cb(self, self.opened_cb_user_data)

    def close(self, response: Gtk.ResponseType):
        self.response = response
        self.widget.set_visible(False)

    def is_open(self) -> bool:
        return self.widget.get_visible()
