/**
   Copyright (C) 2014 Raphael Freudiger <laser_b@gmx.ch>
   Copyright (C) 2014 Jonatan Zeidler <jonatan_zeidler@gmx.de>
   Copyright (C) 2014-2017 Tails Developers <tails@boum.org>

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

   status-menu-helper is based on gnome-shell-extension-suspend-button
   (https://github.com/laserb/gnome-shell-extension-suspend-button) by
   Raphael Freudiger <laser_b@gmx.ch>.
**/
const Lang = imports.lang;
const Mainloop = imports.mainloop;

const St = imports.gi.St;
const LoginManager = imports.misc.loginManager;
const Main = imports.ui.main;
const StatusSystem = imports.ui.status.system;
const PopupMenu = imports.ui.popupMenu;
const ExtensionSystem = imports.ui.extensionSystem;
const BoxPointer = imports.ui.boxpointer;

const Gettext = imports.gettext.domain('tails');
const _ = Gettext.gettext;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Lib = Me.imports.lib;

const Util = imports.misc.util;

const Extension = new Lang.Class({
    Name: 'StatusMenuHelper.Extension',

    enable: function() {
        this.statusMenu = Main.panel.statusArea['aggregateMenu']._system;

        this._createActions();
        this._removeAltSwitcher();
        this._addSeparateButtons();

        this._menuOpenStateChangedId = this.statusMenu.menu.connect('open-state-changed', Lang.bind(this,
            function(menu, open) {
                if (!open)
                    return;
                this._restartButton.visible = true;
                this._poweroffButton.visible = true;
            }));

        Main.sessionMode.connect('updated', Lang.bind(this, this._sessionUpdated));
        this._sessionUpdated();
    },

    disable: function() {
        if (this._menuOpenStateChangedId) {
            this.statusMenu.menu.disconnect(this._menuOpenStateChangedId);
            this._menuOpenStateChangedId = 0;
        }

        this._destroyActions();
        this._restoreAltSwitcher();
    },

    _createActions: function() {
        this._restartButton = this.statusMenu._createActionButton('view-refresh-symbolic', _("Restart"));
        this._restartButtonId = this._restartButton.connect('clicked', Lang.bind(this, this._onRestartClicked));
 
        this._lockScreenButton = this.statusMenu._createActionButton('changes-prevent-symbolic', _("Lock screen"));
        this._lockScreenButtonId = this._lockScreenButton.connect('clicked', Lang.bind(this, this._onLockClicked));

        this._poweroffButton = this.statusMenu._createActionButton('system-shutdown-symbolic', _("Power Off"));
        this._poweroffButtonId = this._poweroffButton.connect('clicked', Lang.bind(this, this._onPowerOffClicked));
    },

    _removeAltSwitcher: function() {
        this.statusMenu._actionsItem.actor.remove_child(this.statusMenu._altSwitcher.actor);
    },

    _restoreAltSwitcher: function() {
        this.statusMenu._actionsItem.actor.add(this.statusMenu._altSwitcher.actor, { expand: true, x_fill: false });
    },

    _addSeparateButtons: function() {
        this.statusMenu._actionsItem.actor.add(this._lockScreenButton, { expand: true, x_fill: false });
        this.statusMenu._actionsItem.actor.add(this._restartButton, { expand: true, x_fill: false });
        this.statusMenu._actionsItem.actor.add(this._poweroffButton, { expand: true, x_fill: false });
    },

    _destroyActions: function() {
        if (this._restartButtonId) {
            this._restartButton.disconnect(this._restartButtonId);
            this._restartButtonId = 0;
        }

        if (this._poweroffButtonId) {
            this._poweroffButton.disconnect(this._poweroffButtonId);
            this._poweroffButtonId = 0;
        }

        if (this._lockScreenButtonId) {
            this._lockScreenButton.disconnect(this._lockScreenButtonId);
            this._lockScreenButtonId = 0;
        }

        if (this._restartButton) {
            this._restartButton.destroy();
            this._restartButton = 0;
        }

        if (this._poweroffButton) {
            this._poweroffButton.destroy();
            this._poweroffButton = 0;
        }

        if (this._lockScreenButton) {
            this._lockScreenButton.destroy();
            this._lockScreenButton = 0;
        }
    },

    _onPowerOffClicked: function() {
        Util.spawn(['sudo', '-n', 'poweroff'])
    },

    _onRestartClicked: function() {
        Util.spawn(['sudo', '-n', 'reboot'])
    },

    _onLockClicked: function() {
	this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Main.overview.hide();
	Util.spawn(['tails-screen-locker']);
    },

    _sessionUpdated: function() {
        this._lockScreenButton.setSensitive = !Main.sessionMode.isLocked && !Main.sessionMode.isGreeter;
    },

});

function init(metadata) {
    Lib.initTranslations(Me);
    return new Extension();
}

