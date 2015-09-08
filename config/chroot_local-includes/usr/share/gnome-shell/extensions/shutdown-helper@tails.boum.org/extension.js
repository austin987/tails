/**
   Copyright (C) 2014 Raphael Freudiger <laser_b@gmx.ch>
   Copyright (C) 2014 Jonatan Zeidler <jonatan_zeidler@gmx.de>
   Copyright (C) 2014 Tails Developers <tails@boum.org>

   This program is free software: you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation, either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

   shutdown-helper is based on gnome-shell-extension-suspend-button
   (https://github.com/laserb/gnome-shell-extension-suspend-button) by
   Raphael Freudiger <laser_b@gmx.ch>.
**/
const Lang = imports.lang;
const Mainloop = imports.mainloop;

const LoginManager = imports.misc.loginManager;
const Main = imports.ui.main;
const StatusSystem = imports.ui.status.system;
const PopupMenu = imports.ui.popupMenu;
const ExtensionSystem = imports.ui.extensionSystem;

const Gettext = imports.gettext.domain('tails');
const _ = Gettext.gettext;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Lib = Me.imports.lib;

const Util = imports.misc.util;

const Extension = new Lang.Class({
    Name: 'ShutdownHelper.Extension',

    enable: function() {
        this._loginManager = LoginManager.getLoginManager();
        this.systemMenu = Main.panel.statusArea['aggregateMenu']._system;

        this._createActions();
        this._removealtSwitcher();
        this._addSeparateButtons();

        this._menuOpenStateChangedId = this.systemMenu.menu.connect('open-state-changed', Lang.bind(this,
            function(menu, open) {
                if (!open)
                    return;
                this._altrestartAction.visible = true;
                this._altpowerOffAction.visible = true;
            }));
    },

    disable: function() {
        if (this._menuOpenStateChangedId) {
            this.systemMenu.menu.disconnect(this._menuOpenStateChangedId);
            this._menuOpenStateChangedId = 0;
        }

        this._destroyActions();
        this._addDefaultButton();
    },

    _createActions: function() {
        this._altrestartAction = this.systemMenu._createActionButton('view-refresh-symbolic', _("Restart"));
        this._altrestartActionId = this._altrestartAction.connect('clicked', Lang.bind(this, this._onRestartClicked));

        this._altpowerOffAction = this.systemMenu._createActionButton('system-shutdown-symbolic', _("Power Off"));
        this._altpowerOffActionId = this._altpowerOffAction.connect('clicked', Lang.bind(this, this._onPowerOffClicked));
    },

    _destroyActions: function() {
        if (this._altrestartActionId) {
            this._altrestartAction.disconnect(this._altrestartActionId);
            this._altrestartActionId = 0;
        }

        if (this._altpowerOffActionId) {
            this._altpowerOffAction.disconnect(this._altpowerOffActionId);
            this._altpowerOffActionId = 0;
        }

        if (this._altrestartAction) {
            this._altrestartAction.destroy();
            this._altrestartAction = 0;
        }

        if (this._altpowerOffAction) {
            this._altpowerOffAction.destroy();
            this._altpowerOffAction = 0;
        }
    },

    _addDefaultButton: function() {
        this.systemMenu._actionsItem.actor.add(this.systemMenu._altSwitcher.actor, { expand: true, x_fill: false });
    },

    _addSeparateButtons: function() {
        this.systemMenu._actionsItem.actor.add(this._altrestartAction, { expand: true, x_fill: false });
        this.systemMenu._actionsItem.actor.add(this._altpowerOffAction, { expand: true, x_fill: false });
    },

    _removealtSwitcher: function() {
        this.systemMenu._actionsItem.actor.remove_child(this.systemMenu._altSwitcher.actor);
    },

    _createaltStatusSwitcher: function() {
        this._altStatusSwitcher = new StatusSystem.AltSwitcher(this._altrestartAction,this._altpowerOffAction);
        this.systemMenu._actionsItem.actor.add(this._altStatusSwitcher.actor, { expand: true, x_fill: false });
    },

    _removealtStatusSwitcher: function() {
        if (this._altStatusSwitcher) {
            this.systemMenu._actionsItem.actor.remove_child(this._altStatusSwitcher.actor);
            this._altStatusSwitcher.actor.destroy();
            this._altStatusSwitcher = 0;
        }
    },

    _onPowerOffClicked: function() {
        Util.spawn(['sudo', '-n', 'poweroff'])
    },

    _onRestartClicked: function() {
        Util.spawn(['sudo', '-n', 'reboot'])
    }
});

function init(metadata) {
    Lib.initTranslations(Me);
    return (extension = new Extension());
}

