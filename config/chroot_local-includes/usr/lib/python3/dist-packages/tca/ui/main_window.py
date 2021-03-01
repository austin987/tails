import logging
import os.path
import json
import subprocess
import gettext
from typing import Dict, Any

import gi
import stem

from tca.translatable_window import TranslatableWindow
from tca.ui.asyncutils import GAsyncSpawn, idle_add_chain
from tca.utils import TorConnectionProxy
import tca.config


gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GLib", "2.0")


from gi.repository import Gdk, Gtk, GLib  # noqa: E402

MAIN_UI_FILE = "main.ui"
CSS_FILE = "tca.css"
IMG_SIDE = '/usr/share/doc/tails/website/about/footprints.svg'

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

log = logging.getLogger(__name__)


class StepChooseHideMixin:
    """
    most utils related to the step in which the user can choose between an easier configuration and going
    unnoticed
    """

    def before_show_hide(self):
        self.state["hide"]: Dict[str, Any] = {}
        self.builder.get_object("radio_unnoticed_none").set_active(True)
        self.builder.get_object("radio_unnoticed_yes").set_active(False)
        self.builder.get_object("radio_unnoticed_no").set_active(False)
        self.builder.get_object("radio_unnoticed_none").hide()

    def cb_step_hide_radio_changed(self, *args):
        easy = self.builder.get_object("radio_unnoticed_no").get_active()
        hide = self.builder.get_object("radio_unnoticed_yes").get_active()
        active = easy or hide
        self.builder.get_object("step_hide_btn_submit").set_sensitive(active)
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
            self.state["hide"]["hide"] = True
            self.state["hide"]["bridge"] = True
            self.change_box("bridge")
        else:
            self.state["hide"]["hide"] = False
            if self.builder.get_object("radio_unnoticed_no_bridge").get_active():
                self.state["hide"]["bridge"] = True
                self.change_box("bridge")
            else:
                self.state["hide"]["bridge"] = False
                self.change_box("progress")


class StepChooseBridgeMixin:
    def before_show_bridge(self, no_default_bridges=False):
        self.state["bridge"]: Dict[str, Any] = {}
        self.builder.get_object("step_bridge_box").show()
        self.builder.get_object("step_bridge_radio_none").set_active(True)
        self.builder.get_object("step_bridge_radio_none").hide()
        self.builder.get_object("step_bridge_text").get_property("buffer").connect(
            "changed", self.cb_step_bridge_text_changed
        )
        hide = self.state["hide"]["hide"]
        if hide or no_default_bridges:
            self.builder.get_object("step_bridge_radio_default").set_sensitive(False)
            self.builder.get_object("step_bridge_text").grab_focus()
        else:
            self.builder.get_object("step_bridge_radio_default").grab_focus()
            self.builder.get_object("step_bridge_radio_default").set_sensitive(True)

        self.builder.get_object("step_bridge_radio_type").set_active(hide)

    def _step_bridge_is_text_valid(self):
        # XXX: do proper validation!
        text = (
            self.builder.get_object("step_bridge_text")
            .get_property("buffer")
            .get_property("text")
        )
        return len(text) > 10

    def _step_bridge_set_actives(self):
        default = self.builder.get_object("step_bridge_radio_default").get_active()
        manual = self.builder.get_object("step_bridge_radio_type").get_active()
        self.builder.get_object("step_bridge_combo").set_sensitive(default)
        self.builder.get_object("step_bridge_text").set_sensitive(manual)
        self.builder.get_object("step_bridge_btn_submit").set_sensitive(
            default or (manual and self._step_bridge_is_text_valid())
        )

    def cb_step_bridge_radio_changed(self, *args):
        self._step_bridge_set_actives()

    def cb_step_bridge_text_changed(self, *args):
        self._step_bridge_set_actives()

    def cb_step_bridge_btn_submit_clicked(self, *args):
        default = self.builder.get_object("step_bridge_radio_default").get_active()
        manual = self.builder.get_object("step_bridge_radio_type").get_active()
        if default:
            self.state["bridge"]["kind"] = "default"
            self.state["bridge"]["default_method"] = self.builder.get_object(
                "step_bridge_combo"
            ).get_active_id()
        elif manual:
            self.state["bridge"]["kind"] = "manual"
            text = (
                self.builder.get_object("step_bridge_text")
                .get_property("buffer")
                .get_property("text")
            )
            self.state["bridge"]["bridges"] = [
                line.strip() for line in text.split("\n")
            ]
        self.change_box("progress")

    def cb_step_bridge_btn_back_clicked(self, *args):
        self.change_box("hide")


