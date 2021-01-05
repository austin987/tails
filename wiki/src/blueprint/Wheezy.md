[[!tag archived]]

We need to start porting Tails to Wheezy, and test it.
Work is done in the `feature/wheezy` Git branch.

**Tickets**:

* [1.1 milestone](https://labs.riseup.net/code/projects/tails/roadmap#Tails_1.1)
* [[!tails_ticket 6015]]

**Current state** (2013-12-23): builds, boots. Quite some things are
broken, and many minor features had to be disabled to workaround
build issues.

[[!toc levels=2]]

Research to do
==============

Windows Camouflage
------------------

**Ticket**: [[!tails_ticket 6342]]

We need to implement the Windows Camouflage mode in GNOME3 "Classic"
(aka. fallback) mode.

### Windows XP

i.e. porting the 1.0 theme

#### Left to do

* Metacity theme, mouse cursor theme and desktop background: should be
  set correctly in `/usr/local/bin/tails-activate-winxp-theme`, but
  isn't actually applied; perhaps changing GSettings in
  `PostLogin.default` isn't supported? We should try migrating this
  code from `PostLogin.default` to a script started from
  `~/.config/autostart/` and see if this works better; might be
  applied too late, though.
* GTK2 theme
* GTK3 theme
* icons theme
* only one GNOME panel
* many, many more settings set in the script
  (`/usr/local/bin/tails-activate-winxp-theme`) that enables all this
  when the user has enabled Windows Camouflage in the Greeter

#### Resources

* The [Luna XP theme](http://winxp4life.tk/index.php#linux) we ship in
  Tails/Squeeze only supports GTK2, *but* upstream have ported it to
  GTK3 and MATE since then.
* Ubuntu's GNOME Classic is not that far from a good old GNOME2 DE:
  https://help.ubuntu.com/community/PreciseGnomeClassicTweaks
* The default theme (`/usr/share/themes/Adwaita/gtk-3.0/`) can be
  forked and customized.
* GTK3 Windows-like themes seem to be
  [in the works](http://blogs.gnome.org/alexl/2012/03/27/moar-windows-themes/),
  and <http://gnome-look.org/> has a few ones.
* some [customization tips](http://askubuntu.com/questions/69576/how-to-customize-the-gnome-classic-panel)

### Windows eight themes

#### Screenshots

* <http://www.techranger.net/media/Screenshot_12.png>
* <https://www.youtube.com/watch?v=qVEvbKg6JNI&src_vid=_E1UxI5I_jo&feature=iv&annotation_id=annotation_571654>
* <https://www.youtube.com/watch?v=wi8NpwiEuzc>

#### Configuration

* <http://www.omgubuntu.co.uk/2014/02/windows-8-metro-gtk-theme>
  - gtk3: <http://gnome-look.org/content/show.php?content=158721> (GPLv3)
  - metacity: <http://gnome-look.org/content/show.php/Windows+8+modern+UI?content=157024> (GPLv3)
* icon theme: <http://gnome-look.org/content/show.php/?content=153241> (GPLv3)
* cursors: <http://gnome-look.org/content/show.php/?content=155025> (GPLv3)
* panel taskbar: <https://github.com/lanoxx/window-picker-applet/> (GPLv3)
* panel height: 48px

#### Other ressources

* <http://news.softpedia.com/news/Windows-8-GTK-Theme-for-Linux-Is-as-Close-As-Possible-to-Microsoft-s-Windows-8-OS-428436.shtml>

### Windows seven themes

#### Screenshots

* <http://www.softpedia.com/progScreenshots/Windows-7-Screenshot-118183.html>
* <http://i1-win.softpedia-static.com/screenshots/Windows-7_5.jpg>

#### Mostly working configuration

* GTK2, GTK3, metacity: <http://gnome-look.org/content/show.php/Win2-7+Remix?content=153233> (GPLv3)
* icon theme: <http://gnome-look.org/content/show.php/?content=153241> (GPLv3)
* cursors: <http://gnome-look.org/content/show.php/?content=155025> (GPLv3)
* panel taskbar: <https://github.com/lanoxx/window-picker-applet/> (GPLv3)

#### Other ressources

* <http://gnome-look.org/content/show.php/Windows+7+theme?content=116499>
* <http://gnome-look.org/content/show.php/Win2-7+Pack?content=113264>
* <http://doc.ubuntu-fr.org/tutoriel/theme_seven>
* <http://gnome-look.org/content/show.php/%5BLXDE%5DWinAte+-+Windows+7+8+Theme+pack?content=163150>
* icon only taskbar panel applet
  - Talika (gnome2) <http://www.webupd8.org/2010/01/talika-applet-icons-only-window-list-on.html>
  - Dockbarx (gnome2 + standalone): http://gnome-look.org/content/show.php/DockbarX?content=101604

What works
==========

* Reading (IMAP) and sending email with Claws.
* OpenPGP applet symmetric enc/dec
* Roundcube webmail
* MAT cleans a PDF
* Erase memory on shutdown
* USB installer (Clone & Install)
* Iceweasel/torbrowser works
* FTP works on LAN in Nautilus
* Streaming in Totem
* Unlocking and using already created persistence
* Tails-additional-software works
* Unsafe browser
* Orca
* memory wiping on shutdown works, when triggered by the GNOME
  shutdown UI, on a system that has this feature working despite Linux
  3.11
