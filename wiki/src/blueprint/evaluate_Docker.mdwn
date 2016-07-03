For an overview of the more general problem, see [[blueprint/replace_vagrant]].
For the detailed plans and things to evaluate in Docker, see [[!tails_ticket 7530]].

[[!toc levels=1]]

Availability on target platforms
================================

(as of 20150514)

Primary target platforms:

* Debian Wheezy: no, even in backports; installation is [possible
  using ugly methods](https://docs.docker.com/installation/debian/)
* Debian Jessie: will be maintained in jessie-backports ([[!debbug 781554]]);
  1.6.2~dfsg1-1~bpo8+1 was uploaded on 2015-06-03
* Debian sid: 1.6.1+dfsg1-2
* Ubuntu 14.04 LTS: 0.9.1, with 1.0.1 available in trusty-updates
* Ubuntu 14.10: 1.2.0
* Ubuntu 15.04: 1.5.0
* Ubuntu 15.10 (current development branch): 1.6.0

Bonus:

* Arch: tracks upstream Git
* Fedora: package was retired of Fedora 22

API stability and backwards-compatibility
=========================================

- "all [Docker] containers are backwards compatible, pretty much to
  the first version. [...] In general backwards compatibility is a
  big deal in the Docker project"
  ([source](https://news.ycombinator.com/item?id=7985142), shykes
  is a Docker developer)
- Apparently the Docker 1.0 release broke older stuff, see e.g. the
  0.6 release in
  [the jenkins plugin changelog](https://wiki.jenkins-ci.org/display/JENKINS/Docker+Plugin).
- Environment replacement was formalized in Docker 1.3, and the new
  behavior ["will be
  preserved"](https://docs.docker.com/reference/builder/#environment-replacement).

Image creation and maintenance
==============================

This is about [[!tails_ticket 7533]]. That's Docker's equivalent of
Vagrant's basebox.

The semi-official Debian images' creation process has been [described by Joey
Hess](http://joeyh.name/blog/entry/docker_run_debian/). They are built
with <https://github.com/tianon/docker-brew-debian.git>, which itself
uses
[`mkimage.sh`](https://github.com/docker/docker/blob/master/contrib/mkimage.sh).
There are `rootfs.tar.xz` files in the former repository.

But there are other solutions around there that feel saner:

* Jonathan Dowland has [documented](http://jmtd.net/log/debian_docker/)
  and [published](https://github.com/jmtd/debian-docker/) the scripts he
  uses to build his own Debian images from scratch, which feels saner.
* The [[!debwiki Cloud/CreateDockerImage]] Debian wiki page documents
  how to use only stuff shipped in Debian to create a Debian image with
  a single command.

See also <https://docs.docker.com/articles/baseimages/>.

Do we want to:

1. Let the build system build and maintain its own images on the
   developer's system, the same way we would do it if we were
   publishing our images? => no, because it may introduce subtle
   discrepancies and at the very least, it'll make reproducible builds
   harder
1. Produce and publish these images automatically
   * e.g. daily or weekly? => no
   * once or twice per release?
1. Build them locally and then upload? If so, who would do it, and
   when? => we'll start with building locally (RM to start with)
   and upload.

Do something different for our base images (e.g. Debian Wheezy)
from we do for the specialized containers (e.g. ISO builder)?

Update frequency: OK to force devs to d/l ~300MB every ~3 weeks, not
OK if every week.

To start with, let's keep things as simple as possible: e.g.
no incremental upgrades.

The build system must by default abort if the base image being used is
not the exact version that shall be used during this release cycle, at
least when building an ISO meant to be published (or trying to rebuild
an already published ISO). One must be enabled to override that check,
e.g. for offline building.

Image publication
=================

By default, Docker downloads images from the [Docker Hub
Registry](https://registry.hub.docker.com/). If we want to publish our
images, of course we want to self-host them somehow.

One can [run their own
registry](https://github.com/docker/docker-registry):

 * [specs](https://docs.docker.com/reference/api/hub_registry_spec/)

Or, one can use `docker save` an image or `docker export` a container,
and then use `docker load` or `docker import`. `save/load` are about
images, while `export/import` are about containers.

XXX: how to verify downloaded images?

We'll just serve our images over HTTP from lizard's web server.

Random notes
============

* Since Docker 0.9, the default execution environment is libcontainer,
  instead of LXC. It now supports e.g. systemd-nspawn, libvirt-lxc,
  libvirt-sandbox, qemu/kvm, in addition to LXC.
* Docker seems to support sharing a directory between the host and
  a container, so on this front, we would not lose anything compared
  to Vagrant.
* Docker supports Linux and OSX.
* According to
  <https://stackoverflow.com/questions/17989306/what-does-docker-add-to-just-plain-lxc>,
  Docker comes with tools to automatically build a container from
  source, version it, and upgrade it incrementally.
* Michael Prokop [gives
  pointers](http://michael-prokop.at/blog/2014/07/23/book-review-the-docker-book/)
  about Docker integration with Jenkins.
* As far as our build system is concerned, we don't care much to
  protect the host system from the build container. The main goal is
  to produce a reliable build environment.
* For security info about Linux containers in general, see the
  [[dedicated blueprint|blueprint/Linux_containers]].
* [overclockix](https://github.com/mbentley/overclockix) uses
  live-build and provides a Dockerfile for easier building.
* overlayfs support was added in Docker 1.4.0; we'll need that when
  using Debian Stretch/sid once Linux 3.18 lands in there after
  Jessie is released.

Test run
========

(20150120, Debian sid host, `feature/7530-docker` Git branch)

	sudo apt --no-install-recommends install docker.io aufs-tools
	sudo adduser "$(whoami)" docker
	su - "$(whoami)"
	make

* `TAILS_BUILD_OPTIONS="noproxy"` => run [apt-cacher-ng in a different
  container](https://docs.docker.com/examples/apt-cacher-ng/);
  - [Linking these containers
    together](https://docs.docker.com/userguide/dockerlinks/) would
    allow to expose apt-cacher-ng's port only to our build container;
    OTOH some of us will want to use the same apt-cacher-ng instance for
    other use cases
  - Docker now has [container
    groups](https://github.com/docker/docker/issues/9694), called
    [Docker compose](https://docs.docker.com/compose/) (now in Debian sid),
    that is apparently [Fig](http://www.fig.sh/) rebranded
    and better integrated; there's also
    [crane](https://github.com/michaelsauter/crane)
  - We can build our own similar thing in our own `Makefile`.
  - We can run both `apt-cacher-ng` and the build system in the same
    container, using some init system and happily violating Docker's
    preferred one-app-per-container philosophy.
    * Running Jessie's systemd inside an _unprivileged_ Docker
      container is doable too: it simply requires passing `-v
      /sys/fs/cgroup:/sys/fs/cgroup:ro` to `docker run`. However, our
      build system can't do what it needs inside an unprivileged
      container (see below) => we'll have to run
      a privileged container.
    * Jessie's systemd works fine inside a _privileged_ Docker
      container -- the list of units needs to be cleaned up a lot
      though, since otherwise it e.g. changes the host system's
      keyboard layout etc.; see e.g.
      <https://github.com/maci0/docker-systemd-unpriv/blob/master/Dockerfile>
    * There are alternatives, like `supervisord`. Pros: likely less
      tweaking to do. Cons: yet another tool to learn.
    * See [[!debpkg systemd-docker]]: wrapper for "docker run" to handle systemd quirks
* Even with `--cache false`, some directories (`chroot`, `cache`) are
  saved and retrieved from the container upon shutdown; same for
  live-config -generated `config/*` files. That's because the current
  directory is shared read-write with the container somehow.
  This bind-mount should be read-only, but we still need to get the
  build artifacts back on the host:
  - see [Managing data in
    containers](https://docs.docker.com/userguide/dockervolumes/)
  - use `VOLUME` to share (read-write) the place where the build
    artifacts shall be copied
* We're currently using the `debian:wheezy` template, that likely we
  should not trust. How should we build, maintain, publish and use
  our own? That's [[!tails_ticket 7533]].
* Being in the `docker` group is basically equivalent to having full
  root access. We should instead encourage contributors
  to run `docker` commands with `sudo`, or to use Docker in
  a virtual machine.
* We currently pass `--privileged` to `docker run`. We can't remove
  it, since `debootstrap` (used by our build system) itself needs to
  run privileged. So we need to:
  1. make it extra clear to potential users of our build system that
     we are _not_ using Docker for security; if they want more
     isolation, then they must run Docker inside a dedicated VM;
  2. ensure that our build system doesn't affect the host system,
     as much as possible; e.g. we could try dropping as many Linux
     capabilities as we can, or run unprivileged and add only the
     capabilities we need.
* Adding `.git` to the `.dockerignore` file would speed up the build,
  but some code in our build process wants to know what branch or
  commit we're building from => maybe we could pre-compute this
  information, and pass it to the build command in some way?
* What execution environment do we want to support? Only LXC
  via libcontainer? Any usecase for e.g. the systemd- or
  libvirt-based ones?
* Move more stuff from `Makefile` to `Dockerfile`? E.g. `DOCKER_MOUNT`
  could be specified as `VOLUME`. Can we specify the build command as
  `CMD`?
* aufs vs. overlayfs
