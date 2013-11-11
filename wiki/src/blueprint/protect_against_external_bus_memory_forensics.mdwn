[[!toc levels=2]]

Rationale
=========

It should not be that easy, for an attacker with physical access, to
retrieve Tails memory. (Note that this will especially be the case for
a [[Tails server|todo/server_edition]] instance left unattended.

Archive
=======

## other implementation ideas

* If a firewire card was inserted into the slot and the bus is active,
  pop up a dialog and ask "hey, you want to use firewire/etc.?"
* disable these buses by default, allow opt-in through tails-greeter
  to enable
* ask that users assert they want to use this or that bus, and make
  the assertion bind to a single device, rather than all devices
  blindly
* de-activate PCMCIA and ExpressCard on systems that don't have any
  PCMCIA or ExpressCard devices after running for 5 minutes. This is
  going to byte some users, but probably only the first time.
