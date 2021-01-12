[[!meta title="User survey"]]

[[!tails_ticket 14545]]

[[!toc levels=3]]

Past surveys
============

[[!map pages="user_survey/*" show="title"]]

Future surveys
==============

Research questions
------------------

### Size of user base

- How many users do we really have?

  Right now we only have number of boots per day but combining this
  with how frequently people use Tails, we could extrapolate rough
  number of users and maybe usage categories (fraction of frequent
  users and occasional users, etc.).

### Technical skills

- How technically skilled are our users?
- How big is the difference between the technical skills of our target
  audience and real audience?
- Is there a match between how hard Tails is to use and the skills of
  our actual users?

### Region

- Is Tails useful and accessible by a global audience?

- Information on where Tails is used the most is very helpful for
  fundraising, outreach, or translation efforts.

### Current features

- What are people using Tails the most?

  This would help us clarify what are the most important features of
  Tails and prioritize incremental improvements.

### New features

- How shall we prioritize our future plans?

- What is missing the most in Tails?

  This would help us build a better roadmap.

### OpenPGP

- How many users use OpenPGP mostly to verify downloads?

- How many users use KeePassX to type their OpenPGP passphrase? ([[!tails_ticket 17867]])

### Upgrades

We used to have quantitative data on which versions our users were
running but we lost this in 4.2. ([[!tails_ticket 17545]])

In April 2019, 10 days after 3.13:

- 28.7% of users were using an outdated version
- 5.3% of users were using a version that was between 6 and 12 months old
- 4.1% of users were using a version that was more than 12 months old
- 1.6% of users were stuck with 3.5, which was 14 months old and the last forced manual upgrade

