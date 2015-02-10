#!/usr/bin/python
#*-* coding=utf-8

import sys
import optparse

from gi.repository import Gtk, Gdk, GObject, GdkPixbuf

class GreeterMockup:

    def __init__(self, version="5", persistence=False):
        uifilename = "tails-greeter" + version + ".ui"

        ui = Gtk.Builder()
        ui.add_from_file(uifilename)
        ui.connect_signals(self)

        self._main_window = ui.get_object("window_main")
        self._notebook = ui.get_object("notebook_main")
        self._previous = ui.get_object("button_previous")
        self._locale_label = ui.get_object("label_locale")
        self._linkbutton_language = ui.get_object("linkbutton_language")
        self._persistence = ui.get_object("box_persistence")
        self._persistence_setup = ui.get_object("button_persistence_setup")
        self._persistence_entry = ui.get_object("box_persistence_entry")
        self._persistence_activate = ui.get_object("box_persistence_activate")
        self._persistence_info = ui.get_object("box_persistence_info")

        self._iconview_locale = ui.get_object("iconview_locale")
        self._iconview_options = ui.get_object("iconview_options")
        language = ui.get_object("languages_treeview")

        self._persistence.set_visible(persistence)

        if language:
            tvcolumn = Gtk.TreeViewColumn("Language")
            language.append_column(tvcolumn)
            cell = Gtk.CellRendererText()
            tvcolumn.pack_start(cell, True)
            tvcolumn.add_attribute(cell, 'text', 1)

        self.cb_languages()
        self._iconview_locale.connect("selection-changed", self.cb_option_selected)

        self.fill_view(self._iconview_options,
                  [("Keyboard", "preferences-desktop-keyboard", "cb_show_keyboard"),
                   ("Bridges", "network-vpn", "cb_show_briges"),
                   ("Widows camouflage", "preferences-desktop-theme", "cb_show_camouflage"),
                   ("Administrative rights", "dialog-password", "cb_show_password"),
                   ("Hardware address", "audio-card", "cb_show_mac")])
        self._iconview_options.connect("selection-changed", self.cb_option_selected)

        self._main_window.show()

    def fill_view(self, view, list):
        model = Gtk.ListStore(GObject.TYPE_STRING, GdkPixbuf.Pixbuf, GObject.TYPE_STRING)
        icon_theme = Gtk.IconTheme.get_default()
        for i in list:
            try:
                pixbuf = icon_theme.lookup_icon(i[1], 48, 0).load_icon()
            except:
                pixbuf = None
            model.append([i[0], pixbuf, i[2]])
        view.set_model(model)
        view.set_text_column(0)
        view.set_pixbuf_column(1)

    def cb_languages(self, widget=None, data=None):
        self.fill_view(self._iconview_locale,
                  [("Deutsch", None, "cb_locale"),
                   ("English", None, "cb_locale"),
                   ("Español", None, "cb_locale"),
                   ("Français", None, "cb_locale"),
                   ("Italiano", None, "cb_locale"),
                   ("Portugès", None, "cb_locale"),
                   ("Tiéng Vièt", None, "cb_locale"),
                   ("Русский", None, "cb_locale"),
                   ("العربية", None, "cb_locale"),
                   ("فارسی", None, "cb_locale"),
                   ("中文", None, "cb_locale"),
                   ("Other...", None, "cb_more_languages")])
        self._locale_label.set_text("please select your language")
        if self._linkbutton_language:
            self._linkbutton_language.set_visible(False)
        

    def cb_option_selected(self, iconview, data=None):
        treepath = iconview.get_selected_items()[0]
        model = iconview.get_model()
        method_name = model[treepath][2]
        if method_name:
            method_name = "self." + method_name +"()"
            print(method_name)
            exec(method_name)

    def cb_more_languages(self):
        self._notebook.set_current_page(1)
        self._previous.set_visible(True)

    def cb_locale(self):
        self.fill_view(self._iconview_locale,
                  [("Belgique", None, "cb_keyboard"),
                   ("Canada", None, "cb_keyboard"),
                   ("France", None, "cb_keyboard"),
                   ("Luxembouge", None, "cb_keyboard"),
                   ("Suisse", None, "cb_keyboard"),
                   ("Other...", None, "cb_more_languages")])
        self._locale_label.set_text("you have chosen French language; please select your region")
        if self._linkbutton_language:
            self._linkbutton_language.set_visible(True)

    def cb_keyboard(self):
        pass

    def cb_show_briges(self):
        pass

    def cb_show_keyboard(self):
        self._notebook.set_current_page(1)
        self._previous.set_visible(True)

    def cb_show_locale(self):
        self._notebook.set_current_page(1)
        self._previous.set_visible(True)

    def cb_show_main(self, widget, data=None):
        self._notebook.set_current_page(0)
        self._previous.set_visible(False)

    def cb_show_camouflage(self):
        self._notebook.set_current_page(3)
        self._previous.set_visible(True)

    def cb_show_password(self):
        self._notebook.set_current_page(2)
        self._previous.set_visible(True)

    def cb_show_mac(self):
        self._notebook.set_current_page(3)
        self._previous.set_visible(True)

    def cb_setup_persistence(self, widget, data=None):
        if self._persistence_setup:
            self._persistence_setup.set_visible(False)
            self._persistence_entry.set_visible(True)
            self._persistence_activate.set_visible(True)

    def cb_activate_persistence(self, widget, data=None):
        if self._persistence_activate:
            self._persistence_entry.set_visible(False)
            self._persistence_activate.set_visible(False)
            self._persistence_info.set_visible(True)

    def cb_cancel_persistence(self, widget, data=None):
        if self._persistence_setup:
            self._persistence_entry.set_visible(False)
            self._persistence_activate.set_visible(False)
            self._persistence_setup.set_visible(True)

    def cb_quit(self, widget, data=None):
        Gtk.main_quit()


    def cb_lang_button_press(self, widget, event, data=None):
        """Handle mouse click in langdialog"""
        if (event.type == Gdk.EventType._2BUTTON_PRESS or
                event.type == Gdk.EventType._3BUTTON_PRESS):
            self._notebook.set_current_page(0)
            self._previous.set_visible(False)
if __name__ == '__main__':
    parser = optparse.OptionParser()
    parser.add_option("-v", "--variant", dest="variant", default="5")
    parser.add_option("-p", "--persistence", action="store_true", dest="persistence", default=False)
    parser.add_option("-P", "--no-persistence", action="store_false", dest="persistence", default=False)

    (options, args) = parser.parse_args()

    app = GreeterMockup(options.variant, options.persistence)
    Gtk.main()

