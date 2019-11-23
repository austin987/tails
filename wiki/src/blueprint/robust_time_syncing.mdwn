This is about [[!tails_ticket 5774]].

[[!toc levels=2]]

Introduction
============

tordate
-------

With *tordate* we're referring to the unholy mess found in
[[!tails_gitweb
config/chroot_local-includes/etc/NetworkManager/dispatcher.d/20-time.sh]],
whose design can be read in [[contribute/design/Time_syncing]]
(overview, steps 1-3, more or less).

tordate is a fragile pile of hacks, and it effectively makes it
possible for attackers to replay any old Tor network consensus to
Tails users. Also, in at least our current understanding of things, it
prevents us from making `/var/lib/tor` persistent, so Tails users have no
long-term Tor Entry Guards. I'm not sure more reasons need to be
stated why we must get rid of it.

The problem
-----------

When Tails boots on a system where the clock is incorrect, Tor will
not be able to bootstrap. With "incorrect" we specifically mean when
the time is outside the current Tor network consensus'
(`/var/lib/tor/cached-microdesc-consensus`) validity lifetime (e.g.
the `valid-after` and `valid-until` fields). When Tor fails to
bootstrap, Tails is effectively useless for networking.

It should be noted that the clock just has to be off by a few hours
for Tor to become completely unable to bootstrap, and that's not very
uncommon. Certain OSes (including Windows up to Windows 8 at least)
set the BIOS clock to the local time, and since Tails uses UTC (and
assumes the BIOS clock is UTC), this becomes a problem for every user
but those living in the GMT+0/UTC timezone. Hence this is a very
serious problem.

What we want
------------

We want a mechanism to avoid the above problem. This mechanism must not
have a network fingerprint unique to Tails. Some people may think NTP,
which is widely used, but NTP is unauthenticated, so a MitM attack
would let an attacker set the system time, which later may be used to
fingerprint the Tails user for applications/protocols that leak the
system time. And while authenticated NTP exists ([[!tails_ticket
6113]]), it's barely in use, so it'd become a great way to identify
Tails users.

In fact, we'd prefer if the sought after "mechanism" is part of Tor's
normal bootstrap process, with no extra packets sent, so the network
fingerprint becomes indistinguishable from a "normal" Tor bootstrap.
That would be a very handy fact when reasoning about how Tails users
can be fingerprinted.

Some other requirements about this mechanism:

* it has to avoid the security issues that current tordate has wrt.
  replayed Tor consensus;
