**Corresponding tickets**: [[!tails_ticket 6178]] and friends.

[[!toc levels=2]]

Background
==========

Tails currently [[uses only AppArmor for isolating
applications|contribute/design/application_isolation]].

User namespaces eventually made their way into the 3.8 kernel:
<https://lwn.net/Articles/531114/>.

Threat model
============

These are *potential* goals. It remains to be discussed which ones are
MUST, SHOULD, etc., which can vary depending on the
sandboxed application.

* filesystem isolation?
* X isolation? (e.g. key logging, taking pictures of the screen)
* network isolation?
* privilege escalation via holes in Linux?
* privilege escalation via already running privileged daemons, or
  setuid/setgid binaries?
* isolation from hardware?
  - sound: prevent sandboxed software from recording
  - identifiers: prevent sandboxed software from learning hardware
    identifiers, e.g. the MAC address; probably hard to achieve, since
    containers share the host's kernel

Security limitations
====================

* Until we can use Ubuntu's AppArmor profiles for LXC in Debian (most
  notably, the mount mediation support is missing), privileged
  containers still [seem to be
  unsafe](https://www.stgraber.org/2014/01/01/lxc-1-0-security-features/).
* [Unprivileged
  containers](https://www.stgraber.org/2014/01/17/lxc-1-0-unprivileged-containers/)
  should be enough for most of what we intend to contain.
  Note, however, that unprivileged containers
  have had quite some security issues when they were introduced (and
  for this reason, the grsec patchset disables unprivileged use of
  user namespaces). Have things gotten better since?


Tools to manage containers
==========================

* LXC
* `unshare(1)`
* [pflask](https://github.com/ghedo/pflask) automates the creation of
  simple Linux containers based on them; it is e.g. used by
  [pflask-debuild](https://github.com/ghedo/pflask/blob/master/tools/pflask-debuild)
* systemd-nspawn
* Docker, that we're [[evaluating|blueprint/evaluate_Docker]] as
  a candidate to replace Vagrant in our easy build system

Running GUI applications in containers
======================================

<a id="oz"></a>

## Subgraph's Oz

* [Oz](https://github.com/subgraph/oz) is a sandboxing system targeting
  everyday workstation applications. It relies mainly on Xpra and
  Linux namespaces.
* See its [technical
  documentation](https://github.com/subgraph/oz/wiki/Oz-Technical-Details)
  for details.
* It has a [GNOME Shell
  extension](https://github.com/subgraph/ozshell-gnome-extension) that
  e.g. allows one to add files (read-only or read-write) to a running sandbox.
* Sandboxed applications can optionally be given access to:
  - files passed on their command line (in a read-only manner), which
    makes them work just fine when started e.g. from a file manager or
    a web browser;
  - the microphone and/or speaker, thanks to Xpra.
* Potential functionality limitations and UX issues:
  - It's not clear to me how things such as copy'n'pasting between
    applications, printing, Orca and IBus input methods are handled.
    Some of those need access to the session D-Bus, so
    presumably making these work will require mediating D-Bus calls,
    as done e.g. in AppArmor on Ubuntu.
    * Xpra 0.14+ can be set up to configure IBus, but how does this
      integrate with the IBus configuration changes applied via the
      desktop environment?
    * Xpra 0.15+ provides a CUPS forwarder backend
  - When one has already started e.g. LibreOffice and needs to open
    a new file, they need to first use the GNOME Shell extension to
    add it to the sandbox; in this respect, the resulting UX seems to
    be inferior to the one the designs the AppArmor and `xdg-app`
    folks mean to implement (file chooser with a privileged backend).
    Creating new files might be problematic as well.
  - Most host OS directories are bind-mounted (read-only) inside the
    sandbox, and a blacklist is applied on top. This means that
    arbitrary code execution is possible, but confined within the
    sandbox, while with AppArmor we restrict a bit more what external
    programs can be executed, but the equivalent of the sandbox is
    arguably weaker.
  - Xpra doesn't support Wayland yet, and Wayland will make some of
    Xpra's current advantages obsolete.

## Other GUI in containers leads

* [Subuser](http://subuser.org/): essentially Docker + Xpra
* [GNOME sandboxed
  applications](https://wiki.gnome.org/Projects/SandboxedApps), aka.
  Flatpak (formerly `xdg-app`); their concept of "portals" is very interesting.
  - To monitor use of portals (e.g. to tell whether they're used at all),
    use `dbus-monitor`. For example:

          dbus-monitor --session "interface='org.freedesktop.portal.FileChooser'"

  - To force GTK to use Portals for select, supported APIs, even outside of Flatpak:

          export GTK_USE_PORTAL=1

    This works, for example, for the Open/Save file dialogs of Firefox
    68 and gedit, and for the Print dialog of Evince. But it does not
    work for the Open/Save file dialogs of GIMP 2.10.8-2+b1 or Evince
    3.30.2-3.

  - To force Qt to use Portals for select, supported APIs, even
    outside of Flatpak, my _untested guess_ is that one needs to
    install [[!debpkg qt5-xdgdesktopportal-platformtheme]] ([upstream
    source
    code](https://code.qt.io/cgit/qt/qtbase.git/tree/src/plugins/platformthemes/xdgdesktopportal)) and
    to set:

          export QT_QPA_PLATFORMTHEME=xdgdesktopportal

  - Ideally we would force usage of Portals for every AppArmor-confined
    application.

  - Flatpak'ing Tor Browser:
    - AsciiWolf's initial work: <https://github.com/micahflee/torbrowser-launcher/issues/407>, <https://github.com/flathub/flathub/pull/1135>
    - muelli's initial work: [[!tor_bug 25578]]
  - [GNOME Developer Experience hackfest: xdg-app + Debian](http://smcv.pseudorandom.co.uk/2016/xdg-app/)
  - LWN on [An initial release of Flatpak portals for GNOME](https://lwn.net/Articles/694291/)
  - [The flatpak security model – part 1: The basics](https://blogs.gnome.org/alexl/2017/01/18/the-flatpak-security-model-part-1-the-basics/)
  - [The flatpak security model – part 2: Who needs sandboxing anyway?](https://blogs.gnome.org/alexl/2017/01/20/the-flatpak-security-model-part-2-who-needs-sandboxing-anyway/)
  - [The flatpak security model, part 3 – The long game](https://blogs.gnome.org/alexl/2017/01/24/the-flatpak-security-model-part-3-the-long-game/)
* Ubuntu Snap
  - Snap seems to be moving towards using Portals. For example,
    support for snaps was
    [added to xdg-desktop-portal]https://github.com/flatpak/xdg-desktop-portal/pull/155).
  - LWN on [Snap interfaces for sandboxed applications](https://lwn.net/Articles/694757/),
    comparing them to Flatpack's portals
* <http://pleonasm.info/blog/2012/10/privilege-separation-with-xpra/>
* [docker-desktop](https://github.com/rogaha/docker-desktop)
* Stéphane Graber's [LXC 1.0 blog post
  series](https://www.stgraber.org/2013/12/20/lxc-1-0-blog-post-series/),
  and especially [GUI in
  containers](https://www.stgraber.org/2014/02/09/lxc-1-0-gui-in-containers/)
* <https://unix.stackexchange.com/questions/134939/x-and-xdotool-in-lxc-instead-of-kvm>
* <https://stackoverflow.com/questions/16296753/can-you-run-gui-apps-in-a-docker>

Other resources
===============

* <http://doger.io/> documents in details the current state of Linux
  containers (namespaces) and of the various userspace implementations
* [Docker, Linux Containers (LXC), and
  security](http://www.slideshare.net/jpetazzo/docker-linux-containers-lxc-and-security):
  good summary of the threats and solutions, as of August 2014
* [Linux Container Security](http://mjg59.dreamwidth.org/33170.html),
  by Matthew Garrett
* Whitepaper by NCC Group on [Linux containers](https://www.nccgroup.trust/globalassets/our-research/us/whitepapers/2016/june/container_whitepaperpdf/) and their weaknesses/strengths
* Google's design for [Linux containers](https://chromium.googlesource.com/chromiumos/docs/+/master/containers_and_vms.md) within ChromeOS
