# Persistence of custom CAs

This is about [[!tails_ticket 5976]].

Persistence of client certificates and CAs in the browser would make their use a lot easier.

## Problem description

Tor Browser currently ships with a specific bundle of trusted CAs (a).
When websites present their certificates, their signature is checked against the list of trusted CAs.
In some cases, the signature they present has been authored by a CA which is not part of the shipped bundle (a).

Tails users wanting to use such websites need to trust a root CA certificate. This information isn't persisted by default and as such, they need to re-do the operation each time they want to access the website.

## Leads

We've tried to follow different leads, which enable users to persist additional trusted CAs.

### Enabling the persistance of the certdb in Tor Browser

Tor Browser [disables the persistance of intermediate certificates](https://gitweb.torproject.org/tor-browser.git/commit/?h=esr24&id=b8b019f1f6398ceba356aa87699a081cb750ae44), but this is exposed behind a flag, named `security.nocertdb`. By switching it to `false`, the NSS certificate database is persisted and reused between restarts.

The same approach than what's done with bookmarks seems to be working, and we would need to persist the `cert8.db` file (it stores all your security certificate settings and any SSL certificates you have imported into Firefox.)

For later reference, it might be useful to know that it was considered at some point to switch to key4 and cert9, but it never happened for Firefox desktop.

To go this way, a new persistence option needs to be created, to allow the persistence of browser certificates and CAs. It will need to do a bind-mount of the persisted files. This needs to be done in the "live-boot" debian project.

#### Risks / Problems with this approach

Adding trusted CAs to the bundle allows the CA (or anyone with access to the CA root or intermediate certs) to inspect the TLS-encrypted traffic using an active man in the middle attack. As such, adding the option to persist custom trusted CAs makes it easier for attackers to decrypt the traffic between a Tails user and visited website.

Also, adding a trusted CA is also a way to fingerprint the browser by loading resources only available for the users who trust a specific CA.

### Using the "certificate patrol" browser extension

In practice, users facing this problem will likely import the trusted CA when they need it, in their browser. (e.g. they could download and persist the trusted root certificate and then import it in Tor Browser when they need it).

An alternative idea would be to trust the certificate the first time it's seen (TOFU) and then check if the certificate remains the same in the next connections to the website. [Certificate patrol](http://patrol.psyced.org/) does propose a way to compare the certificates when they changed, with indicators to help the user chose if the change is valid or not.

Certificate Patrol exposes a `CertPatrol.sqlite` file, which could be persisted to allow the tracking of certificate changes between Tor Browser uses.

### Using a browser extension to add trusted certificates at startup

Another approach to the former approach is to import the certificates at startup [using a browser extension](https://github.com/moba/cacert-firefox-addon/blob/master/lib/main.js). It exposes the user to the same risks as described in the previous section.

## Current status of the reflexion

We have to decide if we prefer to:

1. Have the users import the root CA themselves, making it harder or them and at the same time less prone to attacks. Document it.
2. Add a persistance option in Tails wich makes it possible to persist new trusted CAs accross restarts

Solution (1) seems to be the best approach as it doesn't require to implement and maintain a custom solution for handling custom trusted CAs.
