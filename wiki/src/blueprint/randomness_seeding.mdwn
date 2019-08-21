[[!meta title="Seeding the random number generator"]]
[[!toc levels=2]]

# Introduction

`/dev/random` and `/dev/urandom` are special Linux devices that provide
access from user land to the Linux kernel Cryptographically Secure
Pseudo Random Number Generator (CSPRNG). This generator is used for
almost every security protocol, like key generation (TLS,
[OpenPGP](https://eprint.iacr.org/2006/086.pdf), LUKS),
picking nodes for Tor circuits, choosing TCP sequences, ASLR offsets. In order
for this CSPRNG to indeed be cryptographically secure, it's recommended
to seed it with a 'good' entropy source, even though The Linux kernel
collects entropy from several sources, for example keyboard typing,
mouse movement, among others.

Because of Tails' feature of being amnesic, and run from different types
of live devices (from DVDs to USB sticks), special care must be taken to
ensure the system gets enough entropy and boots with enough randomness.
This proves to be hard within the Tails context, where the system is
almost always booting the same way. Even the SquashFS is ordered to
optimize boot time.

Although these problems have been documented since a long time (see
<https://www.av8n.com/computer/htm/secure-random.htm> and
<http://www.av8n.com/computer/htm/fixup-live-cd.htm>), there's not much
done to tackle the problem. We looked at notes and research from LiveCD
OS's and supply them here for completeness' sake. Whonix has a [wiki
page](https://www.whonix.org/wiki/Dev/Entropy) with some notes, and
Qubes has tickets about this
[Qubes 673](http://wiki.qubes-os.org/trac/ticket/673),
[Qubes 1311](https://github.com/QubesOS/qubes-issues/issues/1311),
[Qubes devel](https://groups.google.com/forum/#!msg/qubes-devel/Q65boPAbqbE/9ZOZUInQCgAJ),
[Qubes devel](https://groups.google.com/forum/#!topic/qubes-devel/5wI8ygbaohk).

# Current situation

See the related [[design document|contribute/design/random]]

Tails does not ship `/var/lib/urandom/random-seed` in the ISO, since it
means shipping a fixed known value for every Tails installation, which
in turn means that entropy contribution would be zero. Furthermore, this
breaks reproducibility of the ISO image.

Without this random seed, `systemd-random-seed` won't write anything to
`/dev/urandom`, so we rely purely on the kernel CSPRNG and current system entropy
to get `/dev/urandom`. It's commonly admitted to be quite good, but given the
Live nature of Tails, and the fact that good cryptography is a must, we may
want to add additional measures to ensure any Tails system has enough entropy.

Tails ships Haveged and rngd since a while. Still there are concerns about
Haveged's reliability to provide cryptographically secure randomness, and rngd
is only really useful when random generator devices are used.

Taking other measures to seed the Linux Kernel CSPRNG with good material seems
worth spending efforts on.

# Use cases

Tails is used in different ways with different live devices. That requires
different solutions, depending on how and what the Tails OS is installed.

## USB

That's the best supported way to use Tails.

Note that in this case, there are two situations: booting this installation
with persistence enabled, and without.

It is worth noting that the first time this Tails installation is
booted, most of the time the first step is to configure persistence,
which means creating an encrypted partition. At this step though, there
is probably very little entropy at this moment, which may weaken the
LUKS volume encryption ([[!tails_ticket 16891]]).

## Virtual Machines (ISO image as virtual DVD )

Tails supports booting virtual machines from ISO images.

Starting Tails from a DVD on bare metal is not supported anymore since
Tails 3.12 ([[!tails_ticket 15292]]).

This may be the most difficult, since all that the user is running is the plain
ISO we provide. In there, there's no seed at all. It is of public
knowledge that entropy in VMs is very poor. It's not really clear how the
entropy gathering daemons we have would help.

On the other hand, that's not the installation method we want to support the
most, and probably not the most used when people want to secure other
communication types than HTTPS (e.g persistence is very useful for OpenPGP key
storage and usage, chat account configuration, ...).

To safely use Tails in a virtual machine, one needs to provide randomness
from the host system to the guest Tails virtual machine, for example
using the Virtio RNG feature (even if it may not be enough by itself).
XXX: is this possible with VirtualBox?

# Proposed solutions

## Random value on the kernel command-line

On recent enough Linux kernels, such as the one used in Tails, the
content of the kernel command line is used as a source of randomness.

We can thus write a random value there in the bootloader configuration
on first boot, and then update it on every subsequent boot and clean
shutdown, similarly to an initial seed that Tails Installer would
write on the system partition.

This is WIP on [[!tails_ticket 11897]].

## Random value stored in an unused sector

We can write a random value in an unused sector (e.g. LBA 34) on first
boot, and here again, update it on every subsequent boot and
clean shutdown.

This is WIP on [[!tails_ticket 11897]].

## Use the Tails Installer to create a better seed

Tails Installer is used from within Tails to:

 - Clone the running Tails device onto another USB stick,
   for example in order to upgrade the latter.
 - Upgrade another Tails USB stick from an ISO image.

Tails Installer could store a seed in the FAT filesystem of the system
partition. That would workaround this first boot problem not handled by the
persistence option.

This seed can be updated both during early boot (initramfs) and during
regular system shutdown. This means remounting this partition
read-write, writing the new random seed, then respectively remounting
it read-only and unmounting it. Obviously we can do this only in
normal shutdown process, and we'll have to avoid it in emergency
shutdown mode.

This is WIP on [[!tails_ticket 11897]].

We may alternatively not update it, and use it only when the persistence is not
enabled. That would still be a unique source of entropy per Tails installation,
so that would be a better situation than the current one.

## Use stronger/more entropy collectors [[!tails_ticket 5650]]

As already stated, Tails runs Haveged and rngd.

We may want to add other sources though, given there are concerns about Haveged,
and rngd starts only when a hardware RNG is detected, which is not so often the
case.

XXX: It would be nice to have a study (read: a survey of packages, etc)
of all the useful entropy gathering daemons that might be of use on a
Tails system (and have this tested on computers with/without Intel RDRAND
or things like an Entropy Key).

An evaluation of some of them [has been done
already](https://volumelabs.net/best-random-data-software/)

Possible candidates:

* [entropy gathering daemon](http://egd.sourceforge.net/): not packaged into Debian.
* [twuewand](http://www.finnie.org/software/twuewand/): used by Finnix LiveCD
  (so made for this kind of environment), not in Debian.
* [timer entropy daemon](https://www.vanheusden.com/te/): not packaged into Debian
* randomsound: probably a bad idea in the Tails context as we're discussing a
  Greeter option to deactivate the microphone.

## Block booting until enough entropy has been gathered

One way to ensure Tails is booting with enough entropy would be to block
the boot while the system is lacking it.

But this brings questions about how to interact correctly with the users,
as blocking without notifications would be terrible UX. Also Tails boot time is
a bit long already, and this may grow it quite a bit more again.

XXX: will enough entropy be gathered on such a blocked, idling system?

XXX: So before going on, we need a bit more data about the state of the entropy when
Tails boots, especially now that we have several entropy collector daemons. It may
very well be that this case does not happen anymore. And if it does, we need to know
on average how much time that blocking would last. [[!tails_ticket
11758]]

## Regularly check available entropy and notify if low

An idea that has been mentioned several times is to have a service that
checks if the available entropy is high enough, and notifies the user if
it's not the case. One downside is, that observing the entropy pool costs
randomness, so this may have to be implemented with care or is worth
discussing/researching the costs/benefits.

XXX: why does observing the entropy pool cost randomness? Does reading
`/proc/sys/kernel/random/poolsize` and
`/proc/sys/kernel/random/entropy_avail` impact the amount of estimated
entropy available?

# Abandoned solutions

## Persist entropy pool seeds [[!tails_ticket 7675]]

For users who enable the persistent storage option, we could store
there a seed from the previous session to help bootstrap with some
"well" generated randomness.

Storing it in the persistent partition could be implemented using a default
(hidden to the user) persistence setting. But it does not solve the problem for
the first time Tails is booted, which is likely when the encrypted persistence
partition is created.

And meanwhile, we have found ways to get the same benefits for every
Tails USB stick, with or without persistence (WIP on [[!tails_ticket
11897]]).

# Related tickets

This is about [[!tails_ticket 7642]], [[!tails_ticket 7675]],
[[!tails_ticket 6116]], [[!tails_ticket 11897]] and friends.

# Also see

* [Schleuder thread about haveged](https://0xacab.org/schleuder/schleuder/issues/194)
* The
  [federal office for IT security in Germany analysed the rng in linux kernel 4.9 and all changes made up to 4.17](https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/Studies/LinuxRNG/LinuxRNG_EN.pdf?__blob=publicationFile&v=10).
* [checking for available entropy](https://salsa.debian.org/tookmund-guest/pgpcr/issues/16)
* <https://eprint.iacr.org/2013/338.pdf>
* <https://www.python.org/dev/peps/pep-0506/>
* <https://docs.python.org/2/library/os.html#os.urandom>
