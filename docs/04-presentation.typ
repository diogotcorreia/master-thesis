#import "./utils/global-imports.typ": codly, codly-languages, cve, fletcher, touying
#import touying: *
#import "./utils/slides-template.typ": *
#import "./utils/constants.typ": TheTool
#import "./content/ch02-background.typ": js_pp_gadget, js_pp_pollute, js_proto_chain, py_attrs, py_fn_globals, py_items
#import "./content/ch05-results.typ": raw_data
#import codly: codly, codly-init
#import codly-languages: codly-languages
#import fletcher: edge, node

#let diagram = touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)

#show: codly-init

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
    preamble: {
      pdfpc-config
      codly(languages: codly-languages, zebra-fill: none)
    },
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

---

#{
  set text(size: 0.8em)
  components.adaptive-columns(outline(indent: 1em, depth: 1))
}

= Background & Root#(sym.space.nobreak)Causes

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

#components.side-by-side()[
  *Pollution*

  - Abuse existing code to set a value on the root prototype
][
  *Gadget*

  - Change behaviour of benign code in the application when certain properties are set

  - Property to pollute depends on gadget
]

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

== Why Python?

- Wide adoption in various fields
- Known by many programmers of various skill levels
- Used by high profile applications and companies

#pause

#v(3em)

#align(center, text(size: 1.3em)[*Valuable target for attackers!*])

== Python Language Fundamentals

=== Class-based Inheritance

#figure(
  caption: [Inheritance in Python is class-based, with most classes inheriting from `object`],
  diagram(
    spacing: (15mm, 20mm),
    node-stroke: luma(80%),
    node-shape: rect,
    node-inset: 0.5em,
    node-corner-radius: 0.5em,
    node((0, 0), `object`, name: <obj>),

    node((-1, 1), `Animal`),
    edge(<obj>, "-|>"),
    node((-0.5, 2), `Mammal`),
    edge(auto, (-1, 1), "-|>"),
    node((-1.5, 2), `Reptile`),
    edge(auto, (-1, 1), "-|>"),

    node((1, 1), `int`),
    edge(auto, <obj>, "-|>"),
    edge("<|-"),
    node((1, 2), `bool`),
    node((2, 1), `str`),
    edge(auto, <obj>, "-|>", bend: -5deg),
    node((3, 1), `list`),
    edge(auto, <obj>, "-|>", bend: -10deg),
    node((4, 1), [...]),
    edge(auto, <obj>, "-|>", bend: -20deg),

    pause,

    node(
      (-0.2, -0.2),
      rotate(-20deg, text(fill: red, stroke: 1pt + black, size: 1.2em, weight: "bold")[Immutable!]),
      stroke: none,
      layer: 1,
    ),
  ),
) <fg:prototype-chain>

---

=== Dunder Attributes

#figure(
  caption: [Some operators in Python are syntactic sugar for dunder methods],
  [
    #codly(number-format: none, display-name: false)
    #grid(
      columns: (2fr, 3fr),
      gutter: 1em,
      ```py
      1 + 2
      ```,
      ```py
      int.__add__(1, 2)
      ```,
    )
  ],
)

#pause

#codly(number-format: numbering.with("1"), display-name: true)
#{
  set text(size: 0.75em)
  py_fn_globals
}

---

=== Object Attributes

#py_attrs

---

=== Item Containers

#py_items

---

#components.side-by-side()[
  *Object Attributes*

  - Used in classes and objects
  - Accessed statically through the dot notation
  - Getter: `getattr`
  - Setter: `setattr`
][
  *Item Containers*

  - Used in dictionaries, lists, tuples, etc.
  - Accessed through square bracket notation
  - Getter: `__getitem__`
  - Setter: `__setitem__`
  - Containers are still objects and can have attributes
]

== Python Class Pollution

- #lorem(6)
- #lorem(7)
- #lorem(8)

= Goals & Research#(sym.space.nobreak)Questions

== Research Questions

+ #lorem(10)

// speaker notes:
// - uncover how widespread class pollution is
// - generate awareness and inspire future research

// list research questions

= Contributions & System#(sym.space.nobreak)Design

== Contributions

- List of dangerous constructs;
- Tool that can detect class pollution, *Classa*;
- Empirical study over #raw_data.len() popular Python packages; and
- *#cve("CVE-2025-58367")* on `deepdiff` with 10.0 CVSS4 score

== Pysa

#lorem(10)

== Classa

#lorem(10)

= Methodology & Results

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

= Discussion & Future#(sym.space.nobreak)Work

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
