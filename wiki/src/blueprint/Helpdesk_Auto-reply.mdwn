Have an auto reply for users writing to HelpDesk
================================================


In order to lower the pressure/urgency of each individual request to HelpDesk,
making it easier to provide more edited information to the rest of the teams
according to our [[mission|contribute/working_together/roles/help_desk/]], we want to have an auto reply for users so they can
self-diagnose the most common problems. Main ticket is [[!tails_ticket 17935]]


We want requests sent to Help Desk to get an automatic email answer:

- “thanks, we don’t have the capacity to answer every request”
- link to the doc and FAQ
- set lower expectations wrt. timing
- for new software suggestions and other dev topics, refer users to https://tails.boum.org/support/faq/#software - https://tails.boum.org/contribute/

Help Desk would still read the reports and extract the info we need for the “Gather qualitative and quantitative user data” part of its [[mission|contribute/working_together/roles/help_desk/]], but will not always answer a personally crafted message to users.


Requirements
------------

- Help Desk members must be able to easily propose changes, for example, to maintain in the message the list of current Top 10 issues reported by users.
- Technical writers also need access to edit the content of the auto-reply.

- Non-WhisperBack emails: Only the 1st email in a thread triggers the auto-reply.
  Otherwise it would be very noisy for the user and send mixed signals ("we need more info from you but we might not
answer a second time").

- WhisperBack emails: Some kind of notification when sending a report
  How would we let them know about the newer hot topics? 
  - Adding a link to somewhere on our website would miss many people.
  - Embedding the current list in the notification would require to either fetch it in
the background.
  - including the list in the image does not work, because it would be outdated as soon
as the image is released and we won't be able to rely this mechanism for issues
in the release itself, which misses most of the point.


Which email gets an auto-reply
------------------------------

HelpDesk receives:

- WhisperBack reports
- Emails sent to tails-support-private
- Emails forwarded from other lists to which users write by mistake.
- Mailing list moderation emails

Most users are writing to tails-support-private@.

tails-bugs@ only receives unencrypted admin emails from the lists, emails from contributors or helpdesk, and WhisperBack reports.

Questions:

- Is it OK if all messages sent by tails-bugs members receive the
  auto-reply message to? (For example, if these messages have a
  special header that could allow you folks to configure your email
  client to automatically [delete] them?)
- Is it OK if messages sent via WhisperBack don’t get an auto-reply
  email? - Can the last page of the WhisperBack report show the user a link to a web version of the auto-reply email?
  (Perhaps, after submission, a part of the auto-reply can be shown, and a link to "latest hot topics and such")
- Is it OK if every message, even if it’s not the beginning of a
thread, gets an auto-reply email?
- Can we track opening posts in email headers? Should we rely on the Re: in the subject line? - What about the "In-Reply-To" field
  - we can also rely on the fact that people writing an email to the help desk write to tails-support-private@ and receive a reply from tails-bugs@, so their second email will be to tails-bugs@ 

Implementation
--------------
- Write a generic message

- [[!tails_ticket 17966 desc="Write standard text to answer hardware support reports for which we can't do anything"]]


Deployment
----------



Changes to HelpDesk workflow after completion
---------------------------------------------

Once this auto-reply is in place, a number of other, important [[!tails_ticket 17965 desc="changes can be implemented in Help Desk’s workflow and processes"]].


<h1 id="template">Actual Auto-reply</h1>

    Dear Tails user,

    We are a very small team working on very limited human resources, with
    regards to that, we may not be able to reply to every request we
    receive, or, we may not reply in a timely manner. In advance, we
    apologize for that.

    You should find many resources on our support page:

    https://tails.boum.org/support

    From there you should find links to your complete documentation, our FAQ
    and our known issues page, that includes a page dedicated to graphic
    card issues.

    If you are getting the "Error starting GDM", please read the provided
    link: https://tails.boum.org/gdm

    It is very difficult to investigate such problems without having access
    to the affected computer. Furthermore, even if we managed to investigate
    the problem, unfortunately we would lack resources to solve it.

    We need more information from you in 2 cases:
        - If this problem did not happen with an older version of Tails:
          Please tell us which older version worked better.
        - If you find a way to workaround the problem:  Please tell us, and
          we will document it so that other affected users benefit from your
    findings. Our best hope is that a future Linux driver update will solve
    the problem.

    For advanced Linux users: if you want to dig deeper on your own, you can
    take it upstream after reproducing on a recent, non-Tails Linux system.

    If your issue is related to the Tor Network itself, please consider
    contacting the The Tor Project instead.

    If your issue is related to software included in Tails, please consider
    contacting their support channels.

    Thanks for your understanding, and have a very nice day.