class StepConnectProgressMixin:
    def before_show_progress(self):
        self.state["progress"]["error"] = None
        self.builder.get_object("step_progress_box").show()
        if not self.state["hide"]["hide"]:
            self.builder.get_object("step_progress_spinner_internet").start()
            self.builder.get_object("step_progress_spinner_internet").set_property(
                "active", True
            )
            self.spawn_internet_test()
        else:
            self.builder.get_object("step_progress_box_internettest").hide()
            self.builder.get_object("step_progress_box_internetok").hide()
            self.spawn_tor_connect()

    def spawn_internet_test(self):
        test_spawn = GAsyncSpawn()
        test_spawn.connect("process-done", self.cb_internet_test)
        test_spawn.run(["/bin/sh", "-c", "sleep 0.5; true"])

    def spawn_tor_test(self):
        test_spawn = GAsyncSpawn()
        test_spawn.connect("process-done", self.cb_tor_test)
        test_spawn.run(["/bin/sh", "-c", "sleep 0.5; true"])

    def spawn_tor_connect(self):
        self.builder.get_object("step_progress_box_torconnect").show()
        self.builder.get_object("step_progress_pbar_torconnect").show()
        progress = self.builder.get_object("step_progress_pbar_torconnect")

        def do_tor_connect_config():
            print("disabling bridges")
            if not self.state["hide"]["bridge"]:
                self.app.configurator.tor_connection_config.disable_bridges()
            elif self.state["bridge"]["kind"] == "default":
                self.app.configurator.tor_connection_config.default_bridges(
                    only_type=self.state["bridge"]["default_method"]
                )
            elif self.state["bridge"]["bridges"]:
                self.app.configurator.tor_connection_config.enable_bridges(
                    self.state["bridge"]["bridges"]
                )
            else:
                raise ValueError(
                    "inconsistent state! you discovered a programming error"
                )
            progress.set_fraction(0.1)
            progress.set_text("configuration prepared")
            return True

        def do_tor_connect_default_bridges():
            print("disabling bridges")
            self.app.configurator.tor_connection_config.default_bridges(
                only_type="obfs4"
            )
            if not self.state["proxy"] or self.state["proxy"]["proxy_type"] == "no":
                self.app.configurator.tor_connection_config.proxy = (
                    TorConnectionProxy.noproxy()
                )
            else:
                proxy_conf = self.state["proxy"]
                if proxy_conf["proxy_type"] != "Socks5":
                    del proxy_conf["username"]
                    del proxy_conf["password"]
                proxy_conf["proxy_type"] += "Proxy"
                self.app.configurator.tor_connection_config.proxy = TorConnectionProxy.from_obj(
                    proxy_conf
                )
            progress.set_fraction(0.1)
            progress.set_text("configuration prepared")
            return True

        def do_tor_connect_apply():
            print("applying conf")
            try:
                self.app.configurator.apply_conf()
            except stem.InvalidRequest as exc:
                progress.set_fraction(0)
                progress.set_text("Error setting bridges!")
                self.state["progress"]["error"] = "setconf"
                self.state["progress"]["error_data"] = exc.message
                self.change_box('error')
                return False
            print("applied!")
            progress.set_fraction(0.20)
            progress.set_text("applied")
            GLib.timeout_add(1000, do_tor_connect_check, {"count": 30})
            return False

        def do_tor_connect_check(d: dict):
            # this dictionary trick is a argument to circumvent the fact that integers are immutable in
            # Python; the dictionary is just acting like a mutable reference, job that might be done with
            # weakref or other methods, but dicts are easier to understand.
            if d["count"] <= 0:
                progress.set_fraction(0)
                progress.set_text("Connection error")

                if (
                    not self.state["hide"]["hide"] and not self.state["hide"]["bridge"]
                ) and not self.app.configurator.tor_connection_config.bridges:
                    log.info("Retrying with default bridges")
                    self.app.configurator.tor_connection_config.default_bridges()
                    idle_add_chain(
                        [do_tor_connect_default_bridges, do_tor_connect_apply]
                    )
                else:
                    self.state["progress"]["error"] = "tor"
                    log.info("Failed with bridges")
                    self.change_box("error")
                return False
            d["count"] -= 1

            ok = self.app.configurator.tor_has_bootstrapped()
            if ok:
                if not self.app.configurator.tor_connection_config.bridges:
                    text = "Tor working!"
                else:
                    text = "Tor working (with bridges)!"
                progress.set_fraction(1)
                progress.set_text(text)
                self.builder.get_object("step_progress_box_start").show()
                return False
            else:
                return True

        idle_add_chain([do_tor_connect_config, do_tor_connect_apply])

    def cb_internet_test(self, spawn, retval):
        if retval == 0:
            self.builder.get_object("step_progress_box_internettest").hide()
            self.builder.get_object("step_progress_box_internetok").show()
            self.builder.get_object("step_progress_box_tortest").show()
            self.spawn_tor_test()
        else:
            self.state["progress"]["error"] = "internet"
            self.change_box("error")

    def cb_tor_test(self, spawn, retval):
        self.builder.get_object("step_progress_box_tortest").hide()
        self.builder.get_object("step_progress_box_torok").show()
        if retval == 0:
            self.spawn_tor_connect()
            return
        else:
            self.builder.get_object("step_progress_box_tortest").hide()
            self.builder.get_object("step_progress_box_torok").show()
            self.builder.get_object("step_progress_img_torok").set_from_stock(
                "gtk-dialog-error", Gtk.IconSize.BUTTON
            )

    def cb_step_progress_btn_starttbb_clicked(self, *args):
        subprocess.Popen(["/usr/local/bin/tor-browser"])

    def cb_step_progress_btn_reset_clicked(self, *args):
        self.todo_dialog("I should reset Tor connection")

    def cb_step_progress_btn_monitor_clicked(self, *args):
        subprocess.Popen(["/usr/bin/gnome-system-monitor", "-r"])

    def cb_step_progress_btn_onioncircuits_clicked(self, *args):
        subprocess.Popen(["/usr/local/bin/onioncircuits"])


