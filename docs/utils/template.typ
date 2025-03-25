#let kthblue = rgb("#2258a5")
#let stylize_link(it) = {
  if type(it.dest) == location {
    it
  } else {
    underline(
      stroke: 1pt + kthblue,
      text(fill: kthblue, it),
    )
  }
}

#let in_page_cover(title: none, subtitle: none, date: none) = {
  set text(12pt)
  show link: stylize_link
  show heading: set block(above: 1em, below: 0.5em)

  align(center)[
    #grid(
      columns: (auto, auto),
      gutter: 10pt,
      image("../assets/KTH_logo_RGB_bla.svg", height: 100pt),
      align(left)[
        #heading(numbering: none, outlined: false)[#title]
        #heading(
          numbering: none,
          outlined: false,
          level: 2,
          subtitle,
        )

        #v(10pt)

        Diogo Correia --- #link("mailto:diogotc@kth.se")

        #smallcaps[#date] \
        KTH Royal Institute of Technology
      ],
    )

    #v(10pt)
  ]
}

#let header(title: none) = {
  set text(10pt)
  smallcaps[#title]
  h(1fr)
  smallcaps[DA237X Degree Project]
  line(length: 100%, stroke: 0.5pt + rgb("#888"))
}

#let footer(anonymous: false) = {
  set align(right)
  set text(10pt)
  line(length: 100%, stroke: 0.5pt + rgb("#888"))
  [Diogo Correia (#link("mailto:diogotc@kth.se"))]
  h(1fr)
  [Page ]
  context counter(page).display("1 of 1", both: true)
}

#let setup_page(content) = {
  show link: stylize_link
  set document(date: none) // make PDFs reproducible
  set par(justify: true)
  set heading(numbering: "1.1.")

  content
}
