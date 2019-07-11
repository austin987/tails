[[!toc levels=1]]

# Rationale: why the shell is bad

* That we need to `set -u` at all.

* Variables are in the global scope by default (thank `$DEITY` for
  `local`, though).

* Shell substitution is hard to get right for anything
  non-trivial. Relatedly, whitespaces + paths = unholy mess.

* `set -e` is generally a good idea, but too abrupt, and awkward to
  temporarily disable when error is a possibility. And if you happen
  to source something that does `set -e` when it's temporarily
  disabled, it becomes globally enabled again.

* No native list/array datatype.

* Sub-shell scoping offers some unpleasant surprises.

* Did you remember to `set -o pipefail` when using pipes with `set
  -e`?

* ...

# Which scripts to convert

Our shell scripts live primarily in:

* `config/binary_local-hooks/`
* `config/chroot_local-hooks/`
* `config/chroot_local-includes/usr/local/bin/`
* `config/chroot_local-includes/usr/local/lib/`
* `config/chroot_local-includes/usr/local/lib/tails-shell-library/`
* `config/chroot_local-includes/usr/local/sbin/`

We do not need to convert all of them, but if a script gets longer
than, say, 30 lines it is starting to get relevant. Or if you deal
with lists of data that is not defined inside the scripts. Or need to
do any error handling beyond "die abruptly".

# Guidelines

* Let's use Python3.

* Read the documentation of the following modules carefully:
  - [`sh` module documentation](http://amoffat.github.io/sh/)
  - [`os`](https://docs.python.org/3/library/os.html)
  - [`shutil`](https://docs.python.org/3/library/shutil.html)

* Refactor reusable code into `submodules/pythonlib/tailslib/`.

Also make sure to look into the `feature/6452-python-scripting` branch
for some inspiration.

# Tips and tricks

* If you cannot build Tails, you can download a
  [nightly build of the development branch](http://nightly.tails.boum.org/build_Tails_ISO_feature-11198-python-scripting/lastSuccessful/archive/build-artifacts/),
  which contains the minimum Python dependencies required for this
  conversion project (e.g. the `sh` and `tailslib` modules), so you
  can test your work.

* You can test your work even more efficiently when running Tails in a
  VM while sharing your Tails source tree to the VM (e.g. via VM
  filesystem shares, or `sshfs`) so you can execute the scripts in it
  after saving your changed on the host. When other scripts call your
  target script, just symlink it into the expected location.
