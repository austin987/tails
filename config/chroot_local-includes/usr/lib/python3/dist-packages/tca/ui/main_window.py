import subprocess
import gi
import gettext

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk

from tca.translatable_window import TranslatableWindow
from tca.ui.asyncutils import GAsyncSpawn
import tca.config

MAIN_UI_FILE = "main.ui"
CSS_FILE = "tca.css"

# META {{{
# Naming convention for widgets:
# step_<stepname>_<type> if there's a single type in that step
# step_<stepname>_<type>_<name> otherwise
# Callbacks have a similar name, and start with cb_step_<stepname>_
#
# Mixins are used to avoid the "huge class" so typical in UI development. They are NOT meant for code reuse,
# so feel free to break encapsulation whenever you see fit
# Each Mixin cares about one of the steps. Each step has a name
# Special methods:
#  - before_show_<stepname>() is called when changing from one step to the other
# }}}

_ = gettext.gettext


class StepChooseHideMixin:
    """
    most utils related to the step in which the user can choose between an easier configuration and going
    unnoticed
    """

    def before_show_hide(self):
        self.builder.get_object("radio_unnoticed_none").set_active(True)
        self.builder.get_object("radio_unnoticed_yes").set_active(False)
        self.builder.get_object("radio_unnoticed_no").set_active(False)
        self.builder.get_object("radio_unnoticed_none").hide()

    def cb_step_hide_radio_changed(self, *args):
        easy = self.builder.get_object("radio_unnoticed_no").get_active()
        hide = self.builder.get_object("radio_unnoticed_yes").get_active()
        active = easy or hide
        self.builder.get_object("step_hide_btn_connect").set_sensitive(active)
        if easy:
            self.builder.get_object("step_hide_box_bridge").show()
        else:
            self.builder.get_object("step_hide_box_bridge").hide()

    def cb_step_hide_btn_connect_clicked(self, user_data=None):
        easy = self.builder.get_object("radio_unnoticed_no").get_active()
        hide = self.builder.get_object("radio_unnoticed_yes").get_active()
        if not easy and not hide:
            return
        if hide:
            self.todo_dialog("Unnoticed connection wizard")
        else:
            if self.builder.get_object("radio_unnoticed_no_bridge").get_active():
                self.todo_dialog(
                    "Bridge configuration still needs to be implemented"
                )
            else:
                self.change_box("progress")


class StepConnectProgressMixin:
    def before_show_progress(self):
        self.builder.get_object("step_progress_box").show()
        self.builder.get_object("step_progress_spinner_internet").start()
        self.builder.get_object("step_progress_spinner_internet").set_property(
            "active", True
        )
        self.spawn_internet_test()

    def spawn_internet_test(self):
        test_spawn = GAsyncSpawn()
        test_spawn.connect("process-done", self.cb_internet_test)
        test_spawn.run(["/bin/sh", "-c", "sleep 2; true"])

    def spawn_tor_test(self):
        test_spawn = GAsyncSpawn()
        test_spawn.connect("process-done", self.cb_tor_test)
        test_spawn.run(["/bin/sh", "-c", "sleep 2; true"])

    def spawn_tor_connect(self):
        test_spawn = GAsyncSpawn()
        test_spawn.connect("process-done", self.cb_tor_connect_exit)
        test_spawn.connect("stdout-data", self.cb_tor_connect_output)
        test_spawn.run(
            [
                "/bin/sh",
                "-c",
                "for i in `seq 1 20`; do echo INFO=$i; sleep 0.1; done; true",
            ]
        )

    def cb_internet_test(self, spawn, retval):
        if retval == 0:
            self.builder.get_object("step_progress_box_internettest").hide()
            self.builder.get_object("step_progress_box_internetok").show()
            self.builder.get_object("step_progress_box_tortest").show()
            self.spawn_tor_test()

    def cb_tor_test(self, spawn, retval):
        self.builder.get_object("step_progress_box_tortest").hide()
        self.builder.get_object("step_progress_box_torok").show()
        if retval == 0:
            self.builder.get_object("step_progress_box_torconnect").show()
            self.builder.get_object("step_progress_pbar_torconnect").show()
            self.spawn_tor_connect()
            return
        else:
            self.builder.get_object("step_progress_box_tortest").hide()
            self.builder.get_object("step_progress_box_torok").show()
            self.builder.get_object("step_progress_img_torok").set_from_stock(
                "gtk-dialog-error", Gtk.IconSize.BUTTON
            )

    def cb_tor_connect_output(self, spawn, text):
        self.builder.get_object("step_progress_pbar_torconnect").pulse()
        self.builder.get_object("step_progress_pbar_torconnect").set_text(text.strip())

    def cb_tor_connect_exit(self, spawn, retval):
        if retval == 0:
            self.builder.get_object("step_progress_pbar_torconnect").set_fraction(1)
            self.builder.get_object("step_progress_pbar_torconnect").set_text(
                _("Connected")
            )
            self.builder.get_object("step_progress_box_start").show()
            return
        else:
            self.builder.get_object("step_progress_pbar_torconnect").set_fraction(0)
            self.builder.get_object("step_progress_pbar_torconnect").set_text(
                "Error %d connecting" % retval
            )

    def cb_step_progress_btn_starttbb_clicked(self, *args):
        subprocess.Popen(["/usr/local/bin/tor-browser"])

    def cb_step_progress_btn_reset_clicked(self, *args):
        self.todo_dialog("I should reset Tor connection")

    def cb_step_progress_btn_monitor_clicked(self, *args):
        subprocess.Popen(["/usr/bin/gnome-system-monitor", "-r"])

    def cb_step_progress_btn_onioncircuits_clicked(self, *args):
        subprocess.Popen(["/usr/local/bin/onioncircuits"])


class TCAMainWindow(
    Gtk.Window, TranslatableWindow, StepChooseHideMixin, StepConnectProgressMixin
):
    # TranslatableWindow mixin {{{
    def get_translation_domain(self):
        return "tails"

    def get_locale_dir(self):
        return tca.config.locale_dir

    # }}}

    def __init__(self, app):
        Gtk.Window.__init__(self, title="Tor Connection Assistant")
        TranslatableWindow.__init__(self, self)
        self.app = app
        self.current_language = "en"
        self.connect("delete-event", self.cb_window_delete_event, None)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load custom CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(tca.config.data_path + CSS_FILE)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        # Load UI interface definition
        self.builder = builder = Gtk.Builder()
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
                revealer = widget.get_template_child(Gtk.InfoBar, "revealer")
                revealer.set_transition_type(Gtk.RevealerTransitionType.NONE)

        self.main_container = builder.get_object("box_main_container_image_step")
        self.add(self.main_container)
        self.change_box("hide")

        # builder.get_object('box_step_choose_hide')
        self.show()

    def todo_dialog(self, msg=""):
        print("TODO:", msg)
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.CANCEL,
            text="This is still TODO",
        )
        dialog.format_secondary_text(msg)
        dialog.run()
        dialog.destroy()

    def change_box(self, name: str):
        children = self.main_container.get_children()
        if len(children) > 1:
            self.main_container.remove(children[-1])
        self.main_container.add(self.builder.get_object("step_%s_box" % name))
        if hasattr(self, "before_show_%s" % name):
            getattr(self, "before_show_%s" % name)()

    def cb_window_delete_event(self, widget, event, user_data=None):
        # XXX: warn the user about leaving the wizard
        Gtk.main_quit()
        return False
