#import "./utils/global-imports.typ": codly, codly-languages, cve, fletcher, glossarium, touying
#import touying: *
#import "./utils/slides-template.typ": *
#import "./utils/constants.typ": TheTool
#import "./utils/enum-references.typ": enum-label, wrapped-enum-numbering
#import "./utils/acronyms.typ": acronyms
#import "./content/ch02-background.typ": (
  js_pp_gadget, js_pp_pollute, js_proto_chain, py_attrs, py_fn_globals, py_items, pysa_taint_models,
)
#import "./content/ch04-the-thing.typ": classa_design
#import "./content/ch05-results.typ": (
  deepdiff_issues, deepdiff_project, deepdiff_source_code, errors_table, features_graph, format_popularity,
  micro_bench_fail, no_issues_projects, project_results_graph, projects_elapsed_seconds, projects_error,
  projects_success, raw_data, reasons_graph, type_i_error_rate,
)
#import "./content/ch06-discussion.typ": mitigation_example
#import glossarium: make-glossary, print-glossary, register-glossary

#import codly: codly, codly-init
#import codly-languages: codly-languages
#import fletcher: edge, node

#let diagram = touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)

#show: codly-init
#show: make-glossary.with(always-long: false)

#let cve = it => alert(cve(it))

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
    // This would fix non-convergence, but they counters are wrong
    // enable-frozen-states-and-counters: false,

    // handout: true,
    preamble: {
      pdfpc-config
      codly(languages: codly-languages, zebra-fill: none)
      register-glossary(acronyms)
      // needs to exist so that acronyms work
      print-glossary(acronyms, disable-back-references: true, show-all: true, invisible: true)
    },
    show-bibliography-as-footnote: bibliography(title: none, "./references.yml"),

    frozen-counters: (
      counter(figure.where(kind: raw)),
    ),
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

#align(center, alert(text(size: 1.3em)[*Valuable target for attackers!*]))

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
)

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

=== Classic Example


#figure(
  caption: [Traversing attributes and `__globals__` to reach Flask's secret key],
  diagram(
    spacing: (15mm, 20mm),
    node-stroke: luma(80%),
    node-shape: rect,
    node-inset: 0.5em,
    node-corner-radius: 0.5em,
    node((0, 0), `animal`),
    pause,
    edge("-|>", bend: 45deg, label: `getattr`),
    node((1, 0), `myfunc`),
    pause,
    edge("-|>", bend: 45deg, label: `getattr`),
    node((2, 0), `__globals__`),
    pause,
    edge("-|>", bend: 45deg, label: `__getitem__`),
    node((1.5, 1), `app`),
    pause,
    edge("-|>", bend: 45deg, label: `getattr`),
    node((0.5, 1), `secret_key`),
  ),
)

---

#figure(
  caption: [Example function vulnerable to class pollution],
  [
    #set text(size: 0.8em)
    #codly(
      highlights: (
        (line: 7, start: 19, end: 25, fill: green),
        (line: 11, start: 9, end: 15, fill: purple),
      ),
    )
    ```py
    def setattr_recursive(obj, path, value):
        parts = path.split(".")
        for part in parts[:-1]:
            if isinstance(obj, dict):
                obj = obj[part]
            else:
                obj = getattr(obj, part)
        if isinstance(obj, dict):
            obj[parts[-1]] = value
        else:
            setattr(obj, parts[-1], value)

    ```
  ],
)

= Goals & Research#(sym.space.nobreak)Questions

== Research Questions

#[
  #set enum(numbering: wrapped-enum-numbering(
    ref-numbering: (..nums) => [*RQ#numbering("1.1", ..nums)*],
    (..nums) => [*RQ#numbering("1.1.", ..nums)*],
  ))
  + #enum-label("rq-causes-consequences")
    What are the root causes and possible consequences of class pollution
    in a Python application?
  #pause

  + #enum-label("rq-tool-design")
    How to design and implement a tool that can efficiently and accurately
    detect class pollution in Python?
  #pause

  + #enum-label("rq-widespread")
    How prevalent and exploitable is class pollution in
    real-world Python projects?
]

