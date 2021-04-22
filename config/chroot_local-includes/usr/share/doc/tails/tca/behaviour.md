What does TCA do?
====================

The main workflow is simple: open, forward, forward, done!

Here you'll find explaination for corner cases such as re-opening TCA, changing network, etc.

Network unplugged
-------------------

Here "unplugged" is short for NetworkManager.state < 60

If you start TCA with network unplugged, TCA will present an error message explaining that you have no local
network.

If you unplug the network *while* using TCA, TCA won't complain, except at the final screen: if you are
looking at the final screen, and the network is unplugged, you'll be presented with the error message.

No Internet
---------------

If you are connected to a network with no internet, TCA won't complain, but of course it cannot connect.

If you open it with a good connection, complete the wizard, then move to a network with no internet, TCA will
not complain.

Close TCA and open again
---------------------------

If status/circuit-established=1 → Success page

Else, it will show the consent question.