* it has to be more robust that the current tordate;
* it has to be as safe as the current tordate + htpdate combination,
  e.g. wrt. failing closed when facing a replayed consensus and the
  time set by htpdate is out of the `valid-before`/`valid-until`
  interval (admitedly, the corresponding UX is totally miserable as of
  Tails 1.4, but at least we're failing closed);
* it has to work with pluggable transports;
* it has to work when not doing a full bootstrap, e.g.
  when `/var/lib/tor` is persistent;
* Tor is a bit fragile when it comes to time jumps during
  early bootstrap stages. For instance, in `tordate` we have to restart Tor
  after setting the time according to the fetched consensus, otherwise
  it just idles, at least sometimes. This will have to be solved too;
* it should help improve the UX we provide while Tor is boostrapping
  and the time is being sync'ed, both on success and on various kinds
  of failures.

Possible solutions
==================

Ask the user what time it is
----------------------------

... when Tor fails to bootstrap for time-related reasons.

That's what ChromeOS does when the time is too wrong:

* <https://code.google.com/p/chromium/issues/detail?id=232066#c105>
* <https://codereview.chromium.org/247663003/>
* Sadly, most of their design docs, UI mockups etc. are apparently not
  accessible to non-Google employees or something, so it's not easy to
  understand why they did what. Still, the resulting code is there:
  <https://src.chromium.org/viewvc/chrome?revision=266431&view=revision>

### User story

	When I start Tails
	And I log into the Tails desktop with the default options
	And Tor fails to bootstrap for time-related reasons
	Then I am asked for the correct time
	And at the same time the corresponding UI lets me choose my preferred timezone
	And then, Tails Clock displays the current time with the chosen timezone
	And Tor bootstrap is attempted again

### Roadmap

#### First iteration

Relevant tickets: [[!tails_ticket 10819]], [[!tails_ticket 6284]],
[[!tails_ticket 12094]].

* What's called *Tails Clock* below is the widget that will display
  the current time within the GNOME desktop, in whatever timezone the
  user prefers, which we call the *display timezone*. The system
  timezone remains UTC in all cases.
* From current tordate, we keep only the mechanism that detects if Tor
  fails to bootstrap due to time-related reasons. Whenever this
  happens, we open a GUI that lets the user set the correct time and
  choose their preferred timezone, and then we restart Tor.
  - GNOME Date and Time interface is good -- according to sajolida "We
    could maybe reuse most of that UI"; however, it "looks like
    a geolocation tool" so it "should come with a clear message that
    this is only to set the 'clock display timezone' and not collected
    in any way"
* We keep htpdate as-is for now, in order to keep failing closed on
  replayed Tor consensus.
* We need Tails Clock: otherwise, we would let the user set the
  correct time in their preferred timezone, but then the feedback we
  would give them (in the GNOME clock display) would let them think the
  operation has failed, since it would still display time in UTC.
  We have to avoid making the UX worse this way, hence the need for
  Tails Clock. The config source for the timezone used by Tails
  Clock must be shared with the time input GUI, to provide
  a consistent UX. The interface used by Tails Clock and by the
  upcoming time input GUI could perhaps be shared; this raises
  privilege separation issues that need to be thought through.
* We need a persistence option for the display timezone: otherwise, it
  will be a pain for Windows users. If the new Greeter is ready in
  time for this, perfect; otherwise, we'll have to implement it in
  a different way, e.g. by allowing users to persist their chosen
  timezone when they set it from Tails Clock or from the
  aforementioned GUI.

#### Second iteration

We stop using htpdate to *set* the system clock, but we keep it around
as a way to *detect* a replayed Tor consensus: if the time delta
detected by htpdate is too big:

* we warn the user that something fishy may be going on, and try to
  make as actionable as realistically possible;
* we stop Tor, in order to keep failing closed in this situation.

And then, perhaps htpdate could be configured to query fewer servers,
because we maybe don't need to trust the info we get from htpdate as
much once we're there.

#### Integration with the new Greeter

We need to give the user will have the opportunity to choose their
preferred timezone in the Greeter ([[!tails_ticket 11645]]). And then,
most likely we'll want to provide them feedback about what Tails
thinks the resulting local time is. And in turn, the UI that provides
that feedback can as well allow users to set the system time if
it's wrong ([[!tails_ticket 11641]]).

The chosen timezone information should be re-used both by Tails Clock
and by the time input GUI that lets users correct the system time if
Tor has failed to bootstrap for time-related reasons.

	When I start Tails
	And I choose my preferred timezone in the Greeter
	Then I see the resulting system time in the chosen timezone
	And I am enabled to correct the system time
	And then, Tails Clock displays the current time with the chosen timezone
	And Tor has greater chances to bootstrap successfully on first try

Extend Tor some how
-------------------

E.g.:

* like [Roger
  suggested](https://lists.torproject.org/pipermail/tor-talk/2011-January/008551.html)
* [[!tor_bug 3652 desc="Export clock skew opinion as getinfo command"]]
  and its [[!tor_bug 6894 desc="answer network time requests"]] duplicate

Misc. resources
===============

* [tlsdate](https://github.com/ioerror/tlsdate)
  - Not maintained nor in Debian anymore.
  - Used by ChromeOS on every network up event => no longer easy to
    fingerprint due to low usage _iff_ we use it exactly in the same
    way (e.g. ask the very same HTTPS servers) as ChromeOS, and go on
    doing so forever.
    * their (outdated) [design
      doc](https://docs.google.com/a/chromium.org/document/d/1ylaCHabUIHoKRJQWhBxqQ5Vck270fX7XCWBdiJofHbU/edit)
    * their [tlsdate
      clone](http://git.chromium.org/gitweb/?p=chromiumos/third_party/tlsdate.git;a=summary)
    * their [upstart job](http://git.chromium.org/gitweb/?p=chromiumos/platform/init.git;a=blob;f=tlsdated.conf;h=d72d780c1f1d432bb7b7a06e787a745dbf5cdd46;hb=HEAD)
    * They query `clients3.google.com` only currently, but intend to
      use the multi-host feature some day.
