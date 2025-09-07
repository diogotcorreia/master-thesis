#import "../utils/constants.typ": TheTool
#import "../utils/global-imports.typ": cve
#import "../utils/enum-references.typ": enum-label, wrapped-enum-numbering

= Introduction <intro>

Research over the past few decades has shown how malicious attackers
can take advantage of benign code in applications to manipulate its execution flow
and, in turn, compromise systems and data.
This control-flow manipulation has historically
been particularly prevalent in C/C++ compiled code,
which can be vulnerable to
memory corruption and therefore susceptible to techniques such as
Shellcode execution and @rop @rop-payload-detection @rop-geometry.

In contrast with compiled languages, the now widely used interpreted programming
languages (such as JavaScript, Python, PHP, etc.) are generally immune against
those techniques, since allocations are instead handled by the interpreter @meaning-memory-safety.
However, they open the door for different kinds of vulnerabilities not previously
possible, such as code reuse attacks, which can be easily
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

== Problem Statement

Class pollution is a novel type of vulnerability in Python,
that allows attackers to surgically mutate variables in a Python application
in order to alter the execution flow of said applications.

Given the potentially high impact of class pollution,
as seen by similar vulnerabilities such as prototype pollution @silent-spring @ghunter,
it is important to be able to detect and prevent possibly unsafe code from
being deployed in production applications.
Unfortunately, there are currently no tools that can identify constructs that
can lead to class pollution,
nor any indication of how prevalent this vulnerability class is across existing
Python applications.

As with similar code reuse attacks, class pollution can
potentially facilitate attacks such as Authorization Bypass, @dos, @rce, and/or @ssti.
For this reason, it is paramount to better understand what is the true
impact and prevalence of this vulnerability class, as well as possible countermeasures
to protect against it.

== Research Questions <intro:rq>

This degree project aims to answer the following three research questions:

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
    How prevalent and exploitable is class pollution in
    real world Python projects?
]

These reflect the iterative process of understanding the vulnerability at
hand, ascertaining how to efficiently identify it,
and, finally,
testing existing applications for its presence.

== Purpose and Goals

This project's primary objective is to
uncover how widespread Python class pollution is
and to empower developers with tooling to detect it.

Furthermore, this project also aims to generate awareness for class pollution
amongst the Python developer community.
As previously stated, there has not been previous substantial research on this topic,
and therefore
the Python community is largely unaware of the dangers of this type of vulnerability.
If developers are aware of the existence of class pollution and its countermeasures,
they can avoid writing vulnerable constructs that can lead to class pollution.

Additionally, it hopes to inspire future research on the topic, which could improve
the automated detection of class pollution, as outlined in @discussion:futurework.

== Ethics & Sustainability

As further outlined in @method,
the dataset of projects utilised through this degree project
contains only source-available projects that can be downloaded from @pypi and GitHub.
When obtaining this dataset,
all relevant APIs have been used sparingly and respecting the rate-limits in place,
caching all responses to prevent unnecessary duplicate requests.

Furthermore, all vulnerabilities found during the project's development have been
responsibly disclosed to the respective developers and maintainers within a reasonable
time frame, following standard disclosure procedures.

Additionally, while this tool could be used maliciously to detect class pollution
in unpatched projects, the benefits for developers far outweigh the drawbacks in
regards to exploitability, as the vulnerability can be quickly identified and
fixed.

Moreover, while this project is not directly related to sustainability, it serves
an important role in securing various Python applications that could be directly related
to sustainability.

== Limitations

This project is aimed at identifying code paths potentially vulnerable
to class pollution.
It is, however, not aimed at identifying the concrete consequences of said pollution
in specific programs,
but only in general as a motivation for this work, as per @rq-causes-consequences[].

== Contributions

This degree project provides three major contributions,
each related to one of the research questions.

Firstly, as part of @rq-causes-consequences[],
a comprehensive list of dangerous constructs that can lead to class pollution
and some examples of accompanying gadgets
have been gathered and are available in @bg:lit-review.

Secondly, as a result of @rq-tool-design[],
#TheTool has been created,
becoming the first publicly available tool specifically built
to detect class pollution in Python projects.

Lastly, in relation to @rq-widespread[],
an empirical study
assessing the prevalence of class pollution
has been conducted over 3000 popular Python packages,
resulting in the responsible disclosure of a critical severity vulnerability,
tracked by #cve("CVE-2025-58367").

== Structure of the Thesis

Technical background related to code reuse attacks in other programming
languages is presented in @bg,
along with the results of a literature review of the causes and consequences
of class pollution,
and a general overview of taint analysis and Pysa.
Then, in @method, the research method to be used is established,
and followed by a high-level description of the implementation of #TheTool in @thing.
After that, the evaluation and its results are presented in
@results and discussed in @discussion.
Finally, in @conclusion, this degree project's final conclusions and reflections
are explored.
