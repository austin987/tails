[[!tag archived]]

[[!meta title="Tails keysigning party"]]

1. Download your emails or save this document to local storage: [[tails-keysigning.txt.gz]].

1. If you want, download the set of public keys: [[tails-keysigning.asc]].

1. Turn off all network connections.

1. Decompress that file:

       gunzip tails-keysigning.txt.gz

1. Compute the SHA-256 sum:

       gpg --print-md sha256 tails-keysigning.txt

1. Make sure it starts with the letter 'F'.

1. Wait for everybody to be ready.

1. We confirm the document SHA-256 sum together.

1. Search for your own fingerprint and your own user ids and
   verify that they are indeed what they should be.

1. In the order of the document, we confirm the user id and fingerprint
   information. Each participant physically present will, in turn stand up and
   states:

   - Their name
   - That they have verified their fingerprints
   - That they have verified their user ids

1. Other people in the room who know this person confirm the identity of this
   participant.

1. If you trust what you hear, put an 'x' in the corresponding checkboxes in
   your file.

1. At the end, sign the resulting document with your own key for
   later verification.

       gpg --clearsign tails-keysigning.txt

1. When back home, take your time to sign the keys after verifying that this
   document has not been tampered with, ideally using
   [caff](https://wiki.debian.org/caff).
