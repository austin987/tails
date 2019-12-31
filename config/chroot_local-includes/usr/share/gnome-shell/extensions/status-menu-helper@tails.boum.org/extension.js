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
const St = imports.gi.St;
const Main = imports.ui.main;
const BoxPointer = imports.ui.boxpointer;

const Gettext = imports.gettext.domain('tails');
const _ = Gettext.gettext;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Lib = Me.imports.lib;

const Util = imports.misc.util;

var Action = new Lang.Class({
    Name: 'Action',

    _init: function(button, id) {
        this.button = button;
        this.id = id;
    }
});

const Extension = new Lang.Class({
    Name: 'StatusMenuHelper.Extension',

    enable: function() {
        if (this._isEnabled) return;
        this._isEnabled = true;

        this.statusMenu = Main.panel.statusArea['aggregateMenu']._system;

        this._createActions();
        this._removeOrigActions();
        this._addSeparateButtons();

        this.statusMenu.menu.connect('open-state-changed', (menu, open) => {
            if (!open)
                return;
            this._update();
        });
    },

    disable: function() {
        // We want to keep the extention enabled on the lock screen
        if (Main.sessionMode.isLocked) return;
        this._isEnabled = false;

        this._destroyActions();
        this._restoreOrigActions();
    },

    _createActions: function() {
        this._lockScreenAction = this._createAction(_("Lock screen"),
                                                   'changes-prevent-symbolic',
                                                    this._onLockClicked);

        this._suspendAction = this._createAction(_("Suspend"),
                                                 'media-playback-pause-symbolic',
                                                 this._onSuspendClicked);

        this._restartAction = this._createAction(_("Restart"),
                                                 'view-refresh-symbolic',
                                                 this._onRestartClicked);

        this._powerOffAction = this._createAction(_("Power Off"),
                                                  'system-shutdown-symbolic',
                                                  this._onPowerOffClicked);

        this._actions = [this._lockScreenAction, this._suspendAction,
                         this._restartAction, this._powerOffAction];
    },

    _createAction: function(label, icon, onClickedFunction) {
        let button = this.statusMenu._createActionButton(icon, label);
        let id = button.connect('clicked', Lang.bind(this, onClickedFunction));
        return new Action(button, id);
    },

    _removeOrigActions: function() {
        this.statusMenu._actionsItem.actor.remove_child(this.statusMenu._altSwitcher.actor);
        this.statusMenu._actionsItem.actor.remove_child(this.statusMenu._lockScreenAction);
    },

    _restoreOrigActions: function() {
        this.statusMenu._actionsItem.actor.add(this.statusMenu._altSwitcher.actor, { expand: true, x_fill: false });
        this.statusMenu._actionsItem.actor.add(this.statusMenu._lockScreenAction, { expand: true, x_fill: false });
    },

    _addSeparateButtons: function() {
        for (let i = 0; i < this._actions.length; i++) {
            this.statusMenu._actionsItem.actor.add(this._actions[i].button, { expand: true, x_fill: false });
        }
    },

    _destroyActions: function() {
        for (let i = 0; i < this._actions.length; i++) {
            let action = this._actions[i];
            if (action.id) {
                action.button.disconnect(action.id);
                action.id = 0;
            }

            if (action.button) {
                action.button.destroy();
                action.button = 0;
            }
        }
    },

    _onLockClicked: function() {
        this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Main.overview.hide();
        Util.spawn(['tails-screen-locker']);
    },

    _onSuspendClicked: function() {
        this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Util.spawn(['systemctl', 'suspend'])
    },

    _onRestartClicked: function() {
        this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Util.spawn(['sudo', '-n', 'reboot'])
    },

    _onPowerOffClicked: function() {
        this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Util.spawn(['sudo', '-n', 'poweroff'])
    },

    _update: function() {
        this._lockScreenAction.button.visible = !Main.sessionMode.isLocked && !Main.sessionMode.isGreeter;
    }

});

function init(metadata) {
    Lib.initTranslations(Me);
    return new Extension();
}