See the [detailed analysis](https://gitlab.tails.boum.org/tails/ux/-/raw/master/upgrades/april-2019.ods).

What user research could we do to complete this quantitative data?

What we already have:

- Qualitative info here and there about upgrades being painful

  - [[Roberto, October 2019|contribute/how/user_experience/interviews/roberto]]:

    > More than anything, they are upgrades constantly. Sometimes it takes us a
    > whole day to do an upgrade and then there's another one the week after. I
    > could do some parts of it but not everything.

    > Each time there's an upgrade we have to do a backup, I'm not sure if
    > that's for security or for technical reasons. GlobaLeaks also have expiring
    > GPG keys and we have to make sure that the GPG keys match or otherwise I
    > could loose files.

  - [[Joana and Orlando, January 2018|contribute/how/user_experience/interviews/joana_orlando]]:

    > Joana once had problems with upgrade on a USB stick. She could do the
    > first two upgrade but then it was not possible to do the third one.

  - [[Claudia and Felix, January 2018|contribute/how/user_experience/interviews/claudia_felix]]:

    > The first year Tails worked very well. But then they started
    > having more problems when the upgrades started.

    > Several time, their Tails stopped working because of an upgrade.
    > In such cases they would get help from another organization
    > collaborating with the whistleblowing platform which has more
    > technical staff. Right now for example, their Tails has been
    > broken since December and is being fixed by them.

    > One of their Tails was so old that it was impossible to upgrade
    > it. Felix installed a new Tails and copied the cryptographic key
    > to the whistleblowing platform manually.

  - [[Isabella, May 2017|contribute/how/user_experience/interviews/helen]]:

    > Upgrades are painful when using Tails not so often.

  - [[Ernesto, March 2017|contribute/how/user_experience/interviews/ernesto]]:

    > The fact the upgrade mechanism is sometimes automatic and sometimes
    > manual. You never know what to expect.

  - [[Helen, March 2017|contribute/how/user_experience/interviews/helen]]:

    > She likes the automatic upgrades in general but she always have to go
    > back to the documentation when the upgrade fails. As part of her work, she
    > also sometimes sees infrequent users struggling with accumulated upgrades
    > (for example upgrading from 2.6 to 2.10).

- Top 5 hot topic in [OpenPGP and Pidgin
  survey](https://tails.boum.org/user_survey/openpgp_and_pidgin/#index3h2)

  - 5 comments were about simpler and easier upgrades without specifying
  - 4 comments were directly complaining about manual upgrades and asking for always going automatic upgrades
  - 2 comments were about faster upgrades
  - 1 comment was about less frequent upgrades

We could also research:

- What makes people skip or delay upgrades?

- Ask questions about upgrades in a survey and follow up with a few interviews.

- What are the biggest pain points in upgrade?

- Are there any other technical problems that we are not aware of, eg.
  download reliability?

### Backups

- Could selling online backups be a business model?

Survey questions
----------------

- **In which region of the world do you use Tails the most?**

  Single choice:

  * North America
  * Latin America and the Caribbeans
  * Western, Northern, and Southern Europe
  * Eastern Europe and Central Asia
  * Middle-East and North Africa
  * Western, Eastern, Central, and Southern Africa
  * South Asia
  * East and Southeast Asia
  * Oceania

- **Other than Tails, which of the following operating systems do you use the most?** (`*`)

  Single choice:

  - Windows
  - macOS
  - Linux

- **Which of the following tasks are the most important to you when using Tails?** (`*`)

  Pick n/10:

  * Chat on IRC
  * Chat on XMPP/Jabber
  * Read and write email in Tor Browser
  * Read and write emails using Thunderbird
  * Read Atom and RSS feeds using Thunderbird
  * Share file using OnionShare
  * Exchange bitcoins using Electrum
  * Use encrypted storage devices other than the Persistent Storage
  * Encrypt and decrypt PGP messages using Thunderbird
  * Encrypt and decrypt PGP messages outside of Thunderbird
  * Delete files securely
  * Manage passwords using KeePassXC
  * Create or edit office documents
  * Create or edit images
  * Create or edit audio files
  * Create or edit video
  * Print documents on paper
  * Access the internal hard disk of the computer
  * Publish content on the web anonymously
  * Connect to remote servers using SSH
  * Use somebody else's computer
  * Avoid viruses and spyware on my own computer
  * Store sensitive documents in the Persistent Storage
  * Clean metadata on images, video, or document
  * Use the command line
  * Change the security level of Tor Browser
  * Check the circuit view of Tor Browser
  * Clone the current Tails to another USB stick using Tails Installer
  * Other: Short free text

  Discarded:

  * Use Tor bridges or pluggable transports
  * Manage a social media account or a blog under a different identity (but not anonymously)
  * Participate in online communities (forums, chat, etc.) anonymously or under a different identity
  * Use the Unsafe Browser to log in to a captive portal

- **What are your main reasons to use Tails?**

  Single choice:

A. I want to hide information about myself
B. I want to communicate and collaborate securely
C. I want to store information safely
D. I want to leave no trace on the computer
E. I want information to be free
F. I don't want my data to be gathered by corporations and governments

  Personas:

→ Access or publish sensitive or censored information (Riou)
    Access censored information online
    Publish sensitive information
    Access sensitive information
    Store, edit, and anonymize sensitive data
→ Hide information to people around me (Kim)
    Hide information from their family
    Hide their identity
    Avoid raising suspicion
    I want to keep information secret from my family and close people
    I don't want to raise suspicion
→ Avoid government and corporate mass surveillance online (Derya)
    I just want more privacy
    I want to keep information secret from my government
    Avoid corporate and government surveillance
→ Communicate or collaborate with others (Cris)
    Work with others who are surveilled or at risk
    Communicate with known and unknown peers
    Share and work on documents with others
    I want to communicate with others who are under surveillance
→ Have a more secure computer
    Use a computer that is not mine
    Use an untrusted computer
    I need to use a computer that is not mine

    I want to access sensitive information stealthily
    I want to hide my identity
    I want to hide my location
    I want to communicate securely with known peers
    I want to communicate securely with unknown peers
    We want to share and work on documents privately
    I need to safely store my data
    I want to edit or anonymize my data

→ Don't

    Help others access censored information
    Understand people using privacy tools
    I want to understand people using Tails

- **New features**

  Ranking:

- **Overall, how difficult or easy is it for you to use Tails?**

  [Single Ease Question](https://measuringu.com/seq10/)

- **Tails' capabilities meet my requirements.**

- **Tails is easy to use.**

  [UMUX-Lite](https://measuringu.com/umux-lite/)

- **What one things would you improve on our website?**

  Short text:

Resources
=========

- [MeasuringU: How to Conduct a Top Task Analysis](https://measuringu.com/top-tasks/)
- [MeasuringU: 12 Tips For Writing Better Survey Questions](https://measuringu.com/survey-questions/)
- [MeasuringU: 10 Tips For Your Next Survey](https://measuringu.com/survey-tips/)
- [Don A. Dillman et al., Internet, Phone, Mail, and Mixed-Mode Surveys](https://b-ok.cc/book/2735848/c2722f)
- [Norman M. Bradburn et al, Asking Questions: The Definitive Guide to Questionnaire Design](https://b-ok.cc/book/736405/94a5b9)
