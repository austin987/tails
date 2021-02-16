import gi

gi.require_version('Gdk', '3.0')
gi.require_version('Gtk', '3.0')
from gi.repository import Gdk, Gtk

from tca.translatable_window import TranslatableWindow
import tca.config

MAIN_UI_FILE = 'main.ui'
CSS_FILE = 'tca.css'
class TCAMainWindow(Gtk.Window, TranslatableWindow):
    # TranslatableWindow mixin {{{
    def get_translation_domain(self):
        return 'tails'
    def get_locale_dir(self):
        return tca.config.locale_dir
    # }}}

    def __init__(self, app):
        Gtk.Window.__init__(self, title='Tor Connection Assistant')
        TranslatableWindow.__init__(self, self)
        self.app = app
        self.current_language = 'en'
        self.connect('delete-event', self.cb_window_delete_event, None)
        self.set_position(Gtk.WindowPosition.CENTER)


        # Load custom CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(tca.config.data_path + CSS_FILE)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Load UI interface definition
        builder = Gtk.Builder()
        builder.set_translation_domain(self.get_translation_domain())
        builder.add_from_file(tca.config.data_path + MAIN_UI_FILE)
        builder.connect_signals(self)

        for widget in builder.get_objects():
            # Store translations for the builder objects
            self.store_translations(widget)
            # Workaround Gtk bug #710888 - GtkInfoBar not shown after calling
            # gtk_widget_show:
            # https://bugzilla.gnome.org/show_bug.cgi?id=710888
            if isinstance(widget, Gtk.InfoBar):
                revealer = widget.get_template_child(Gtk.InfoBar, 'revealer')
                revealer.set_transition_type(Gtk.RevealerTransitionType.NONE)

        box_main_container_image_step = builder.get_object('box_main_container_image_step')
        self.add(box_main_container_image_step)
        box_main_container_image_step.add(builder.get_object('box_step_choose_hide'))

        self.show()

    def cb_window_delete_event(self, widget, event, user_data=None):
        # don't close the toplevel window on user request
        return True
