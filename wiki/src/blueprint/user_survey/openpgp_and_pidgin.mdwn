[[!meta title="OpenPGP and Pidgin survey"]]

[[!toc levels=3]]

- GitLab issue: [[!tails_ticket 17821]]
- Advertised on [[Home]] from 2020-07-18 to 2020-08-13
- 924 full responses, 851 valid responses
- Conversion rate 2.2%

Research questions and results
==============================

## OpenPGP support outside of Thunderbird ([[!tails_ticket 8310]], [[!tails_ticket 17183]], [[!tails_ticket 17169]])

This will become an even hotter topic once Enigmail goes away in a few months:
Thunderbird will maintain its own keyring, independently from GnuPG's ⇒
Seahorse will stop being useful for anything related to email, so the
cost/benefit of vaguely supporting it will become even higher.

- **How popular is OpenPGP inside and outside Thunderbird?**

  OpenPGP is much more popular outside Thunderbird than inside
  Thunderbird:

  - 16% of our users use OpenPGP inside Thunderbird.
  - 49% of our users use OpenPGP outside Thunderbird.

- **How technical are the people using OpenPGP outside Thunderbird?**

  People using OpenPGP outside Thunderbird are slightly less technical
  that people using OpenPGP inside Thunderbird:

  - Enigmail users use mostly Linux significantly more than non-Enigmail
    users: 62% vs. 50%.
  - Enigmail users use the command line slightly more than non-Enigmail
    users: 62% vs. 56%.
  - The most popular OpenPGP tools are Nautilus (41%), Seahorse (37%),
    and the applet (34%).
  - OpenPGP users use mostly Linux slightly more than our users in
    general: 54% vs. 49%.

- **Could these people use Thunderbird instead?**

  No.

  - 33% of our users use OpenPGP only outside Thunderbird.
  - 15% of our users use OpenPGP mostly to communicate using a website.
  - 16% of our users use OpenPGP mostly to communicate by email, which
    is the same fraction as the number of Enigmail users.

- **Who will suffer from the Thunderbird migration because they use
  OpenPGP both inside and outside Thunderbird?**

  Almost all our Enigmail users:

  - 1% of our users only use OpenPGP inside Thunderbird.
  - 16% of our users use OpenPGP both inside and outside Thunderbird.
  - 55% of Enigmail users use OpenPGP mostly to communicate by email.
  - 16% of Enigmail users use OpenPGP mostly to communicate using a
    website.

## Can we stop including an IRC client by default? (#15816)

This open question has been the main blocker for replacing Pidgin for years.

- **What would be the cost of removing the support for IRC by default in Tails?**

  The cost would be way less than breaking Electrum or Seahorse:

  - 8% of our users use IRC in Pidgin.
  - 28% of our users use Electrum.
  - 37% of our users use Seahorse.

  We should provide an alternative, otherwise the noise might be similar
  to dropping 32-bit computers (4%), though the concrete impact is very
  different for people. IRC users are also use Electrum much more than
  our users in general: 51% vs. 28%.

- **How technical are the people using IRC in Tails?**

  IRC users are much more technical than our users in general:

  - IRC users use mostly Linux significantly more than our users in
    general: 63% vs. 49%.
  - IRC users use OpenPGP a lot more than our users in general: 91% vs.
    50%.
  - IRC users use the command line a lot more than our OpenPGP users in
    general: 91% vs. 58%.

