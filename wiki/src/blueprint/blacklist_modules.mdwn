[[!toc levels=2]]

Debian ships a long list of modules for wide support of devices, filesystems, protocols. Some of these modules have a pretty bad security track record, and some of those are simply not used by most of our users. 

Other distributions like Ubuntu[1] and Fedora[2] already ship a blacklist for various network protocols which aren't much in use by users and have a poor security track record.
Corresponding tickets:

* [[!tails_ticket 7575]]
* [[!tails_ticket 6457]]

Modules to blacklist
====================

* ax25: ([[!wikipedia AX.25]]) amateur radio. Kernel module to work with amateur radio. Has had numerous vulnerabilities in the past. CVE's: CVE-2009-2909/CVE-2013-3223/. Indirect: CVE-2014-1446

Modules to remove
=================

* ipx: ([[!wikipedia Internetwork_Packet_Exchange]]) Primarily used on Novell Netware networks and popular in the 90's. Little networks make use of IPX if any. CVE-2013-7268.
* appletalk: [[!wikipedia AppleTalk]], unsupported in OS X since 2009. CVE's: CVE-2013-7267/CVE-2009-2903/CVE-2007-1357
* psnap: ([[!wikipedia Subnetwork_Access_Protocol]] Relies on the ipx module, obscure and not used much.
* rose: (network protocol derived from X.25) **FIXME: explanation**
* p8023: [[!wikipedia Ethernet_frame#Novell_raw_IEEE_802.3]], was used by Novel NetWare until the mid-nineties. Relies on the ipx module.
* llc: (ANSI/IEEE 802.2 LLC type 2 Support, [[!wikipedia IEEE_802.2]] **FIXME: explanation**
* p8022: [[!wikipedia IEEE_802.2]] **FIXME: explanation**
* decnet: The Linux DECnet Network Protocol FIXME: explanation
* econet: FIXME: explanation
* netrom: The amateur radio NET/ROM network and transport layer protocol FIXME: explanation
* af_802154: [[!wikipedia IEEE_802.15.4]] Kernel module to make low-power, low-rate network standard possible.

[1] https://wiki.ubuntu.com/Security/Features#blacklist-rare-net
[2] https://fedoraproject.org/wiki/Security_Features_Matrix#Blacklist_Rare_Protocols
