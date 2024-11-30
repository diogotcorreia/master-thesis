#import "template.typ": in_page_cover, header, footer, setup_page

#let title = [Uncovering Class Pollution in Python]
#let date = [December 2024]

#show: setup_page

#set page("a4", header: header(title: title), footer: footer())

#in_page_cover(title: title, date: date)

= Thesis Title
// [Provide a preliminary title, which gives an indication of what the
// degree project will be about]

#title

= Background
// [Name and briefly describe the research area within which the project
// is being carried out. Describe how the project is connected to current
// research or development. Describe why the project is of interest and
// to whom, and in particular explain the interest of the organization or
// company within which the project is carried out.]

Through the use of static and/or dynamic code analysis, this work in
this thesis will consist of creating a tool that can detect class pollution
in the Python programming language, followed by running this tool in various
open-source libraries and applications.

Class pollution consists in changing properties of a class/superclass or
even the global namespace through Python's internal accessors (e.g.,
`__class__`, `__base__`, `__globals__`, etc.).
This behaviour is similar to, although slightly more limited than, JavaScript's
Prototype Pollution, which various studies have concluded that is widespread
and can result in severe vulnerabilities like Remote Code Execution (RCE) @silent-spring.

The results of this project will uncover how widespread this vulnerability
is and if any of the found vulnerabilities are exploitable in practice.

= Research Questions
// [A degree project must investigate a specific research/technical
// question. Provisionally state the question that the project will
// target.]

- *RQ1:* How to design a tool that can efficiently and accurately detect
  class pollution in Python?
- *RQ2:* What is the impact of class pollution in vulnerable Python application?
- *RQ3:* Is class pollution in Python widespread and exploitable in
  real world applications?
- *RQ4:* How does class pollution in Python compare to prototype pollution
  in JavaScript when it comes to exploitability and widespreadness?

= Hypothesis
// [What is the expected outcome of the investigation?]

It is hypothesised that very few applications in the real world are
vulnerable to class pollution due to the specific conditions necessary
for pollution.
Additionally, the impact of the vulnerabilities will likely be reduced
due to the scope of the pollution being mostly on the same class.

Furthermore, when compared to JavaScript where prototype pollution
happens through the very commonly used square bracket notation (e.g.,
`obj[key]`), Python only allows dynamically accessing the internal
properties (e.g., `__class__`) through the `setattr` and `getattr`
functions, which are less commonly used by developers.
Therefore, it is hypothesised that this Python vulnerability will be
less widespread than its JavaScript counterpart.

= Research Method
// [What method will be used for answering the research question, e.g.,
// how will observations be collected and conclusions drawn?]

= Background of the Student
// [Describe the knowledge (courses and/or experiences) you have that
// makes this an appropriate project for you.]

The student has a strong background in the subject both through courses
and research experience.
Diogo has taken the DD2525 Language-Based Security course, given by Prof.
Musard, and has been part of the LangSec group since September 2024 where
he has been researching prototype pollution in JavaScript.

= Suggested Examiner at KTH
// [You may suggest an examiner at KTH. State if you have been in contact
// with the examiner and received a preliminary expression of interest to
// serve as examiner.]

= Suggested Supervisor at KTH
// [You may suggest a supervisor at KTH. State if you have been in
// contact with the supervisor and received a preliminary expression of
// interest to serve as supervisor.]

Musard Balliu (#link("mailto:musard@kth.se"))

= Resources
// [What is already available at the company (or other host institution)
// in the form of previous projects, software, expertise, etc. that the
// project can build on?]

// TODO cite silent spring/ghunter
The LangSec group at KTH, of which Prof. Musard is part of, has been working
on Prototype Pollution in JavaScript @silent-spring @ghunter,
as well as static and dynamic code analysis.
This expertise is directly transferable to the problem at hands, due to the
similarities between the two vulnerabilities.

= Eligibility
// [Verify that you are eligible to start your degree project, that is,
// that you fulfill the basic requirements of starting the project, and
// also have completed all the courses that are relevant for the
// project.]

At the end of HT24, 91.5 credits in courses will have been completed,
of which the AK2030 Theory and Methodology of Science course is included in.

= Study Planning
// [List all the courses that you will need to complete during or after
// the degree project, and describe how and when you plan to complete
// those courses. This is aimed to ensure that the thesis really is one
// of the last elements of your education.]

No courses, with the exception of the programme integrating course DD2303,
will be taken during or after the degree project.

#bibliography("references.yml", title: "References")
