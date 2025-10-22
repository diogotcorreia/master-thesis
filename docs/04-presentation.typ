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
  has_issues_projects, micro_bench_fail, no_issues_projects, project_results_graph, projects_elapsed_seconds,
  projects_error, projects_success, raw_data, reasons_graph, type_i_error_rate, vulnerable_projects,
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
#let speaker-note = speaker-note.with(mode: "md")

#let HANDOUT_MODE = false

// typst query --root . ./04-presentation.typ --field value --one "<pdfpc-file>" > ./04-presentation.pdfpc
#let pdfpc-config = pdfpc.config(
  duration-minutes: 25,
  last-minutes: 5,
  note-font-size: 21,
  disable-markdown: false,
)

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-common(
    // This would fix non-convergence, but they counters are wrong
    // enable-frozen-states-and-counters: false,

    handout: HANDOUT_MODE,
    preamble: {
      pdfpc-config
      codly(languages: codly-languages, zebra-fill: none, highlighted-default-color: orange.lighten(70%))
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

#speaker-note[
  hello

  and today I'm presenting my thesis:
]

---

#{
  set text(size: 0.8em)
  show outline.entry: it => if HANDOUT_MODE {
    link(
      it.element.location(),
      it.indented(it.prefix(), it.inner()),
    )
  } else [
    - #link(
        it.element.location(),
        it.indented(it.prefix(), it.body()),
      )
  ]
  components.adaptive-columns(outline(indent: 1em, depth: 1))
}

#speaker-note[
  - let's look at the agenda for today
  - we will start by motivating this work
  - then we will look at the resulting contributions and how Classa is designed
  - after that, we will analyse the results
  - and finally, we will discuss about mitigations and future work
]

= Background & Root#(sym.space.nobreak)Causes

== JavaScript Prototype Pollution

=== Background

- Novel type of vulnerability: introduced in 2018 by Arteau@pp-arteau
- Takes advantage of JavaScript's prototype-based inheritance
- Can lead to Cross-Site Scripting (XSS), Remote Code Execution,
  Denial of Service, etc.@ghunter@probetheproto@silent-spring

#speaker-note[
  - some of you might already be familiarised with pp in js
]

---

=== Prototype-based Inheritance

#{
  set text(size: 0.9em)
  js_proto_chain
}

#speaker-note[
  - in js, all objects inherit from a root prototype
  - ...a `__proto__` property pointing...
  - when accessing a property, the prototype chain is traversed
    until one of the objects contains the desired property
]

---

#components.side-by-side()[
  === Pollution

  - Abuse existing code to set a value on the root prototype
][
  #{
    set text(size: 0.69em)
    figure(caption: "Example construct that would pollute the root prototype with admin")[
      ```js
      const obj = {};

      // Object.prototype points to the root prototype
      Object.prototype // {}
      obj["__proto__"]["admin"] = true;
      Object.prototype // { admin: true }

      const other_obj = {};
      other_obj.admin // true
      ```
    ]
  }
]

#speaker-note[
  - exploitation requires two steps
  - first, we need to set a value on the root prototype
  - in this context, pollution means...
  - _explain example_
]

---

#components.side-by-side()[
  #{
    set text(size: 0.74em)
    figure(caption: "Example gadget, granting access to admin-only information")[
      ```js
      const user = {
        username: "johndoe"
      };
      // If Object.prototype.admin is polluted, this is true
      if (user.admin) {
        printSuperSecretInformation();
        // Oh no :(
      }
      ```
    ]
  }
][
  === Gadget

  - Change behaviour of benign code in the application when certain properties are set

  - Property to pollute depends on gadget
]

#speaker-note[
  - then, we need to find code whose behaviour changes based on adding this property to the root prototype
  - obviously, the gadget dictates which property we want to pollute
  - _explain example_
]

#focus-slide()[
  Can we do the same with Python?
]

== Why Python?

- Wide adoption in various fields
- Known by many programmers of various skill levels@stack-overflow-survey-2025-most-popular
- Used by high profile applications and companies
- Many libraries: Flask, Django, NumPy, Pandas, etc.

#pause

#v(2em)

#align(center, alert(text(size: 1.3em)[*Valuable target for attackers!*]))

#speaker-note[
  - most of you have probably have heard about it or even used it

  - *CHANGE SLIDE* and therefore research on possible exploits and mitigations is very important to keep the ecossystem secure
]

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

#speaker-note[
  - python, like js, also has inheritance, but based on classes
  - notably, it also has an object class, of which all most other classes inherit from
  - the same exploit *WE USED IN JS* does not work because object is immutable, so we cannot change any of its properties
]

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

#speaker-note[
  - python exposes many of its internals
  - if you have every used python, you might have encountered some of these in the form of dunder methods
  - for example, these two pieces of code are equivalent
  - one interesting dunder attribute exposed by python is `__globals__` on functions
  - this exposes the namespace of the file a function is defined in
  - this is useful for attackers because they can use it to traverse to a property they want to pollute
]