// speaker notes:
// - uncover how widespread class pollution is
// - generate awareness and inspire future research

= Contributions & System#(sym.space.nobreak)Design

== Contributions

- List of dangerous constructs;
- Tool that can detect class pollution, *Classa*;
- Empirical study over #raw_data.len() popular Python packages; and
- *#cve("CVE-2025-58367")* on `deepdiff` with 10.0 CVSS4 score

== Pysa

- Security-focused Python taint analysis tool
- Easy to configure models

#pause

#{
  set text(size: 0.9em)
  pysa_taint_models
}

== Classa

#{
  set text(size: 0.9em)
  classa_design
}

= Methodology & Results

== Methodology Overview

- Micro Benchmarking
- Empirical Study
- Case Study

== Micro Benchmarking

- 5 synthetic benchmarks
  - 3 known-vulnerable, 2 known-not-vulnerable
- 5 known-vulnerable real-world projects

#pause

#micro_bench_fail


== Empirical Study

- 3000 popular real-world projects (GitHub, PyPI)
- Median runtime of #projects_elapsed_seconds.median seconds (successful projects)
#pause
- #projects_error.len() projects failed analysis

#errors_table

---

- #no_issues_projects.len()
  (#calc.round((no_issues_projects.len() / projects_success.len()) * 100, digits: 1)%)
  projects without issues
- False positive rate of #type_i_error_rate% (projects)

#{
  set text(size: 0.6em)
  project_results_graph(width: 18cm, height: 8cm)
}

---

#{
  set text(size: 0.65em)
  features_graph(width: 18cm, height: 10cm)
}

---

#{
  set text(size: 0.65em)
  reasons_graph(width: 18cm, height: 10cm)
}

== Case Study

=== DeepDiff

- Manually audited: *deepdiff* v8.6.0
  - #format_popularity(deepdiff_project.at("popularity")) downloads on @pypi
  - 2.4k stars on GitHub
  - 18k dependent repositories
#pause

- #TheTool detected #deepdiff_issues.len() _Vulnerable_ issue on *deepdiff*
- Vulnerability in `Delta` module

---

=== Detected Class Pollution Source

#deepdiff_source_code(long: false)

---

=== Impact

How can this be used?

#pause

- Pollute `deepdiff.serialization.SAFE_TO_IMPORT` to allow usage of `posix.system`
#pause
- Use `Delta`'s pickle constructor to run arbitrary code (@rce)

---

=== Affected Applications

#figure(
  caption: [HTTP endpoint that accepts binary data, passed directly
    into the `Delta` class],
  [
    #set text(size: 0.85em)
    #set text(size: 0.75em)
    #codly(
      skips: ((7, 4), (9, 66)),
      header: box(height: 0.835em)[`src/lsst/cmservice/routers/v2/manifests.py`],
      footer: [from GitHub repository *lsst-dm/cm-service* at revision f551e2b],
      offset: 185,
      highlighted-lines: (264,),
    )
    ```py
    @router.patch(
        "/{manifest_name_or_id}",
        summary="Update manifest detail",
        status_code=202,
    )
    async def update_manifest_resource(
        patch_data: Annotated[bytes, Body()] | Sequence[JSONPatch],
    ) -> Manifest:
            new_manifest["spec"] += Delta(patch_data)
    ```
  ],
)

---

=== CVE

#figure(
  caption: [Security advisory for *deepdiff* as a result of the findings of #TheTool],
  image("./assets/cve.svg", width: 30cm),
)


= Discussion & Future#(sym.space.nobreak)Work

== Mitigations

- Prevent traversal through dunder attributes

#mitigation_example

== Limitations

=== Non-Goals

- Gadget detection

=== Shortcomings

- Complex traversals (e.g., through functions)
- Requires presence of `setattr`

== Future Work

- Automatic feature labeling
- Improve false positive rate
- Gadget detection

= Conclusion

== Conclusion

- Dangerous consequences
- Exploitable in real-world scenarios (*#cve("CVE-2025-58367")*)
- Uncommon vulnerability

#title-slide()
