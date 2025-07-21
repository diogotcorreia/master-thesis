= Methods <method>

This chapter goes over over the research methods used in
this degree project, along with how they are fit for this work.
Firstly, @method:research-process describes the research method
used to answer the established research questions.
Secondly, @method:data-collection goes over how the dataset used for
@rq-widespread was obtained and its characteristics.
Finally, #text(fill: red, lorem(10)) // TODO

== Research Process <method:research-process>

Each of the research questions outlined in @intro:rq are
answered through different processes, described by each
of subsections below.

Additionally, @fg:research-process provides a visual
representation of the research process adopted in this
thesis.

#figure(
  // TODO
  rect(fill: red, height: 10em, lorem(5)),
  caption: "Visual representation of the research process",
) <fg:research-process>

=== Literature Review

In order to answer @rq-causes-consequences[], a literature review
has been conducted.
Given the lack of abundant scientific work on this topic,
the review has been complemented with articles and technical blog
posts from outside the research community.
Additionally, given its thoroughness, the Python specification
@python-reference-manual has been used to investigate further
constructs that can result in class pollution.

In total, two papers @pp-python-prevention @pp-python-blog,
one blog post @pp-python, and The Python Reference Manual
@python-reference-manual have been analysed in order to
compile the causes and consequences of class pollution.

As such, the results of this literature review are presented
in @results:lit-review.

=== Tool Design

#text(fill: red, lorem(50))

// TODO: develop a tool accordingly
// TODO: try tool on artificial dataset

=== Vulnerability Prevalence

As a means to determine the prevalence of class pollution, as
outlined by @rq-widespread[], the designed tool, resulting from
@rq-tool-design[], has been run against a dataset of Python
packages and applications.
Further details about the tool can be found in @thing, and the
sampling method and size are described in more detail in
@method:data-collection.

Then, the results are used to inductively infer the prevalence
over the entire universe of Python applications.

=== Comparison with Prototype Pollution

#text(fill: red, lorem(50))

// TODO: compare to existing research

== Data Collection <method:data-collection>

#lorem(10)

// dataset of python github repos >= 1000 stars

=== Sampling

#lorem(20)

=== Sample Size

#lorem(25)

=== Target Population

#lorem(30)

== Evaluation Framework

#lorem(20)
