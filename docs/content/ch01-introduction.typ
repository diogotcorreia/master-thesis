#import "../utils/enum-references.typ": wrapped-enum-numbering, enum-label

= Introduction <intro>

For the past few decades, researchers have been investigating how the execution
flow of programs can be manipulated.
This is especially prevalent in C/C++ compiled code, which can be vulnerable to
memory corruption and therefore susceptible to techniques such as
Shellcode execution and Return Oriented Programming (ROP) @rop-payload-detection @rop-geometry.

In contrast with compiled languages, the now widely used interpreted programming
languages (such as JavaScript, Python, PHP, etc.) are generally immune against
those techniques, since allocations are handled by the interpreter instead @meaning-memory-safety.
However, they open the door for different kinds of vulnerabilities not previously
possible, such as code reuse attacks, which, in certain languages, can be easily
overlooked by developers when iterating on a codebase.

*Code reuse* attacks take advantage of existing code in an application to
execute (sometimes arbitrary) code flows that were not intended by its developers,
having the potential to perform malicious actions.
This class of attacks can take various forms, such as object injection @php-object-injection,
prototype pollution @pp-yinzhi-cao, class pollution, and more, depending
on language-specific features.
While the former two have been the focus of many studies throughout the years,
there has been little research done on class pollution in
the Python programming language @pp-python. // TODO: consider removing this reference

== Problem

- unknown prevalence of class pollution
- no tool that can detect it

#lorem(100)

== Research Questions

The degree project has the goal of answering the following four research questions:

#[
  #set enum(
    numbering: wrapped-enum-numbering(
      ref-numbering: (..nums) => [*RQ#numbering("1.1", ..nums)*],
      (..nums) => [*RQ#numbering("1.1.", ..nums)*],
    ),
  )
  + #enum-label("rq-causes-consequences")
    What are the root causes and possible consequences of class pollution
    in a Python application?
  + #enum-label("rq-tool-design")
    How to design and implement a tool that can efficiently and accurately
    detect class pollution in Python?
  + #enum-label("rq-widespread")
    Is class pollution in Python prevalent and exploitable in
    real world applications?
  + #enum-label("rq-cmp-pp")
    How does class pollution in Python compare to prototype pollution
    in JavaScript when it comes to exploitability and prevalence in
    the real-world?
]

// TODO: expand?

== Purpose

- generate awareness for this type of vulnerabilities in python programs
- inspire future research on the topic

#text(fill: red, lorem(50))

== Goals

This project aims to uncover how widespread Python class pollution
is and if any of the discovered vulnerabilities are exploitable in practice,
allowing developers to patch their respective applications.
Additionally, a systematic investigation of the root causes of class pollution
will help developers avoid dangerous constructs.

#text(fill: red, lorem(100))

== Ethics & Sustainability

// TODO rewrite since there is missing context because this is at the beginning

Given that this study will be solely performed on source-available projects, and that all vulnerabilities will be
responsibly disclosed to the respective developers and maintainers within a reasonable timeframe,
this project does not raise ethical questions.

Moreover, while this project is not directly related to sustainability, it will serve a role in
securing various applications that could be directly related to sustainability.

== Limitations

This project is aimed at designing a tool that can identify code paths potentially vulnerable
to class pollution.
It is, however, not aimed at identifying consequences of said pollution in specific programs,
but only in general as a motivation for this work, as per @rq-causes-consequences[].

== Structure of the Thesis

#text(fill: red, lorem(50))
