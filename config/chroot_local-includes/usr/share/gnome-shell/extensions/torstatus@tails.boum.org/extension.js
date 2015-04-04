/**********************************************************************
Tor Status: a GNOME shell extension to display Tor status
Copyright (C) 2015 Tails Developers <tails@boum.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************/

const Lang = imports.lang;

const Gio = imports.gi.Gio;
const Shell = imports.gi.Shell;
const St = imports.gi.St;

const Main = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;

const Gettext = imports.gettext.domain('tails');
const _ = Gettext.gettext;

const TorStatusIndicatorName = 'TorStatus'
const TorStatusIndicatorStatusFile = '/var/run/tor-is-ready'

const TorStatusIndicator = new Lang.Class({
    Name: TorStatusIndicatorName,
    Extends: PanelMenu.Button,

    _init: function() {
        this.parent(0.0, _("Tor"));

        // Monitor the status file
        let status_file = Gio.File.new_for_path(TorStatusIndicatorStatusFile);
        this._status_file_monitor = status_file.monitor(Gio.FileMonitorFlags.NONE, null);
        this._monitor_changed_signal_id = this._status_file_monitor.connect(
                'changed', Lang.bind(this, this._onFileChanged));

        // Create icon
        this._icon = new St.Icon({ style_class: 'system-status-icon' });
        this._updateIcon(status_file.query_exists(null));
        this.actor.add_actor(this._icon);
        this.actor.add_style_class_name('panel-status-button');

        // Create menu
        let menu_item = new PopupMenu.PopupMenuItem(_("Open Tor Monitor"));
        menu_item.connect('activate', Lang.bind(this, this._openTorMonitor));
        this.menu.addMenuItem(menu_item);
    },

    _updateIcon: function(tor_is_connected) {
        if (tor_is_connected) {
            this._icon.set_icon_name('tor-connected-symbolic');
        } else {
            this._icon.set_icon_name('tor-disconnected-symbolic');
        }
    },

    _openTorMonitor: function() {
        Shell.AppSystem.get_default().lookup_app('tor-monitor.desktop').activate();
    },

    _onFileChanged: function(monitor, file, other_file, event_type, user_data) {
        switch (event_type) {
            case Gio.FileMonitorEvent.CREATED:
                this._updateIcon(true);
                break;
            case Gio.FileMonitorEvent.DELETED:
                this._updateIcon(false);
                break;
        }
    },

    _destroy: function() {
        this._status_file_monitor.disconnect(this._monitor_changed_signal_id);
        this.parent();
    }
});

let tor_status_indicator;

function init() {
}

function enable() {
    tor_status_indicator = new TorStatusIndicator();
    Main.panel.addToStatusArea(TorStatusIndicatorName, tor_status_indicator);
}

function disable() {
    tor_status_indicator.destroy();
}

