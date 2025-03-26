#import "@preview/kthesis:0.1.1": kth-thesis, setup-appendices

#import "@preview/glossarium:0.5.4": make-glossary, register-glossary, print-glossary
#import "./utils/acronyms.typ": acronyms
#import "utils/enum-references.typ": setup_enum_references
#show: make-glossary
#register-glossary(acronyms)
#show: setup_enum_references

// Fix et al. only appearing on 7+ authors in in-text citations.
// IEEE style guide says it should show up for 3 or more.
// See: https://github.com/typst/hayagriva/issues/164
#set cite(style: "./ieee-et-al-3.csl")

#show: kth-thesis.with(
  primary-lang: "en",
  localized-info: (
    en: (
      title: "Uncovering Class Polution In Python",
      subtitle: lorem(7),
      abstract: include "./content/abstract-1-en.typ",
      keywords: (
        "python",
        "taint analysis",
        "code reuse",
        "class pollution",
        "static analysis",
      ),
    ),
    sv: (
      title: "Svenska Översättningen av Titeln",
      subtitle: "Svenska Översättningen av Undertiteln",
      abstract: include "./content/abstract-2-sv.typ",
      keywords: (), // TODO
    ),
  ),
  authors: (
    (
      first-name: "Diogo",
      last-names: "Torres Correia",
      email: "diogotc@kth.se",
      user-id: "diogotc",
    ),
  ),
  supervisors: (
    (
      first-name: "Musard",
      last-names: "Balliu",
      email: "musard@kth.se",
      user-id: "musard",
      school: "School of Electrical Engineering and Computer Science",
      department: "Department of Computer Science",
    ),
  ),
  examiner: (
    first-name: "Roberto",
    last-names: "Guanciale",
    email: "robertog@kth.se",
    user-id: "robertog",
    school: "School of Electrical Engineering and Computer Science",
    department: "Department of Computer Science",
  ),
  course: (
    code: "DA237X",
    credits: 30,
  ),
  degree: (
    code: "TCYSM",
    name: "Master's Program, Cybersecurity",
    subject-area: "Computer Science and Engineering",
    kind: "Master of Science",
    cycle: 2,
  ),
  // National subject category codes; mandatory for DiVA classification.
  // One or more 3-to-5 digit codes, with preference for 5-digit codes, from:
  // https://www.scb.se/contentassets/10054f2ef27c437884e8cde0d38b9cc4/standard-for-svensk-indelning--av-forskningsamnen-2011-uppdaterad-aug-2016.pdf
  national-subject-categories: ("10201", "10206", "10299"), // TODO
  school: "EECS",
  // TRITA number assigned to thesis after final examiner approval
  trita-number: "2024:0000", // TODO
  // Names of opponents for this thesis; may be none until they're assigned
  opponents: none, // TODO
  // Thesis presentation details; may be none until it's scheduled and set.
  // Either "online" or "location" fields may be none, but not both.
  presentation: none, /* (
    language: "en",
    slot: datetime(
      year: 2025,
      month: 6,
      day: 14,
      hour: 13,
      minute: 0,
      second: 0,
    ),
    online: (service: "Zoom", link: "https://kth-se.zoom.us/j/111222333"),
    location: (
      room: "F1 (Alfvénsalen)",
      address: "Lindstedtsvägen 22",
      city: "Stockholm",
    ),
  ), */
  acknowledgements: include "content/acknowledgements.typ",
  extra-preambles: (
    (heading: "Acronyms and Abbreviations", body: print-glossary(acronyms)),
  ),
  doc-date: datetime.today(),
  doc-city: "Stockholm",
  doc-extra-keywords: ("master thesis",),
  // Whether to include trailing "For DiVA" metadata structure section
  with-for-diva: true,
)

#include "./content/ch01-introduction.typ"
#include "./content/ch02-background.typ"
#include "./content/ch03-method.typ"
#include "./content/ch04-the-thing.typ"
#include "./content/ch05-results.typ"
#include "./content/ch06-discussion.typ"
#include "./content/ch07-conclusion.typ"

#bibliography("references.yml", title: "References")

#show: setup-appendices
#include "./content/zz-a-usage.typ"
#include "./content/zz-b-else.typ"
