[[!toc levels=2]]

Starting point
==============

We have a delta with Debian. Some of it is legit, some of it should be
upstream'ed somehow. It's hard, both for us and for others (Debian
contributors, other derivatives) to make the difference, and to
identify areas that need work.

Back in May, 2014, we have
[explained](https://lists.debian.org/debian-project/2014/05/msg00036.html)
what our current delta was.

Existing data
=============

* <http://deriv.debian.net/Tails/sources.new>:
  - Packages we have that are not Debian.
  - looks at our devel APT suite
  - no room for an explanation
* <http://deriv.debian.net/Tails/sources.patches>:
  - list of deviations from existing Debian packages
  - patches we applied, they are extracted and kept up to date:
    useful, but no room for explanations on why these patches exist

Scripts that generated this data:
<https://wiki.debian.org/Derivatives/Integration#Patches>

Goals
=====

1. Enable anyone to easily find potential action items; that is:
   make it easy to filter what should be ignored ("legit" delta) and
   what should be improved.

2. Visualize the evolution of a given derivative's delta with Debian  
   => detect if the situation is improving or getting out of control  
   => derivatives developers can be happy and proud, or react
   promptly; Debian contributors can evaluate how a given derivative
   is "nice" to Debian.

Ideas
=====

## 1. Have explanations about the delta in each case

Ideally, for *3.0 (quilt)* packages, `compare-source-package-list`
could look into `debian/patches` for derivatives-specific patches,
and retrieve information from
[DEP-3](http://dep.debian.net/deps/dep3/) headers.

For other kinds of packages, it seems that the metadata would need
to be added to some fine in the `debian/` directory, possibly using
the DEP-3 format. This also would be useful to document the delta
of *3.0 (quilt)* packages that is not expressed in
`debian/patches`, e.g. shipping a newer upstream version
than Debian.

Paul Wise
[wants](https://lists.debian.org/CAKTje6EFxUbNj=8eXRM+G8c_QkWaFn=yQ_PJT_ytYQB9+EEgSg@mail.gmail.com)
to "add that to the new tracker.d.o interface and associate it with
the person who logged in, since what people want to see might be
different".

## 2. Generate graphs displaying the evolution of a derivative's delta

This requires adding date/time information to at least
`sources.{new,patches}`, and having some code that generates graphs
out of it. Presumably, once specified properly, this could be a great
task for someone learning programming.

Next steps
==========

* This is being discussed in the [Tracking derivatives delta:
  explanations, history](https://lists.debian.org/85r41tx7k4.fsf@boum.org)
  thread on the debian-derivatives mailing list.
* Action items: [[!tails_ticket 7607]] and subtasks

Misc. ideas
===========

One of the design goals of the new distro-tracker (the thing behind
<https://tracker.debian.org/) is to help "derivatives that want to use
it track/manage their divergence with Debian", [as Raphaël Hertzog
put it](https://mailman.boum.org/pipermail/tails-dev/2014-July/006427.html).
