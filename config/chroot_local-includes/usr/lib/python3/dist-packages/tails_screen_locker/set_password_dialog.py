#!/usr/bin/env python3

import os
import gettext

UI_FILE = os.path.join(os.path.dirname(__file__), "set_password_dialog.ui")

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk

_ = gettext.gettext

def get_password():
    password_dialog = PasswordDialog()
    return password_dialog.pw


class PasswordDialog(object):
    def on_window1_destroy(self, object, data=None):
        Gtk.main_quit()

    def on_gtk_quit_activate(self, menuitem, data=None):
        Gtk.main_quit()

    def on_cancel_clicked(self, button, data=None):
        Gtk.main_quit()

    def on_entry_changed(self, entry, data=None):
        if not self.entry1.get_text() or not self.entry2.get_text():
            self.ok_button.set_sensitive(False)
        elif self.entry1.get_text() == self.entry2.get_text():
            self.password_match()
        else:
            self.password_mismatch()

    def password_mismatch(self):
        self.ok_button.set_sensitive(False)
        self.entry2.set_icon_from_stock(1, self.mismatch_icon)

    def password_match(self):
        self.ok_button.set_sensitive(True)
        self.entry2.set_icon_from_icon_name(1, None)

    def on_ok_clicked(self, button, data=None):
        pw1 = self.entry1.get_text()
        pw2 = self.entry2.get_text()
        assert(pw1 == pw2)
        self.pw = pw1
        Gtk.main_quit()

    def on_key_pressed(self, widget, event):
        if self.ok_button.get_sensitive() and Gdk.keyval_name(event.keyval) == "Return":
            self.ok_button.clicked()


    def __init__(self):
        self.pw = None
        self.builder = Gtk.Builder()
        self.builder.add_from_file(UI_FILE)
        self.builder.connect_signals(self)
        self.ok_button = self.builder.get_object('button_ok')
        self.entry1 = self.builder.get_object('entry1')
        self.entry2 = self.builder.get_object('entry2')
        self.mismatch_icon = self.entry2.get_icon_stock(1)
        print(self.mismatch_icon)
        self.entry2.set_icon_from_icon_name(1, None)
        self.ok_button.set_sensitive(False)
        self.dialog = self.builder.get_object("dialog1")
        self.dialog.set_title(_("Set a screen lock password"))
        self.dialog.run()


if __name__ == "__main__":
    gettext.install("Tails")
    print(get_password())