class StepErrorMixin:
    def before_show_error(self):
        self.state["error"] = {}
        # XXX: fetch data from self.state['progress']['error'] and self.state['progress']['error_data']

    def cb_step_error_btn_proxy_clicked(self, *args):
        self.change_box("proxy")

    def cb_step_error_btn_captive_clicked(self, *args):
        self.todo_dialog("Open unsafe browser")

    def cb_step_error_btn_bridge_clicked(self, *args):
        self.change_box("bridge", no_default_bridges=True)


class StepProxyMixin:
    def before_show_proxy(self):
        self.state.setdefault("proxy", {"proxy_type": "no"})
        self.builder.get_object("step_proxy_combo").set_active_id(
            self.state["proxy"]["proxy_type"]
        )

        for entry in ("address", "port", "username", "password"):
            buf = self.get_object("entry_" + entry).get_property("buffer")
            buf.connect("deleted-text", self.cb_step_proxy_entry_changed)
            buf.connect("inserted-text", self.cb_step_proxy_entry_changed)
            if entry in self.state["proxy"]:
                content = self.state["proxy"][entry]
                buf.set_text(content, len(content))

        self._step_proxy_set_actives()
        self.get_object("combo").grab_focus()

    def _step_proxy_is_valid(self) -> bool:
        proxy_type = self.get_object("combo").get_active_id()

        def get_text(name):
            return self.get_object("entry_" + name).get_text()

        if proxy_type == "no":
            return True
        if not get_text("address"):
            return False
        if not get_text("port"):
            return False
        if proxy_type == "Socks5":
            if get_text("username") and not get_text("password"):
                return False
        return True

    def _step_proxy_set_actives(self):
        proxy_type = self.get_object("combo").get_active_id()
        if proxy_type == "no":
            for entry in ("address", "port", "username", "password"):
                self.get_object("entry_%s" % entry).set_sensitive(False)
        elif proxy_type in ("HTTPS", "Socks4"):
            for entry in ("address", "port"):
                self.get_object("entry_%s" % entry).set_sensitive(True)
            for entry in ("username", "password"):
                self.get_object("entry_%s" % entry).set_sensitive(False)
        else:
            for entry in ("address", "port", "username", "password"):
                self.get_object("entry_%s" % entry).set_sensitive(True)

        self.get_object("btn_submit").set_sensitive(self._step_proxy_is_valid())

    def _step_proxy_is_port_valid(self):
        entry = self.get_object("entry_port")
        port = entry.get_text()
        if not port:
            return True
        elif port.isdigit() and int(port) > 0 and int(port) < 65536:
            return True
        else:
            return False

    def cb_step_proxy_entry_changed(self, *args):
        self._step_proxy_set_actives()
        if self._step_proxy_is_port_valid():
            icon_name = ""
        else:
            icon_name = "gtk-dialog-warning"
        entry = self.get_object("entry_port")
        entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, icon_name)

    def cb_step_proxy_combo_changed(self, *args):
        self._step_proxy_set_actives()

    def cb_step_proxy_btn_back_clicked(self, *args):
        self.change_box("error")

    def cb_step_proxy_btn_submit_clicked(self, *args):
        self.state["proxy"]["proxy_type"] = self.get_object("combo").get_active_id()
        for entry in ("address", "port", "username", "password"):
            self.state["proxy"][entry] = self.get_object("entry_%s" % entry).get_text()

        self.change_box("progress")


