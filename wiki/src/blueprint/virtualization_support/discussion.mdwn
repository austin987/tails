We need to discuss whether we want to support,
either actively or passively:

* kvm, qemu, VirtualBox?

> definitely yes

** A prepackaged Tails portable QEMU/whatever

* VMWare?

> trying to be pragmatical w.r.t. to user expectations. Given the
> statistics of which VMs are most common (VMWare wins) it seems
> likely that many people that will run amnesia in a VM are users of
> vmware => let's support it

>> OK --intrigeri

* amnesia as a guest inside Windows (low-security context, not always
  possible to do better)?

> it's better to make it easy to use amnesia inside {qemu, virtualbox}
> on a locked-down public computer, rather than using the Internet
> Explorer installed on this computer. Let's support running amnesia
> on Windows, then, **but** tell users, when running inside a VM,
> that they are implicitly trusting both the VM software *and* the
> host OS. This is needed to avoid creating a false sense of security,
> which is often quite worse as no security and a clear sense of it.

>> This has been implemented.
