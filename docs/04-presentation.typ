#import "./utils/global-imports.typ": cve, touying
#import touying: *
#import "./utils/slides-template.typ": *
#import "./utils/constants.typ": TheTool
#import "./content/ch05-results.typ": raw_data

#show: university-theme.with(
  aspect-ratio: "16-9",
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

#pdfpc.config(
  duration-minutes: 25,
  last-minutes: 5,
  note-font-size: 16,
  disable-markdown: false,
)

#title-slide()

= Background &\ Root Causes

== Code Reuse Attacks (Motivation)

- JavaScript Prototype Pollution

Can we do the same with Python?

// show numbers like amount of CVEs
// and results from papers (e.g., prototype pollution)

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

= Limitations &\ Future Work

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
