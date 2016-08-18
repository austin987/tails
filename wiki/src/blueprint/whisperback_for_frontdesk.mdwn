[[!meta title="WhisperBack for frontdesk"]]

[[!toc levels=2]]

At the 2015 summit, we identified a few improvements to WhisperBack that
would make the life of our support team easier. Namely:

  - Have user language information in Whisperback ([[!tails_ticket 9799 desc="#9799"]])
  - Add some OpenPGP key checks to WhisperBack ([[!tails_ticket 9800 desc="#9800"]])

Here are some notes and design ideas on how to solve these.

Language information
====================

Our support team can understand and write several languages. But not everybody
in the team has the same linguistic abilities and they also work on shifts.
The process of answering requests would be faster if our team could:

  - Filter incoming requests based on the language they are written in.

  - Know whether the person sending the request understands other languages.

Language of the report
----------------------

We could determine the language in which the report is written by:

  - Using a language detection library.
  - Referring to the LOCALE of the session.
  - Asking the user.

Relevant design question:

  - None of these techniques would be perfect but that's ok.
  - The set possible languages should be limited by the set of languages
    understood by the support team. 
  - The user should be aware this information so as to correct it manually or
    to adjust her writing to the languages understood by the support team.

Languages understood by the user
--------------------------------

This is based on the assumption that many people are more comfortable
understanding than writing another language than their native language.  This
being true both for people writing us and people working in the support team.
For example, it might be all-right for someone writing us in French to receive
an answer in English or for someone writing us in Portuguese to receive an
answer in Spanish.

we could determine the languages understood by the user by:

  - Referring to the LOCALE of the session.
  - Asking the user.

Privacy concerns
----------------

As we received the reports encrypted, it would be most efficient for the
support team to know the language of the report from the email headers. For
example as a flag in the subject of the email as this would allow using email
filters. But this might have privacy concerns.

  - When the user sends the report, we would be telling our WhisperBack relays
  (hidden services), boum.org, and the email providers of the user support team
  that someone sent an report in a given language amongst the one understood by
  the team. This seems acceptable.

  - When answering the report:
    - If the answer is sent in plain text, the language of the report
    would already be known by all the machines relaying the email.
    - If the answer is sent encrypted, we would revealed this language to the
    email provider of the user. This is more serious and should be avoided.

As a workaround, we can decide not to flag in the email headers, the language
of reports that are sent along with an OpenPGP key.

OpenPGP checks
==============

We want to:

  1. Verify that the key matches the email address of the user.
  2. Verify that the key exists.
  3. Be nice to people sending many reports and avoid asking them to paste the
     armored version every time.

In order to ensure 1 and 2, we need access to the public key itself (not only
it's ID).

To solve 3 we could:

  1. Look for a key in the keyring of the user. But we need to ask permission
     before adding it to the report.
  2. Search for a key on the public key servers. But we need to ask permission
     before doing the search.

Proposed design
===============

Mockup
------

<pre>
Summary:  [                                   ]

Email:    [                     ] [ OpenPGP key (optional) ]

We answer requests in English, French, Spanish and  Italian.
Requests  not  in  English  might  take  longer  to  answer.
Imperfect English is welcome.

[ ] I understand an answer in English.

Description of the problem:

[                               ]
[                               ]
</pre>

Description of the widgets
--------------------------

  a. `[ OpenPGP key (optional)]` is a button which opens a dialog:

    1. If an OpenPGP key matching the email is found in the keyring
       of the user, then we ask for permission before adding it to the
       report.

    2. Otherwise we ask permission to search for a key in the public key
       servers and then attach it to the report.

    3. If the search fails we ask for an armored OpenPGP key and
       validate it against the email of the user.
    
    4. If several valid keys are found in step 1 or 2 we ask the user to select one.

    5. Once an OpenPGP key is selected the button changes caption to
       `[OpenPGP key: $KEYID]` and can be clicked to run the key
       selection process again.

  b. `[ ] I understand English.` is a checkbox the notify that the
     sender is fine with receiving and answer in English.

Metadata for the user support team
----------------------------------

  - **Language of the report**:

    - If the report has no OpenPGP key associated, then we would add a
      `[xx]` flag in the subject of the email corresponding to the
      autodetected language of the nbody of the message.

    - If the report has an OpenPGP key associated, then we would add a
      `Language: ` field in the body of the report.
 
  - **English understood**: we would add an `English: [yes|no]` field in
    the body of the report according to checkbox (b).

  - **Locale**: if the locale of the session is not English and is different
    from the language of the report we would add a `Locale: ` field in
    the body of the report.

  - **OpenPGP key**: we would attach an armored version of the OpenPGP
    key associated with the report.
