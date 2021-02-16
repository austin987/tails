import gi
import gettext
import sys

gi.require_version('GLib', '2.0')
gi.require_version('Gtk', '3.0')
from gi.repository import GLib, Gtk

from tca.ui.main_window import TCAMainWindow
import tca.config

class TCAApplication:
    '''
    main controller
    '''
    def __init__(self):
        self.mainwindow = TCAMainWindow(self)

if __name__ == '__main__':
    _ = gettext.gettext
    GLib.set_prgname(tca.config.APPLICATION_TITLE)
    GLib.set_application_name(_(tca.config.APPLICATION_TITLE))
    Gtk.init(sys.argv)
    Gtk.Window.set_default_icon_name(tca.config.APPLICATION_ICON_NAME)
    application = TCAApplication()
    Gtk.main()
