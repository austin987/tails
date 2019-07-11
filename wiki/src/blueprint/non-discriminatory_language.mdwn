Also tracked by ticket: [[!tails_ticket 10181]]

What's the problem
------------------

We want the Tails community to be diverse. In order to achieve this, our documentation should be the most welcoming possible, to all spectra of gender and provide the same openness in all translations. Also see [Debian's diversity statement](https://www.debian.org/intro/diversity).

Some ideas/suggestions:

*  Can we measure how severe the problem is? 

    ` find $WIKIPATH -name *.de.po -type f -exec \
     grep -ioE "Nutzer|Anwender|$MOREWORDS" '{}' \; | wc -l `

   That could allow us to decide whether we have an urgent problem in
   our documentation that needs to be addressed in general, or whether
   it occurs only in a few places that can be fixed manually by
   slightly twisting the language.

*  Via the same approach as we handle other translation issues: How do
   other wikis/translations handle the same problem? Like TorProject,
   GNOME, Debian, Wikipedia,...  What would be the "official" (Duden?)
   way to do it? (for comparison)

*  Other languages are not gender neutral as well. How is it handled in
   the French/$MORELANG translation?
   Of course it is difficult to compare "good" and "bad" languages with
   regard to gender neutrality, and every language needs a mechanism to
   express/discriminate between, for instance, gender where it is
   necessary for understanding.

*  It should be decided what we want to achieve: non-discrimination
   between which groups?  A candidate/idea for a solution should again
   be evaluated for this aspect.  For instance if we decided to use
   "Benutzerinnen und Benutzer" consistently, we might accidentially
   exclude all groups that don't want themselves to be categorised to
   male or female.  We could bite the bullet and accept that we cannot
   fix natural/spoken languages and need to take a feasible option.
   Another approach could be to only remove/replace words (versus
   adding them) to make the language less specific, and thus, less
   discriminating. (On the other hand, there are some people that are
   very effective in saying nothing with a lot of words.)

Examples of sentences and their german translation
--------------------------------------------------

"Das Hauptziel einer Fehlerbeschreibung ist es, den Entwicklern genau
zu sagen wie der Fehler reproduziert werden kann." from the bug
reporting page. In this situation we could use "den Entwickelnden"
oder a gender gap "den Entwickler*Innen". The question is also how we
can maintain a good readability (for me personally a gender gap is not
a problem for readability, it's sort of a habituation thing).

Another example:
"Das Ziel dieser Dokumentation ist zu erklären, wie man Tails benutzt
und dem Nutzer die wesentlichen Sicherheitsfeatures darzustellen."
from the introduction page. In this one we could use "den Nutzenden",
but this sounds a bit weird. So maybe a gender gap fits more in here
or a completely different term.

Last example (there a a lot of them ;) I just picked some out quickly):
"Tor wird gleichermaßen von Journalisten, Strafverfolgungsbehörden,
Regierungen, Menschenrechtsaktivisten, Geschäftsführern, dem Militär,
Missbrauchsopfern und normalen Bürgern, die sich um ihre Privatsphäre
sorgen, benutzt." from  "Why does Tails use Tor?"

Why do we want gender neutral language?
---------------------------------------

* as many non-discriminated persons don't recognize their privileged positions, they have to learn what their privileges are and how discrimination is carried out towards affected groups 
* many people do not recognize the discriminating power of language
* discrimination does not only happen by excluding *different* (or not being the norm) marginalized groups physically, by law etc.
* language itself is often only addressing male persons. Different languages have distinct pronouns etc. (which can have an excluding impact for non-binary identifying persons)
* women have been oppressed and marginalized systematically for centuries by societal norms and structures, which is still reflected in the German language e.g. by the "generic masculine" which excludes not only women but also every other gender except the male one
* we want to include and address as many persons as possible, not *only* women. We understand that women are most probably the biggest group being oppressed by male-centered language, but so is every person who identifies themselves as outside of the common gender binary
* we consider that we don't want to exclude or patronize any person (as stated in our Code of Conduct). We want to address and reach any person (free from any prejudice, etc.); this also concerns language, as language itself is reproducing, re-enabling and reinforcing, and thus portraying a (current) society in which many various marginalized groups are discriminated
* language is not only a tool. Language is varied in terms of style, wording and grammar when addressing distinct groups (scientific papers, [technical] documentation, essays, personal letters/e-mails, chat, short messaging etc.). it also carries underlying (societal) structures, authority, social status, rights, addressing and meanings that represent (sometimes even decades to century old) societal structures and a society which is based on oppression and institutional discrimination (colonization, racism, patriarchy, two-gendered-heterosexist norms and structures, etc)
* often people tell that "this is not meant this way" or "by using $this (male)-gendered wording we address everyone". This is not enough, as inclusion does not happen and won't happen solely by the *will to include some persons or groups*, but in the same sentence excluding those in particular. It's even worse to say so, as it implies that you understand the concerns with regard to discriminating language, but you're ignoring solutions for them for some reasons. Some examples for such reasons are:"better readability", "adds a layer of complexity", "it is and should not be our task to address this", "it won't change anything with regard to discrimination and inclusion of marginalized groups", "everybody knows that 'all' are meant by using $expression", etc.
* we understand that gender neutral language can be in fact more complicated and may appear a bit more clumsy than *usual* language. But we also believe that language is nothing what is set in stone, it evolves permanently and is adapted to new needs. New words are introduced nearly every day and other words are used less frequently, sometimes even words and phrases disappear (and perhaps reappear again someday)
* the current state-of-the-art language does not have to be taken for granted. Every single person is in the position to reflect, modify and adapt language. So are we.

* everything written here so far leads us to the decision to implement a gender-neutral and thus non-discriminatory language

General examples how discrimination via language works
------------------------------------------------------

WIP

Possible in-practice solutions (German)
---------------------------------------

* add a "disclaimer" that we address everyone and that we understand the general problem but use common wording as it's less complicated. -> aka. leave as it is
* use both female/male wording, e.g. "Benutzerinnen und Benutzer".
* switch around between e.g. male and female
* "internal I" aka Binnen-I (BenutzerInnen)
* "Gendergap" and variants (underscore, asterisk, small/operator asterisk, period. e.g. "Benutzer_innen", "Benuter*innen", "Benutzer﹡innen", "Benutzer∗innen", "Benutzer.innen")
* "Gender-x" abolish gender completely and replace it by an "x" or "ces", e.g. "Benutzx" resp. "Benutzecs"

Interesting reads
-----------------

*  [[https://de.wikipedia.org/wiki/Generisches_Maskulinum]]
* A is a [brochure](https://www.bmbf.gv.at/frauen/gleichbehandlung/sg/lf_gg_sprachgebrauch_26114.pdf) of the austrian 'ministry for education and women' with some tips how to phrase.
* A is a [guide](http://www.uibk.ac.at/gleichbehandlung/sprache/leitfaden_nicht_diskr_sprachgebrauch.pdf) to non discriminatory language not only about gender based discrimination but also about ageism, ableism... 
* [[https://de.wikipedia.org/wiki/Gender_Gap_%28Linguistik%29]]
