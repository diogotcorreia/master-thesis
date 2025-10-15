#import "./utils/global-imports.typ": touying
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

= Background &\ Related Work

== #lorem(2)

=== #lorem(5)

#lorem(50)

---

=== #lorem(5)

- #lorem(6)
- #lorem(7)
- #lorem(8)

= Motivation &\ Problem Statement

= Goals &\ Research Questions

= Contributions &\ System Design

= Methodology &\ Results

= Limitations &\ Future Work

= Conclusion

#title-slide()
