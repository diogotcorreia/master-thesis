#import "@preview/timeliney:0.2.0"

#import "utils/template.typ": in_page_cover, header, footer, setup_page, kthblue
#import "utils/enum-references.typ": setup_enum_references, wrapped-enum-numbering, enum-label

#let title = [Uncovering Class Pollution in Python]
#let date = datetime(year: 2025, month: 3, day: 17)
#let keywords = (
  "python",
  "taint analysis",
  "code reuse",
  "class pollution",
  "static analysis",
)

#show: setup_page
#show: setup_enum_references

#set page("a4", header: header(title: title), footer: footer())

#in_page_cover(
  title: title,
  subtitle: [Degree Project Individual Plan],
  date: date.display("[month repr:long] [year]"),
)

= Project Information
// Preliminary title, that indicates what the degree project will be about.
// The name and e-mail address of the student
// The name of the examiner at KTH
// The name of the supervisor at KTH
// The name and e-mail address of the supervisor, if the thesis is performed outside KTH
// Current date
// Keywords

- *Preliminary Title:* #title
- *Student:* Diogo Correia (#link("mailto:diogotc@kth.se"))
- *Examiner:* Prof. Roberto Guanciale (#link("mailto:robertog@kth.se"))
- *Supervisor:* Prof. Musard Balliu (#link("mailto:musard@kth.se"))
- *Date:* #date.display("[weekday], [month repr:long] [day padding:none], [year]")
- *Keywords:* #keywords.join(", ")

= Background & Objective
// Description of the area within which the degree project is being carried out with connection to scientific and/or societal interest.
// Description of the interest of the organization or company who provided the assignment.
// The high level objective of the project, the desired outcome from the perspective of the assignment provider.
// The background knowledge required to carry out the project.

For the past decades, researchers have been investigating how to manipulate
the execution flow of programs.
This was prevalent in C/C++ compiled code, which could be vulnerable to
memory corruption and therefore susceptible to techniques such as
Shellcode execution and Return Oriented Programming (ROP). // TODO sources

In contrast with compiled languages, the now widely used interpreted programming
languages (such as JavaScript, Python, PHP, etc.) are generally immune against
those techniques, since allocations are handled by the interpreter instead. // TODO sources
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
the Python programming language @pp-python.

The *Python programming language* was created in 1991 by Guido van Rossum and has since
seen immense adoption from the programming community, with more than 50% of the respondents
of the 2024 StackOverflow Survey
#link("https://survey.stackoverflow.co/2024/technology/#most-popular-technologies")[having worked with or want to work with it].
It is used for many applications, such as scripting, web applications, machine learning, and much
more.
Some high-profile open-source programs that extensively use Python are
#link("https://github.com/home-assistant/core")[Home Assistant],
#link("https://github.com/yt-dlp/yt-dlp")[yt-dlp]
and
#link("https://github.com/ansible/ansible")[ansible],
along hundreds of companies like Netflix, Google and Reddit
that use it for their products as well. // TODO sources
For this reason, Python is a very valuable target for malicious attackers
and therefore extremely relevant for security researchers.

In Python, *class pollution* consists in changing properties of a class/superclass
or even the global namespace through Python's internal accessors (e.g.,
`__class__`, `__base__`, `__globals__`, etc.).
This behaviour is similar to, although slightly more limited than, JavaScript's
prototype pollution, which various studies have concluded to be widespread
and can result in severe vulnerabilities like Remote Code Execution (RCE)
@silent-spring and Cross-Site Scripting (XSS) @probetheproto.

This project aims to uncover how widespread this vulnerability
is and if any of the discovered vulnerabilities are exploitable in practice,
allowing developers to patch their respective applications.
Additionally, a systematic investigation of the root causes of class pollution
will help developers avoid dangerous constructs.

= Research Questions & Method
// QUESTION: State the question that will be examined. Formulate it as an explicit and evaluable question. State your hypothesis.
// Objectives: Break down the research questions to measurable objectives.
// Tasks: Describe the tasks that are necessary to reach the objectives. For each task, describe the challenges it involves.
// Method: Describe the method/s that will be followed. Explain why they are appropriate for the project or for the specific tasks.

The degree project has the goal of answering the following four research questions:

#[
  #set enum(numbering: wrapped-enum-numbering((..nums) => [*RQ#numbering("1.", ..nums)*]))
  + #enum-label("rq-causes-consequences")
    What are the root causes and possible consequences of class pollution
    in a Python application?
  + #enum-label("rq-tool-design")
    How to design and implement a tool that can efficiently and accurately
    detect class pollution in Python?
  + #enum-label("rq-widespread")
    Is class pollution in Python widespread and exploitable in
    real world applications?
  + #enum-label("rq-cmp-pp")
    How does class pollution in Python compare to prototype pollution
    in JavaScript when it comes to exploitability and widespreadness?
]

These questions are explained below in more detail, along with their objectives, tasks and methods.

== @rq-causes-consequences[] Root Causes and Consequences of Class Pollution

Answering this research question is key for the remaining work in this project,
since its goal is to identify all the different forms class pollution can take
in Python, along with what some possible consequences are.
While this project is only aimed at discovering class pollution and not at exploiting it,
identifying possible consequences is still important for the motivation of the project
as well as to generate awareness among developers.

To achieve this objective, a literature review will be performed, along with a systematic
investigation by observing interpreter behaviour, which together will allow for creating
a list of different constructs that can pollute internal properties of Python classes,
as well as a list of valuable targets to pollute.

== @rq-tool-design[] Efficient and Accurate Tool Implementation

This is the most important and laborious research question, consisting in the
development of a tool that can be ran against a Python codebase and flag potential
code paths that can result in class pollution.

It is imperative that the tool is as efficient and accurate as possible
(i.e., it has a short runtime and low false positive/negative rate),
and ideally requiring little human intervention
given that in @rq-widespread[] it will be ran against many different codebases.

To achieve these objectives, the tool will be built on top of
#link("https://pyre-check.org/docs/pysa-basics/")[Pysa], a static taint
analysis engine designed by Meta.
Given the dynamic and loose-typing nature of the Python programming language,
it is impossible to have perfect static taint analysis, but the use of Pysa will
abstract most of these complexities away, while allowing focus to be placed on
the specifics of the problem at hand.

The tool should be able to find all the dangerous constructs found in @rq-causes-consequences[]
and, ideally, perform validation automatically.
To ensure this, a set of artificial benchmarks will be written and then the tool
will be run against them, revealing initial results regarding its accuracy,
which will then be validated by the results obtained through @rq-widespread[].

== @rq-widespread[] Widepreadness and Exploitability of Class Pollution

Equipped with the tool from @rq-tool-design[], it can now be run against various different
Python libraries and applications in order to determine how widespread class pollution is.

The first step is picking which libraries and applications will be analyzed.
To ensure a representative sample of various different packages, a selection
of 3000 packages will be downloaded from #link("https://pypi.org/")[PyPI], the largest
Python repository.
These packages will be sourced from three different cohorts:
- the 1000 most downloaded packages in the last month;
- 1000 packages picked randomly from the 1001-9000 most downloaded packages in the last month;
- the 9001-10000 most downloaded packages in the last month.

It is theorized that less frequently downloaded packages could be undergo less rigorous testing
and scrutiny, therefore having a higher probability of being vulnerable to class pollution,
hence the emphasis on testing less popular packages.
These numbers are subject to adjustments if they are found to not be appropriate for the
timeline of the project.

Additionally, some other applications not available on PyPI or otherwise with lower download
counts could also be tested if they are deemed relevant in the scope of this project.

Finally, the obtained results will then be used to draw conclusions inductively and generalize
widepreadness and exploitability to the entire Python ecosystem.

== @rq-cmp-pp[] Comparison to Prototype Pollution

With this research question, the aim is to compare the results obtained from @rq-causes-consequences[]
and @rq-widespread[] with prior work on prototype pollution, such as #cite(<ghunter>, form: "prose") and
#cite(<pp-yinzhi-cao>, form: "prose"), and reach a conclusion on which one is more prevalent.

To achieve this, both quantitative and qualitative properties will be taken into account,
such as what percentage of packages are vulnerable, how easy it is to exploit, and
how severe the consequences are.

Furthermore, given what is already known by class pollution (i.e., pollution requires the use of
`getattr` followed by `setattr`), it is hypothesised that this Python vulnerability will be
less widespread than its JavaScript counterpart, where pollution happens through the very
commonly used square bracket notation (e.g., `obj[key]`).

== Ethics & Sustainability
// Ethics and Sustainability: Does the project address questions of ethics or sustainability? Does the project raise ethical or sustainability questions? If yes, how could these be handled?

Given that this study will be solely performed on source-available projects, and that all vulnerabilities will be
responsibly disclosed to the respective developers and maintainers within a reasonable timeframe,
this project does not raise ethical questions.

Moreover, while this project is not directly related to sustainability, it will serve a role in
securing various applications that could be directly related to sustainability.

== Limitations
// Limitations: Define the limitations on what is to be done (so that it is clear what is not included in the degree project).

This project is aimed at designing a tool that can identify code paths potentially vulnerable
to class pollution.
It is, however, not aimed at identifying consequences of said pollution in specific programs,
but only in general as a motivation for this work, as per @rq-causes-consequences[].


== Risks
// Risks: Explain what can go wrong and delay or make the project impossible to conclude. Explain how you will deal with these problems.

The proposed project is rather ambitious and it can certainly take more time than expected.
The most likely scenario is that the tool developed as per @rq-tool-design[] cannot be fully
completed on time, and will therefore be missing some features like automated validation, which can
cascade into reduced data for @rq-widespread[] and @rq-cmp-pp[].

If that is the case, it might be necessary to decrease the number of packages analysed in @rq-widespread[]
in order to allow for manual validation, reducing the external validity of the experiment.

#pagebreak()

= Evaluation & News Value
// Evaluation: How is it determined if the objectives of the degree project have been fulfilled and if the research question has been adequately answered? What kind of qualitative or quantitative measures can be defined and evaluated?
// Expected scientific results: How is the work scientifically relevant?
// The work's innovation/news value. Why does someone want to read the finished work? And who are these people?

The objectives of the project are deemed fulfilled if the resulting tool can successfully identify most
cases of class pollution in the written artificial benchmarks, and has a low false positive rate
when run against real-world programs.
The project is still considered a success even if no class pollution vulnerabilities are found in
the tested programs, since there might not exist any.

Given the impact that prototype pollution can have in JavaScript applications @silent-spring, it is
important to know if the same can be achieved in other widely-used languages, such as Python.
For that reason, the answers to the proposed research questions are extremely relevant to security-conscious
developers and members of the Python community as a whole.

= Pre-study
// Description of the literature studies. What areas will the literature study focus on? How shall the necessary knowledge on background and state-of-the-art be obtained? What preliminarily important references have been identified?

The pre-study will mainly focus on answering @rq-causes-consequences[] and gathering ideas for @rq-tool-design[]
based on existing similar state-of-the-art tools.
Furthermore, a study on existing works related to class pollution in Python will be conducted, in order to
avoid overlap with any existing research.

There has been little research in the topic at hands, but some important references might be, for example,
"Research and Explore of Prototype Pollution Attack in Python" (#cite(<pp-python>, form: "year")) @pp-python
and the blog post "Prototype Pollution in Python" (#cite(<pp-python-blog>, form: "year")) @pp-python-blog.
Moreover, the tools developed for JavaScript prototype-pollution are also of interest, namely
Silent Spring @silent-spring, GHunter @ghunter and Probe the Proto @probetheproto.

#pagebreak()

= Conditions & Schedule
// List of the resources are needed to solve the problem. This can be technical equipment, software, or data, but also experiment and interview subjects.
// Describe the way the external supervisor will be involved in the project.
// Provide a project timeline, specifying the main tasks and the time allocated for them, milestones (time of achievement of intermediate goals)

The developed tool will interface with Pysa, which is written in Python and OCaml
#footnote[
  Pysa is currently being rewritten in Rust, but it is only expected to be
  #link("https://github.com/facebook/pyre-check/tree/897a035baabe731e50f833b8b749739463bd230f/pyre2")[
    complete at the end of 2025
  ],
  which makes it unviable for the timeline of this project
],
and will be developed in Rust.
When the tool is completed, it will be tested against many different open-source
projects, which are expected to be fetched from PyPI.
At the same time, the student will work on the Degree Project Report, which will
be written in #link("https://typst.app/")[Typst].

Based on the objectives and tasks outlined in this document, a preliminary timeline for this project
can be found on @timeline.

// Preparation (W10 - W13)
// - literature review (W10 - W12)
// - pre-study drafting (W12 - W13)
// Tool Development (W14 - W19)
// - Artificial Benchmarks (W14 - W15)
// - Taint Analysis (W15 - W19)
// - Automatic Validation (W18 - W19)
// Evaluation (W19 - W22)
// - Artificial Benchmarks (W19)
// - Gather PyPI Projects (W19 - W20)
// - Tool Execution (W20 - W22)
// - Tool Adjustments (W21 - W22)
// Reporting (W10 - W27)
// - Final Report Drafting (W23 - W24)
// - Presentation Preparation (W24 - W25)
// - Final Revision (W25 - W27)

#figure(
  caption: "Gantt chart of preliminary degree project timeline",
  text(
    size: 0.8em, // fit on last page
    {
      timeliney.timeline(
        show-grid: true,
        milestone-line-style: (stroke: (dash: "dashed", paint: kthblue)),
        {
          import timeliney: *

          let subtask(..args) = task(..args, style: (stroke: 3pt + gray))

          let months = ("March", "April", "May", "June", "July")
          headerline(..months.map(m => group(strong(m))))

          taskgroup(
            title: [*Preparation (4w)*],
            {
              subtask("Literature Review (3w)", (0, 0.75))
              subtask("Pre-Study Drafting (2w)", (0.5, 0.875))
            },
          )

          taskgroup(
            title: [*Tool Development (6w)*],
            {
              subtask("Artificial Benchmarks (2w)", (0.875, 1.25))
              subtask("Taint Analysis (5w)", (1.125, 2.25))
              subtask("Automatic Validation (2w)", (1.75, 2.25))
            },
          )

          taskgroup(
            title: [*Evaluation (4w)*],
            {
              subtask("Artificial Benchmarks (1w)", (2, 2.25))
              subtask("Gather PyPI Projects (2w)", (2, 2.5))
              subtask("Tool Execution (3w)", (2.25, 3))
              subtask("Tool Adjustments (2w)", (2.5, 3))
            },
          )

          taskgroup(
            title: [*Reporting (>5w)*],
            {
              subtask(
                "Final Report Drafting (>2w)",
                (from: 0, to: 3, style: (stroke: (dash: "densely-dotted", thickness: 2pt, paint: gray))),
                (3, 3.5),
              )
              subtask("Presentation Preparation (2w)", (3.25, 3.75))
              subtask("Final Revision (3w)", (3.5, 4.25))
            },
          )

          let milestone-text(name, date) = align(
            center,
            text(
              fill: kthblue,
              [
                *#name* \
                #date
              ],
            ),
          )

          milestone(
            at: 0.875,
            milestone-text("Pre-Study Submission", "Mar 2025"),
          )

          milestone(
            at: 3.5,
            anchor: "north-east",
            milestone-text("Report Submission", "Jun 2025"),
          )

          milestone(
            at: 3.75,
            milestone-text("Oral Presentation", "Jun 2025"),
          )

          milestone(
            at: 4.25,
            anchor: "north-west",
            milestone-text("Final Submission", "Jul 2025"),
          )
        },
      )
    },
  ),
) <timeline>

#pagebreak()
#bibliography("references.yml", title: "References")
