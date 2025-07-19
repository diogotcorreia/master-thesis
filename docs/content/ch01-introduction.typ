#import "../utils/enum-references.typ": enum-label, wrapped-enum-numbering

= Introduction <intro>

For the past few decades, researchers have been investigating how the execution
flow of programs can be manipulated.
This is especially prevalent in C/C++ compiled code, which can be vulnerable to
memory corruption and therefore susceptible to techniques such as
Shellcode execution and @rop @rop-payload-detection @rop-geometry.

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

There are currently no tools that can identify constructs that can lead to class
pollution, nor any indication of how prevalent this vulnerability is across existing
Python applications.
As seen with similar vulnerabilities, such as prototype pollution @silent-spring @ghunter, there
is a possibility that the impact of class pollution could be high, leading to,
for example, Authorization Bypass, @dos, @rce, and/or @ssti.
For this reason, it is paramount to better understand what is the potential
impact and prevalence of this vulnerability, as well as possible countermeasures
to protect against it.

The specifics of the problem are further outlined in @bg:python.

== Research Questions

This degree project aims to answer the following four research questions:

#[
  #set enum(numbering: wrapped-enum-numbering(
    ref-numbering: (..nums) => [*RQ#numbering("1.1", ..nums)*],
    (..nums) => [*RQ#numbering("1.1.", ..nums)*],
  ))
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

These reflect the iterative process of understanding the vulnerability at
hands, going over how to efficiently identify it, testing existing
applications for its presence, and, finally, reaching a conclusion on
how it compares to similar vulnerabilities.

== Purpose

The purpose of this project is to generate awareness for this vulnerability
in Python programs amongst the Python developer community.
As previously stated, there has not been previous substantial research on this topic,
and therefore the Python developers might not be aware of it, writing
constructs that could lead to class pollution.
If developers are aware of the existence of class pollution and its countermeasures,
they can avoid writing vulnerable programs.

Additionally, it hopes to inspire future research on the topic, which could improve
the automated detection of class pollution, as outlined in @discussion:futurework.

== Goals

This project aims to uncover how widespread Python class pollution
is amongst a sample of source-available Python projects,
and if any of the discovered vulnerabilities are exploitable in practice,
allowing developers to patch their respective applications.
Additionally, a systematic investigation of the root causes of class pollution,
as per @rq-causes-consequences[], will help developers avoid dangerous constructs.

Finally, this thesis also aims to perform a quantitative and qualitative
comparison between class pollution in Python and prototype pollution in JavaScript,
going over how prevalent they are and what conditions are necessary for them
to be exploitable in practice.

== Ethics & Sustainability

As further outlined in @method, the designed tool has been run against various
source-available projects that can be downloaded from @pypi.
All vulnerabilities found during the elaboration of this project have been
responsibly disclosed to the respective developers and maintainers within a reasonable
time frame, following standard disclosure procedures.

Additionally, while this tool could be used maliciously to detect class pollution
in unpatched projects, the benefits for developers far outweigh the drawbacks in
regards to exploitability, as the vulnerability can be quickly identified and
fixed.

Moreover, while this project is not directly related to sustainability, it will serve
an important role in securing various Python applications that could be directly related
to sustainability.

== Limitations

This project is aimed at designing a tool that can identify code paths potentially vulnerable
to class pollution.
It is, however, not aimed at identifying consequences of said pollution in specific programs,
but only in general as a motivation for this work, as per @rq-causes-consequences[].

== Contributions

// TODO: go back to research questions, provide an answer
// say which section it is discussed in

#text(fill: red, lorem(50))

== Structure of the Thesis

// TODO: to be written at the end

#text(fill: red, lorem(50))
