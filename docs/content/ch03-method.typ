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

In order to answer @rq-widespread[] and @rq-cmp-pp[],
there was a need to obtain a set of Python applications
to analyse for class pollution.
This section describes how the list of projects was obtained
and how that ensures the external validity of the experiments.

// dataset of python github repos >= 1000 stars

=== Sampling

Due to the design and requirements of the tool, further explained
in @thing, the list of projects to analyse should mostly consist
of applications rather than libraries.
For this reason, @pypi is not a good candidate for obtaining a list
of projects, since more of the packages present are libraries,
and are not meant to be used as standalone programs.
Therefore, GitHub, which contains a wide range of open-source
repositories, was used as the source for this degree project's dataset.
Even though libraries are still present on GitHub, applications are
also prevalent.

There is a vast amount of projects on GitHub, so only
Python repositories with more than 1000 stars were taken into account
for this dataset.
For the purposes of this experiment, a project's star count was deemed
a good indicator of its real-world usefulness and its overall usage.
Additionally, a repository is deemed a "Python repository" if its most used
language is Python, as per GitHub's linguist library, which determines
language distribution by file type and size @gh-linguist.

To obtain this dataset, GitHub's Search API was used, in particular the
`/search/repositories` endpoint.
While this endpoint has a limit of 100 items per page, and a maximum of 10
pages (effectively a 1000 items limit), it is possible to tweak the
search parameters to bypass this restriction.
In particular, one can first search for all the repositories with more
than 1000 stars, sorted by most stars, and then search only for repositories
with less than the star amount of the last repository in the previous query.

Furthermore, to aid with reproducibility of this research,
the last revision of the default branch of each repository was saved
in the dataset.
That revision will be the one analysed later by the tool described in
@thing.

Instructions on how to run the scripts to obtain this dataset
can be found in the `data` directory of the accompanying repository
and in @usage.

=== Sample Size

There are #text(fill: red)[8000] Python repositories with more
than 1000 stars on GitHub.
These are too many repositories, so only a subset of those
are used for the analysis.

In order to ensure a representative population, the dataset was
split into three cohorts: the 1000 most starred, the 1000 least
starred, and the remaining repositories.
Then, 500 repositories were picked randomly from each of the cohorts,
resulting in a final dataset of 1500 repositories.
This process is pictured in @fg:dataset-cohorts.

#figure(
  // TODO
  rect(fill: red, height: 10em, lorem(5)),
  caption: [
    Splitting the intermediate dataset into cohorts to obtain
    the final dataset
  ],
) <fg:dataset-cohorts>

== Evaluation Framework

#lorem(20)