---


#components.side-by-side()[
  === Object Attributes

  - Used in classes and objects
  - Accessed statically through the dot notation
  - Getter: `getattr`
  - Setter: `setattr`
][
  #py_attrs
]

#speaker-note[
  - also needed to understand class pollution is the distinction between object attributes and container items
  - on one hand...
]

---

#components.side-by-side()[
  #codly(display-name: false)
  #set text(size: 0.89em)
  #py_items
  #codly(display-name: true)
][
  === Container Items

  - Used in dictionaries, lists, tuples, etc.
  - Accessed through square bracket notation
  - Getter: `__getitem__`
  - Setter: `__setitem__`
  - Containers are still objects and can have attributes
]

#speaker-note[
  - on the other hand...
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

#speaker-note[
  - now we will take a look at a classic example of traversing with class pollution,
    putting together all the pieces we learnt until now
  - if this is a flask application, we can reach `app` and then `secret_key`
    - allows for forging authentication cookies
]

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

#speaker-note[
  - in code, this could be represented by a function like this
  - the important part here is that the return value from `getattr` eventually reaches the argument of `setattr`
]

= Goals & Research#(sym.space.nobreak)Questions

== Research Questions

#[
  #set enum(
    numbering: wrapped-enum-numbering(
      ref-numbering: (..nums) => [*RQ#numbering("1.1", ..nums)*],
      (..nums) => box(width: 2.3em)[*RQ#numbering("1.1.", ..nums)*],
    ),
    number-align: start + top,
  )
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

#speaker-note[
  - `<rq1>` we have already answered this one
  - `<rq2>`
  - `<rq3>` will be answered by running Classa on real-world projects
  - main goals:
    - uncover how widespread class pollution is
    - raise awareness and inspire future research
]

= Contributions & System#(sym.space.nobreak)Design

== Contributions

- List of dangerous constructs;
- Tool that can detect class pollution, *Classa*;
- Empirical study over #raw_data.len() popular Python packages; and
- *#cve("CVE-2025-58367")* on `deepdiff` with 10.0 CVSS4 score

#speaker-note[
  - as a result of this degree project, we provide some contributions, mainly...
]

== Pysa

- Security-focused Python taint analysis tool
- Easy to configure models

#pause

#{
  set text(size: 0.9em)
  figure(caption: [Simplified Pysa taint models that detect flows from `getattr` to `setattr`])[
    ```py
    def getattr() -> TaintSource[GetAttrSource]: ...

    def setattr(value: TaintSink[SetAttrSink]): ...
    ```
  ]
}

#speaker-note[
  - let's now look at the design and implementation of Classa
  - under the hood, Classa uses Pysa, a `<read slides>`
  - its models can be configured using a python-like syntax
  // TODO: change the code to actually use getattr/setattr?
  - in this example, we can see a pattern that resembles code vulnerable to class pollution,
    where the return value of one function flows into the argument of another
]

== Classa

#{
  set text(size: 0.9em)
  classa_design
}

#speaker-note[
  - Classa is designed to analyse projects in bulk, despite also being able to analyse a single project
  - given a list of projects `<point>`, it starts by downloading all the relevant source code
  - it then may resolve and install the appropriate dependencies if desired
  - then, pysa is run on the code
  - and the results are analysed (*pysa gives lots of data*)
  - then, a human operator has to label the issues manually,
    marking them as either true or false positives,
    and a respective reason
]

= Methodology & Results

== Empirical Study

- 3000 popular real-world projects (GitHub, PyPI)
- Median runtime of #projects_elapsed_seconds.median seconds (successful projects)
#pause
- #projects_error.len() projects failed analysis

#errors_table

#speaker-note[
  - to test the performance of the tool and the prevalence of class pollution in real-world projects,
    we conducted an empirical study
  - for this, we analysed `<read>`, sampled from a large number of popular packages and repositories
  - most projects took less than #projects_elapsed_seconds.median seconds to be analysed,
    but some took up to #calc.round(projects_elapsed_seconds.max / 60, digits: 1) minutes
  - unfortunately, `<read>`, mostly due to problems related to Pysa
]

---

- #no_issues_projects.len()
  (#calc.round((no_issues_projects.len() / projects_success.len()) * 100, digits: 1)%)
  projects without issues
- False positive rate of #type_i_error_rate% (projects)

#{
  set text(size: 0.6em)
  project_results_graph(width: 18cm, height: 8cm)
}

#speaker-note[
  - most projects did not have issues, that is, any piece of code that could be vulnerable to
    class pollution
  - #has_issues_projects.len() projects have issues, but only #vulnerable_projects.len()
    have actual vulnerabilities, with the other being false positives
]

---

#{
  set text(size: 0.65em)
  features_graph(width: 18cm, height: 10cm, annotate: true)
}

