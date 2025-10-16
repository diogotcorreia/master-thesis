#import "./utils/global-imports.typ": codly, codly-languages, cve, touying
#import touying: *
#import "./utils/slides-template.typ": *
#import "./utils/constants.typ": TheTool
#import "./content/ch02-background.typ": js_pp_gadget, js_pp_pollute, js_proto_chain
#import "./content/ch05-results.typ": raw_data
#import codly: codly, codly-init
#import codly-languages: codly-languages

#show: codly-init
#codly(languages: codly-languages, zebra-fill: none)

// typst query --root . ./04-presentation.typ --field value --one "<pdfpc-file>" > ./04-presentation.pdfpc
#let pdfpc-config = pdfpc.config(
  duration-minutes: 25,
  last-minutes: 5,
  note-font-size: 16,
  disable-markdown: false,
)

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-common(
    preamble: pdfpc-config,
    show-bibliography-as-footnote: bibliography(title: none, "./references.yml"),
  ),
  config-info(
    title: [#TheTool: Uncovering Class Pollution in Python],
    subtitle: [Measuring Class Pollution Vulnerabilities of #raw_data.len() Real-World Python Projects],
    author: [Diogo Correia | diogotc\@kth.se],
    date: datetime(year: 2025, month: 10, day: 22),
    institution: [KTH Royal Institute of Technology],
    logo: image("./assets/KTH_logo_RGB_bla.svg"),
    logo-white: image("./assets/KTH_logo_RGB_vit.svg"),
  ),
)

#set footnote.entry(gap: 0.3em, separator: none)
#show footnote.entry: set text(size: 0.5em, fill: black.lighten(20%))
#show figure.caption: set text(size: 15pt)

#title-slide()

= Background &\ Root Causes

== JavaScript Prototype Pollution

=== Background

- Novel type of vulnerability: introduced in 2018 by Arteau@pp-arteau
- Takes advantage of JavaScript's prototype-based inheritance
- Can lead to Cross-Site Scripting (XSS), Remote Code Execution,
  Denial of Service, etc.@ghunter@probetheproto@silent-spring

---

=== Prototype-based Inheritance

#{
  set text(size: 0.9em)
  js_proto_chain
}

---

=== Pollution

#{
  set text(size: 0.7em)
  js_pp_pollute
}

---

=== Gadget

#{
  set text(size: 0.9em)
  js_pp_gadget
}


#focus-slide()[
  Can we do the same with Python?
]

== Python Language Fundamentals

- #lorem(6)

== Python Class Pollution

- #lorem(6)
- #lorem(7)
- #lorem(8)

= Goals &\ Research Questions

== Research Questions

+ #lorem(10)

// speaker notes:
// - uncover how widespread class pollution is
// - generate awareness and inspire future research

// list research questions

= Contributions &\ System Design

== Contributions

- List of dangerous constructs;
- Tool that can detect class pollution, *Classa*;
- Empirical study over #raw_data.len() popular Python packages; and
- *#cve("CVE-2025-58367")* on `deepdiff` with 10.0 CVSS4 score

== Pysa

#lorem(10)

== Classa

#lorem(10)

= Methodology &\ Results

== Methodology Overview

- Micro Benchmarking
- Empirical Study
- Case Study
- Tool Tweaks?

== Micro Benchmarking

#lorem(10)

== Empirical Study

#lorem(10)

== Case Study

#lorem(10)

= Discussion &\ Future Work

== Mitigations

- #lorem(10)

== Limitations

=== Non-Goals

- Gadget detection

=== Shortcomings

- Complex traversals (e.g., through functions)
- Requires presence of `setattr` // TODO show example code block

== Future Work

- Automatic feature labeling
- Improve false positive rate
- Gadget detection

= Conclusion

== Conclusion

- Dangerous consequences
- Exploitable in real-world scenarios (*#cve("CVE-2025-58367")*)
- Not widespread

#title-slide()

=
