[[!meta title="Request tracker for help desk"]]

Having a request tracker powering our help desk will be key to fulfilling their
[[updated mission|contribute/working_together/roles/help_desk]]:

**Gather qualitative and quantitative data to understand better our users and
prioritize our work.**

Requirements
============

MUST
----

 - Track easily what's been done and what's left from previous help desk shifts:
   - Make it easy to ensure everything is answered
   - Allow a single person to follow an issue from the beginning to the end
 - Statistics:
   - Know how many users encountered the same issue. Spot the "Top bugs"
   - Be able to have stats on common issues
   - Be able to categorize issues ("tags")
 - Allow building a responsible data retention policy
   - The platform will handle sensitive information (email addresses of
     users, their hardware, their problems, etc.). We'll have to do some
     threat modeling to figure out how to store each piece of
     information and for how long. The platform might have built-in
     capacity for this...
 - Handle incoming and outgoing OpenPGP emails
 - Allow searching in the archive of tickets
   - Plain text search
   - Search on metadata (eg. filter by the version of Tails)
 - Make it easy to forward logs to devs (who might not have a direct
   access to the platform)
 - Provide a separate queue of tickets per language [[!tails_ticket 9080]]
 - Make it easy to onboard new help desk members
 - Keep a database of template answers
 - Allow cross-referencing Redmine tickets and help desk tickets
   - For example, in order to know when a particular issue will be fixed
   - Make it easy to contact the user back when there is a solution
 - Parse automatically at least some metadata from WhisperBack reports
   - We might want to parse automatically all kind of data from
     WhisperBack reports but that might be hard to do (eg. hardware
     information) but the platform should at least parse automatically the
     WhisperBack headers (email address, version number, etc.)

SHOULD
------

 - Keep track of hardware compatibility (Tails works on XYZ, Wi-Fi card XYZ doesn't work)
 - Replace the list of bad users and flag them automatically as nasty
 - Allow users to express whether they were satisfied with our answers

MAY
---

 - As a start we'll aim at creating a tool that's only accessible to
   help desk members (and maybe a few other core contributors) but not
   to members of the Foundations and UX team in general.
   But for the future, the platform might have built-in capacity to
   handle different type of accesses to the data in terms of privacy.
 - Shift management:
   - Replace the calendar of shifts and do something smart about that (send notifications to the person on duty)
   - Automatically clock user support time
 - Allow forwarding issues from and to other user support projects (Tor, Access Now)
 - Have a disposable chat system for tricky cases (Tor does that)

Budgeting
=========

This work is directly related to the work of four of our core team:

- [[Help Desk|contribute/working_together/roles/help_desk]]: they will
  use the platform to do their work.
- [[Foundations
  Team|contribute/working_together/roles/foundations_teams]]: they will
  use the data of the platform to investigate for example hardware
  compatibility issues.
- [[UX Designes|contribute/working_together/roles/ux]]: they will use
  the data of the platform to investigate usability issues and help
  prioritizing our work.
- [[Sysadmins|contribute/working_together/roles/sysadmins]]: they will
  administer the platform.

Making sure that the platform will work for them is part of the core
work of these teams (eg. building the requirements).

But researching implementation options doesn't fit in their scope of
work and should be budgeted apart. This work could either be:

- Clocked and paid only once we'll find a grant or a budget to build the
  platform.

- Paid after requesting an exceptional budget line to tails@boum.org.
  For example, if we decide to get the help from external contractors
  for the research phase.

  If we decide to work with external contractors, we'll have to be
  careful about not spending more time being the point of contact than
  doing the work ourselves (for example, this might not work for
  intrigeri).

It might be good if the researcher and the implementer are the same
person. This might be groente but not before the end of the year.

Options
=======

  - [[!wikipedia Comparison_of_help_desk_issue_tracking_software]] (Wikipedia)

### OTRS

  - <http://www.otrs.com/>
  - <https://otrs.github.io/doc/manual/admin/3.1/en/html/configure-pgp.html>

### RT

  - <http://bestpractical.com/rt/>
    - <https://bestpractical.com/rtir/>
    - AccessNow have a RT behind their help desk. It's run by Gustaf
      Björksten <gustaf@accessnow.org>.
  - <https://www.bestpractical.com/docs/rt/4.2/RT/Crypt/GnuPG.html>
  - <https://forge.puppetlabs.com/darin/rt>
  - Koumbit is using RT and told us about their experience in <ead91b4d-8a87-5855-de55-2c4ffcb40377@koumbit.org>

### Faveo

  - <https://www.faveohelpdesk.com/>
  - Online demo: <https://www.faveohelpdesk.com/online-demo/>

### Helpy

  - <https://helpy.io/>
