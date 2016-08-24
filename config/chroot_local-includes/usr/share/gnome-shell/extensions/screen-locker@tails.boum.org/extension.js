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

   screen-locker is based on gnome-shell-extension-suspend-button
   (https://github.com/laserb/gnome-shell-extension-suspend-button) by
   Raphael Freudiger <laser_b@gmx.ch>.
**/
const Lang = imports.lang;

const St = imports.gi.St;
const Main = imports.ui.main;
const BoxPointer = imports.ui.boxpointer;

// const Gettext = imports.gettext.domain('tails');
// const _ = Gettext.gettext;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Lib = Me.imports.lib;

const Util = imports.misc.util;

const Extension = new Lang.Class({
    Name: 'ScreenLocker.Extension',

    enable: function() {	
        this.statusMenu = Main.panel.statusArea['aggregateMenu']._system;

        this._lockScreenAction = this.statusMenu._createActionButton('changes-prevent-symbolic', _("Lock"));
        this._lockScreenActionId = this._lockScreenAction.connect('clicked', Lang.bind(this, this._onClicked));
	this.statusMenu._actionsItem.actor.add(this._lockScreenAction, { expand: true, x_fill: false, x_align: St.Align.Start });

    },

    disable: function() {
        this._destroyActions();
    },

    _destroyActions: function() {
        if (this._lockScreenActionId) {
            this._lockScreenAction.disconnect(this._lockScreenActionId);
            this._lockScreenActionId = 0;
        }

        if (this._lockScreenAction) {
            this._lockScreenAction.destroy();
            this._lockScreenAction = 0;
        }
    },

    _onClicked: function() {
	this.statusMenu.menu.itemActivated(BoxPointer.PopupAnimation.NONE);
        Main.overview.hide();
	Util.spawn(['tails-screen-locker']);
    },

});

function init(metadata) {
    Lib.initTranslations(Me);
    return (extension = new Extension());
}

