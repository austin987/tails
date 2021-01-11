[[!meta title="Restructure our support page"]]

Parent ticket: [[!tails_ticket 15130]]

Current problems
================

- Some support channels are put forward too much and might not be
  helpful for the average user seeking help (training organization,
Redmine, feature request)

- The difference between our different support content is not clear
  enough (known issues, documentation, FAQ).

  During the expert review ([[!tails_ticket 14548]]), the person would
  have gone to:

    1. FAQ: which wouldn't help
    2. Chat: which would have been very complicated to setup and might
       not have helped
    3. Email: which would have helped

  But she should instead have been pointed to:

    - Better troubleshooting instructions for Mac
    - Known issues on Mac hardware

- Our support page is a hub that points to other support content but
  currently the user has to change page and scan each one of them.
  Instead our support page should help people know which support content
  will solve their issue, without trial and error.

- Some requests are very frequent on our help desk (and they change over
  time). Our support page should help filter these frequent issues
quickly.

- Issues for the current release are only listed in the release notes,
  which is probably not where people facing these issues would look for.

Ideas
=====

- Restructure the page to help differently people who either cannot
  start Tails or are in Tails already.

  - Split [[!tails_gitweb wiki/src/support/known_issues.mdwn]] into two:

    - Issues that prevent Tails from starting: [[!tails_gitweb
      wiki/src/support/known_issues/starting.mdwn]] [1]
    - Issues that don't: [[!tails_gitweb
      wiki/src/support/known_issues.mdwn]] [2]
    - Cross-reference these two pages

Troubles starting Tails
-----------------------

- Create a page dedicated to issues starting Tails and link it from
  [[!tails_gitweb wiki/src/support.mdwn]] and
  [[!tails_gitweb wiki/doc/first_steps/bug_reporting.mdwn]]:

  - Inline troubleshooting sections from the installation instructions
  - List or inline known issues that prevent Tails from starting [1]

Troubles inside Tails
---------------------

- Improve a bit the upgrade instructions "*Make sure you are using the
  latest version*".
  
  Like we're doing on [[!tails_gitweb
  wiki/src/install/inc/steps/verify_up-to-date.inline.mdwn]]

- List hot topics on help desk

  The help desk could maintain a list of the most popular issues
  reported, for example updating it after each shift (two weeks).

  This list would be:

  - Inlined on the support page
  - Copied in the monthly reports

- Inline issues from latest release

  We could have inline files listing issues for each release.

  For example: [[!tails_gitweb
  wiki/src/news/version_3.3/issues.inline.mdwn]]

  This file would be inlined from both:
    - The support page
    - The release notes for this version

  When writing the release notes for a new version:

    1. Review the issues from the latest version and see if they are
       still relevant.
    2. Create an empty file for the next version, copying parts from the
       previous version whenever relevant.
    3. Update /support to inline the file for the next version.
       
- List or point to known issues that don't prevent Tails from starting [2]

- Embed more information about the documentation in the support page

  We could reuse the index pages that we already have for the different
  documentation sections ([[!tails_gitweb
  wiki/src/doc/first_steps.index.mdwn]]) and display them in accordions
  (toggles).

  See how Chrome does that:
  <https://support.google.com/chrome/?topic=7438008>

* Link to FAQ after documentation and explain what kind of information
  is in there

  Our FAQ almost exclusively contains general interest questions that
  are not about how to start Tails or issues affecting Tails.
  All-in-all, they should be way less relevant to people visit the
  support page than our known issues and documentation.

Contact and misc
----------------

- Decide what to do with training organizations

  Ask the organizations if they are being contacted for support and, if
  so, find out what issues are being reported.

- Rephrase and restructure Redmine and feature requests for a technical audience only

  The support page currently refers users to Redmine to find out if an
  issue is already known which is probably a dead end for less technical
  users.

- Advertise "Report an error" as a option to contact us

  Right now, it is advertised outside of the ways to "get in touch with
  us".

  Could we go even further and say that people who cannot start Tails
  should write us an email and people who can start Tails should send us
  a WhisperBack report?

- Remove the instructions to connect to the chat

  There is very little happening on the chat actually. Very few users
  with a good understanding of Tails help others. Most core Tails people
  connect either rarely or never.

  Make it less visible until it's easy to connect and get answers?

Next steps
==========

* Ask feedback from:
  - Help desk
  - Expert who did the review
  - Release managers
* Create wireframes of the final page
* Organize incremental work to implement all this