- **Are people using IRC in Tails to connect to servers that do not block Tor?**

  The most popular IRC servers are:

  - Freenode: 52%
  - Private IRC servers: 43%
  - IRCnet: 34%
  - OFTC: 10%
  - EFnet: 10%
  - Undernet: 7%

  I didn't check how much these servers block Tor.

  - The Tor project has a [list of IRC/chat networks that block or support Tor](https://trac.torproject.org/projects/tor/wiki/doc/BlockingIrc)

- **How popular is XMPP among our users?**

  A little bit more than Enigmail:

  - 16% of our users use Enigmail.
  - 17% of our users use XMPP in Pidgin.
  - 58% of our Pidgin users use only XMPP.
  - 92% of our Pidgin users use XMPP and IRC.

## General purpose questions

- **How technical is our current user base and how easy is it for them to use Tails?**

  Linux users are still the biggest share of our user base, which hasn't
  changed much since 2017.

  | OS | |
  |--|
  | Windows | 45% |
  | macOS | 7% |
  | Linux | 49% |

  Our current user base finds Tails relatively easy to use.

  Tails scored 5.9 on the *Single Ease Question* among respondents.
  A reference average for this *Single Ease Question* is
  [5.5](https://measuringu.com/seq10/), so we're doing pretty good!

- **Which applications are used the most in Tails?**

  Fraction of users that reported using a given application (at least sometimes).

  | Application | Total |
  |--|
  | Tor Browser | 100% |
  | OpenPGP | 50% |
  | Electrum | 28% |
  | Thunderbird | 27% |
  | OnionShare | 27% |
  | Pidgin | 19% |

- **What are the top requests of our current user base?**

  The top 5 priorities of our users are, in rough order:

  1. The single most frequent comment is to do nothing because Tails is
     great already :)

  2. More persistent settings

     - Security level and NoScript settings in Tor Browser
     - Background
     - Keyboard and language

  3. Messaging applications and voice calls

     Signal was the most mentioned as it also allows voice calls.

  4. Tor is painful for web browsing

     People complain about websites blocking Tor and captchas. I bet
     that's why people ask so much for VPN and use the Unsafe Browser
     whenever Tor Browser doesn't work.

  5. Better upgrades

Methodology
===========

## Prompt

[[!img openpgp_and_pidgin.png link="no" alt=""]]

## Questions

- **Overall, how difficult or easy is it for you to use Tails?** (`*`)

  7-point scale from *Very Difficult* to *Very Easy*

  | OS | Average |
  |--|
  | All | 5.9 |
  | Windows | 5.8 |
  | macOS | 5.9 |
  | Linux | 6.0 |

- **If you could change just one thing in Tails, what would it be?**

  Short text:

  I coded the answer and extracted the themes that were mentioned more
  than once.

  - More persistent settings (57)

        16 Persist Tor Browser preferences (security level, NoScript, etc.)
        15 Persist background
        11 Persist keyboard and language
         9 Persist more settings
         4 Persist Tor settings
         2 Easier Persistent Storage

  - Nothing (53)

        53 Nothing

  - Messaging applications and voice calls (38)

        11 Messaging
        10 Voice calls (including Signal for voice calls)
         7 Signal
         7 Omemo
         3 Telegram

  - Tor is painful for web browsing (39)

        19 VPN
         6 Faster Tor
         5 Websites blocking Tor
         4 Download from Unsafe Browser
         3 Sound in Unsafe Browser
         2 Private Unsafe Browser

  - Better upgrades (25)

  - Improvements to Tor Browser (22)

        10 Safest by default (overlaps with persisting preferences)
         4 NoScript in taskbar
         3 Prevent maximizing Tor Browser
         3 Full browser screenshot
         2 Remove letterboxing

  - Network connection (21)

        10 Bridges (easier, more reliable, and by default)
         7 Better circuit view or control
         4 Network connection

  - More cryptocurrencies (18)

        16 Monero
         2 Other cryptos

  - Additional Software (16)

        11 Additional Software (easier, persist config, more choice, etc.)
         5 Package manager

  - Application launching (7)

         3 Favorites (different or custom)
         2 Better Applications menu
         2 Launchers on the desktop

  - More tools

         6 Video editing
         4 Better media player
         3 More tools in general
         3 Video download
         2 Scribus
         2 MAT GUI
         2 GPT-3
         2 BitTorrent
         2 Ability to play CDs

  - Tech trolling

        17 Replace GNOME
         4 Whonix design with VMs
         3 Spoof entire MAC
         2 Replace systemd

  - Hardware support

         5 Wi-Fi support
         3 Booting is hard
         2 Mac hardware
         2 Mobile
         2 Tablet

  - Misc

        13 VeraCrypt (creation of volumes)
        10 Disk install
         9 More documentation
         8 OpenPGP
         7 toram
         5 Dark theme
         4 Freeze
         4 Faster boot
         3 Windows camouflage
         3 Smaller OS
         3 Clock display
         3 Backups
         2 U2F keys
         2 Confirm before shutdown
         2 Disable camera and microphone
         2 Change entry guard

- **How often, if at all, do you use the following tools in Tails?** (`*`)

  | Application | Sometimes | Most of the time | Total |
  |--|
  | Tor Browser | 3% | 97% | 100% |
  | OpenPGP | 24% | 26% | 50% |
  | Electrum | 16% | 12% | 28% |
  | Thunderbird | 17% | 10% | 27% |
  | OnionShare | 22% | 5% | 27% |
  | Pidgin | 13% | 6% | 19% |

- **Other than Tails, which of the following operating systems do you use the most?**

  | OS | |
  |--|
  | Windows | 45% |
  | macOS | 7% |
  | Linux | 49% |

  These results are very similar to the one from the VeraCrypt surveys.
  The question was asked differently so I don't think that we can
  compare them in details.

### Conditional questions on OpenPGP

- **How often, if at all, do you use the following tools for OpenPGP in Tails?** (`*`)

  Randomized array

| | Never | Sometimes | Most of the time | Don't know |
|--|--|--|--|
| The `gpg` command line [[!img doc/first_steps/introduction_to_gnome_and_the_tails_desktop/utilities-terminal.png size="22x22" link="no"]] | 20% | 19% | 10% | 2% |
| *Enigmail* in *Thunderbird* [[!img doc/first_steps/persistence/thunderbird.png size="22x22" link="no"]] | 32% | 10% | 6% | 1% |
| The OpenPGP applet in the top bar [[!img doc/encryption_and_privacy/gpgapplet/gpgapplet_with_text.png size="22x22" link="no"]] | 14% | 15% | 20% | 1% |
| The *Passwords and Keys* utility [[!img doc/first_steps/introduction_to_gnome_and_the_tails_desktop/seahorse.png size="22x22" link="no"]] | 12% | 19% | 18% | 1% |
| The *Files* browser [[!img doc/first_steps/introduction_to_gnome_and_the_tails_desktop/files.png size="22x22" link="no"]] | 8% | 15% | 25% | 1% |
| The *Archive* manager [[!img doc/first_steps/introduction_to_gnome_and_the_tails_desktop/file-roller.png size="22x22" link="no"]] | 22% | 17% | 8% | 3% |

- **Which other tool, if any, do you use for OpenPGP in Tails?**

  Short text

- **Which of the following options describe the best what you use OpenPGP for?**

  Single choice

  * Exchanging encrypted messages or files by email
  * Exchanging encrypted messages or files using a website
  * Exchanging encrypted messages or files using an external device
  * Encrypting text or files for myself
  * Other:

### Conditional questions on Pidgin

- **How often, if at all, do you use Pidgin in Tails to connect to XMPP (also called Jabber) servers?**

  *To see if your accounts use XMPP/Jabber, choose Accounts → Manage Accounts in Pidgin.*

  Single choice

  * Never: 8%
  * Sometimes: 57%
  * Most of the time: 35%
  * Don't know: 1%
  * No answer

- **How often, if at all, do you use Pidgin in Tails to connect to IRC servers?**

  *To see if your accounts use IRC, choose Accounts → Manage Accounts in Pidgin.*

  Single choice

  * Never: 54%
  * Sometimes: 34%
  * Most of the time: 9%
  * Don't know: 4%
  * No answer

- **How often, if at all, do you use private conversations (also called OTR) in Pidgin in Tails?**

  Single choice

  * Never
  * Sometimes
  * Most of the time
  * Don't know
  * No answer

- **Which IRC servers, if any, do you connect to using Pidgin in Tails?**

  Randomize multiple choice

  * Private IRC servers: 43%
  * Freenode: 52%
  * IRCnet: 34%
  * Undernet: 7%
  * OFTC: 10%
  * EFnet: 10%
  * Leetnet:
  * Other:

  <!-- https://netsplit.de/networks/top10.php -->

### Conditional questions on OpenPGP or Pidgin

- **We might be interested in asking you a few more questions to
  understand better how you use OpenPGP or Pidgin in Tails. If you feel
  like it, you can share your email address with us. We will only use it
  to contact you as part of this research and delete it afterwards.**

  Short text