#speaker-note[
  - as previously mentioned, all issues were labeled manually
  - here we can see the patterns of potentially exploitable code, and how prevalent they are
  - *base case*, dict access means it uses `__getitem__`
  - a successful and dangerous exploit usually requires both `Dict Access` and `Supports __setitem__`,
    which as you can see are not very prevalent
  - there three last entries are actually "negative patterns", as they make exploitation harder
    - for instance, `Needs Existing` requires the value to pollute to already exist
]

---

#{
  set text(size: 0.65em)
  reasons_graph(width: 18cm, height: 10cm)
}

#speaker-note[
  - likewise, here we have the reasons for issues to be labeled false positives
  - most of these cases happened because the object returned by `getattr` has
    been modified before reaching `setattr`
    - this is something Pysa makes hard to detect unfortunately
  - it was also very common for `getattr` to be called only once,
    which does not let an attacker traverse freely
    - this was mitigated in classa during post-processing, but some still managed to slip through
]

== Case Study

=== DeepDiff

- Manually audited: *deepdiff* v8.6.0
  - #format_popularity(deepdiff_project.at("popularity")) downloads on @pypi
  - 2.4k stars on GitHub
  - 18k dependent repositories
#pause

- #TheTool detected #deepdiff_issues.len() _Vulnerable_ issue on *deepdiff*
- Vulnerability in `Delta` module

#speaker-note[
  - to demonstrate the exploitability and consequences of class pollution,
    we conducted a case study on a package detected vulnerable by Classa
  - deepdiff is a library for calculating the difference between two objects and therefore...
  - deepdiff is a very popular package, `<read>`
  - Classa found #deepdiff_issues.len() issue in the package
  - more specifically in its `Delta` module
]

---

=== Detected Class Pollution Source

#{
  codly(highlighted-lines: (121, 123))
  deepdiff_source_code(long: false)
}

#speaker-note[
  - we can notice here that the exploitable code is similar to the one I showed at the beginning
]

---

=== Impact

How can this be used?

#pause

- Pollute `deepdiff.serialization.SAFE_TO_IMPORT` to allow usage of `posix.system`
#pause
- Use `Delta`'s pickle constructor to run arbitrary code (@rce)

#speaker-note[
  - but in practice, how can this be used?
  - after careful investigation, deepdiff also includes a gadget via the pickle python library
  - pickle is a serialization library for python objects, which opens the door for remote code execution
  - deepdiff has measures in place to secure this via an allow list of modules
  - this can be bypassed with class pollution by adding posix.system to this allow list
  - we can then use the gadget to achieve rce
]

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

#speaker-note[
  - after finding the vulnerability, we performed a search on github for repositories that used
    the vulnerable `Delta` class
  - we found one repository that fed the payload from an unauthenticated http request
    into the Delta class, exposing the system to RCE
  - this validates this vulnerability affects production systems
]

---

=== CVE

#figure(
  caption: [Security advisory for *deepdiff* as a result of the findings of #TheTool],
  image("./assets/cve.svg", width: 30cm),
)

#speaker-note[
  - this vulnerability was reported to both of these projects
  - resulting in a CVE being assigned to deepdiff
  - with severity critical 10/10
  - after initial contact, fix was issued within 24h
]

= Discussion & Future#(sym.space.nobreak)Work

== Mitigations

- Prevent traversal through dunder attributes

#{
  set text(0.96em)
  mitigation_example
}

#speaker-note[
  - you might be thinking, how can we prevent these types of attacks
  - the mitigation is really simple, and involves just checking if the attribute being traversed starts and ends with underscores
  - if so, abort the traversal
]

== Limitations

=== Non-Goals

- Gadget detection

#pause

=== Shortcomings

- Complex traversals (e.g., through functions)
- Requires presence of `setattr`

#speaker-note[
  - this project also has a few limitations
  - first, this project is aiming at identifying the pollution step, not the gadgets
  - second, there are certain code paths that can in theory lead to class pollution,
    but are not detected by Classa, such as `<read>`
]

== Future Work

- Automatic pattern labeling
- Improve false positive rate
- Gadget detection

#speaker-note[
  - as for future work, we would like to see some way to automatically label the patterns
    of vulnerable code paths, as it allows prioritising results by exploitability
  - then, improving the false positive rate is also important,
    as any noise in the results wastes time in manual auditing
  - finally, there is room to now investigate a way to systematically detect the gadgets that can be used
    for class pollution
]

= Conclusion

== Conclusion

- Dangerous consequences
- Exploitable in real-world scenarios (*#cve("CVE-2025-58367")*)
- Uncommon vulnerability

#speaker-note[
  - so, to conclude this presentation
  - we have seen the dangerous consequences of class pollution
  - and how it can be exploited in real-world applications, as demonstrated by the CVE we obtained
  - despite being relatively uncommon, it is a novel type of vulnerability that has not gotten
    much attention, meaning vulnerable code might have gone unnoticed for a long time
  - given the possible impact, it is important to continue the research on this topic
]

#title-slide()