class TCAMainWindow(
    Gtk.Window,
    TranslatableWindow,
    StepChooseHideMixin,
    StepConnectProgressMixin,
    StepChooseBridgeMixin,
    StepErrorMixin,
    StepProxyMixin,
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
        # self.state collects data from user interactions. Its main key is the step name
        self.state: Dict[str, Dict[str, Any]] = {
            "hide": {},
            "bridge": {},
            "progress": {},
            "step": "hide",
        }
        if self.app.args.debug_statefile is not None:
            log.debug("loading statefile")
            with open(self.app.args.debug_statefile) as buf:
                content = json.load(buf)
                log.debug("content found %s", content)
                self.state.update(content)
        self.current_language = "en"
        self.connect("delete-event", self.cb_window_delete_event, None)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load custom CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(os.path.join(tca.config.data_path , CSS_FILE))
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
        self.builder.get_object('main_img_side').set_from_file(IMG_SIDE)
        self.add(self.main_container)
        self.change_box(self.state["step"])

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

    def change_box(self, name: str, **kwargs):
        children = self.main_container.get_children()
        if len(children) > 1:
            self.main_container.remove(children[-1])
        self.state["step"] = name
        self.main_container.add(self.builder.get_object("step_%s_box" % name))
        if hasattr(self, "before_show_%s" % name):
            getattr(self, "before_show_%s" % name)(**kwargs)

    def get_object(self, name: str):
        """shortcut over self.builder.get_object"""
        return self.builder.get_object("step_%s_%s" % (self.state["step"], name))

    def cb_window_delete_event(self, widget, event, user_data=None):
        # XXX: warn the user about leaving the wizard
        Gtk.main_quit()
        return False
