import logging
import gi

from tailsgreeter import TRANSLATION_DOMAIN
import tailsgreeter.config
from tailsgreeter.ui import _
from tailsgreeter.ui.setting import GreeterSetting
from tailsgreeter.ui.popover import Popover
from typing import TYPE_CHECKING

gi.require_version('Gtk', '3.0')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, Pango

if TYPE_CHECKING:
    from tailsgreeter.settings.localization import LocalizationSetting

REGION_SETTINGS_UI_FILE = "region_settings.ui"


class LocalizationSettingUI(GreeterSetting):
    def __init__(self, localization_setting: "LocalizationSetting"):
        self._localization_setting = localization_setting
        super().__init__()
        self.selected_code = ""  # type: str
        self.selected_name = ""  # type: str

        self._localization_setting.connect("notify::value", self.cb_value_changed)

        self.treestore = self._localization_setting.get_tree()

        self.builder = Gtk.Builder()
        self.builder.set_translation_domain(TRANSLATION_DOMAIN)
        self.builder.add_from_file(tailsgreeter.config.data_path + REGION_SETTINGS_UI_FILE)
        popover_box = self.builder.get_object("box_{}_popover".format(self.id))
        self.popover = Popover(self.listboxrow, popover_box)

        self.treeview = self.builder.get_object("treeview_{}".format(self.id))
        self.treeview.connect("row-activated", self.cb_treeview_row_activated)

        # Fill the treeview
        renderer = Gtk.CellRendererText()
        renderer.props.ellipsize = Pango.EllipsizeMode.END
        column = Gtk.TreeViewColumn("", renderer, text=1)
        self.treeview.append_column(column)

        searchentry = self.builder.get_object("searchentry_{}".format(self.id))
        searchentry.connect("search-changed", self.cb_searchentry_search_changed)
        searchentry.connect("activate", self.cb_searchentry_activate)

        self.treestore_filtered = self.treestore.filter_new()
        self.treestore_filtered.set_visible_func(self.cb_liststore_filtered_visible_func, data=searchentry)
        self.treeview.set_model(self.treestore_filtered)

    def apply(self):
        self._localization_setting.set_value(self.selected_code, chosen_by_user=True)

    def cb_searchentry_activate(self, searchentry, user_data=None):
        """Selects the topmost item in the treeview when pressing Enter"""
        if searchentry.get_text():
            self.treeview.row_activated(Gtk.TreePath.new_from_string("0"),
                                        self.treeview.get_column(0))
        else:
            self.popover.close(Gtk.ResponseType.CANCEL)

    def cb_searchentry_search_changed(self, searchentry, user_data=None):
        self.treestore_filtered.refilter()
        if searchentry.get_text():
            self.treeview.expand_all()
            self.treeview.scroll_to_point(0, 0)  # scroll to top
        else:
            self.treeview.collapse_all()
        return False

    def cb_treeview_row_activated(self, treeview, path, column,
                                  user_data=None):
        treemodel = treeview.get_model()
        self.selected_code = treemodel.get_value(treemodel.get_iter(path), 0)
        self.selected_name = treemodel.get_value(treemodel.get_iter(path), 1)
        self.popover.close(Gtk.ResponseType.YES)

    def cb_value_changed(self, obj, param):
        logging.debug("refreshing {}".format(self._localization_setting.get_name()))

        def treeview_select_line(model, path, iter_, data):
            if model.get_value(iter_, 0) == data:
                self.treeview.get_selection().select_iter(iter_)
                self.treeview.scroll_to_cell(path, use_align=True,
                                             row_align=0.5)
                return True
            else:
                return False

        self.treestore_filtered.foreach(
                treeview_select_line,
                self._localization_setting.get_value())

    def cb_liststore_filtered_visible_func(self, model, treeiter, searchentry):
        search_query = searchentry.get_text().lower()
        if not search_query:
            return True

        # Does the current node match the search?
        value = model.get_value(treeiter, 1).lower()
        if search_query in value:
            return True

        # Does the parent node match the search?
        treepath = model.get_path(treeiter)
        parent_treepath = treepath.copy()
        parent_treepath.up()
        if parent_treepath.get_depth() == 1:
            # treepath is now the parent
            parent_value = model.get_value(model.get_iter(parent_treepath), 0)
            return search_query in parent_value

        # Does any of the children nodes match the search?
        children_treeiter = model.iter_children(treeiter)
        while children_treeiter:
            child_value = model.get_value(children_treeiter, 0)
            if search_query in child_value:
                return True
            children_treeiter = model.iter_next(children_treeiter)

        return False


class LanguageSettingUI(LocalizationSettingUI):
    @property
    def id(self) -> str:
        return "language"

    @property
    def title(self) -> str:
        return _("_Language")

    @property
    def icon_name(self):
        return "tails-language"

    @property
    def value_for_display(self) -> str:
        return self._localization_setting.get_name()


class KeyboardSettingUI(LocalizationSettingUI):
    @property
    def id(self) -> str:
        return "keyboard"

    @property
    def title(self) -> str:
        return _("_Keyboard Layout")

    @property
    def icon_name(self):
        return "tails-keyboard-layout"

    @property
    def value_for_display(self) -> str:
        return self._localization_setting.get_name()


class FormatsSettingUI(LocalizationSettingUI):
    @property
    def id(self) -> str:
        return "formats"

    @property
    def title(self) -> str:
        return _("_Formats")

    @property
    def icon_name(self):
        return "tails-formats"

    @property
    def value_for_display(self) -> str:
        return self._localization_setting.get_name()
