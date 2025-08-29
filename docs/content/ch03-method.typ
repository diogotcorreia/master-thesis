= Methods <method>

This chapter goes over over the research methods used in
this degree project, along with how they are fit for this work.
Firstly, @method:research-process describes the research method
used to answer the established research questions.
Secondly, @method:data-collection goes over how the dataset used for
@rq-widespread was obtained and its characteristics.
Finally, @method:evaluation goes over how the results given by
the accompanying tool were evaluated.

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

== Data Collection <method:data-collection>

In order to answer @rq-widespread[],
there was a need to obtain a set of Python applications
to analyse for class pollution.
This section describes how the list of projects was obtained
and how that ensures the external validity of the experiments.

Instructions on how to run the scripts to obtain the dataset
as described below can be found in the `data` directory of the
accompanying repository and in @usage.

=== Sampling

When deciding what projects to analyse, both Python libraries and
applications were considered.
While @pypi contains mostly libraries, many open-source applications
are present exclusively on GitHub.
For this reason, both sources were equally used for this degree
project's dataset.

It is important to note that the threat model can vary between libraries
and applications, as code in libraries can be used in many ways by downstream
projects, while code in applications is usually exclusively used within the
same codebase.
This is taken into account when determining the exploitability of the
vulnerabilities found, later on.

#heading(level: 4, numbering: none, outlined: false)[PyPI]

While @pypi does not make the download counts for each package readily
available, due to challenges of keeping accurate statistics, it publishes a
Google BigQuery dataset that other projects can use @pypi-downloads.
One of those projects is #link("https://hugovk.github.io/top-pypi-packages/")[Top PyPI Packages],
which provides a monthly dump of the 15 thousand most downloaded @pypi packages.
That dump has been used to generate part of the dataset used in this degree project,
assuming that download count would correlate with the overall usage of the
package in downstream projects.

Additionally, to aid with reproducibility of this research, the URL of one
of the wheels (Python's binary packaging format as defined by
#link("https://peps.python.org/pep-0427/")[PEP 427]) of the latest version
of each package was immediately saved.
If no wheel was available, the URL of source tarball was saved instead.

#heading(level: 4, numbering: none, outlined: false)[GitHub]

There is a vast amount of projects on GitHub, so only
Python repositories with more than 1000 stars were taken into account
for this dataset.
For the purposes of this experiment, a project's star count was deemed
a good indicator of its real-world usefulness and its overall usage.
Additionally, a repository is deemed a "Python repository" if its most used
language is Python, as per GitHub's linguist library, which determines
language distribution by file type and size @gh-linguist.

Furthermore, again to aid with reproducibility of this research,
the last revision (i.e., commit) of the default branch of each repository
was saved in the dataset.

=== Sample Size

Both the @pypi and GitHub datasets contain too many entries to
be analysed in a reasonable time, given the scope of this degree project.
For that reason, only a subset of entries in each dataset will be
taken into account during evaluation.

In order to ensure a representative population, each dataset was sorted
by popularity (downloads for the @pypi dataset, and stars for GitHub's),
and then split into three cohorts: the $N$ least popular projects,
the $N$ most popular projects, and the remaining projects.
The value of $N$ has been picked based on the number of total entries
for each platform, and has been fixed as #box($N = 3000$) for @pypi and
#box($N = 1000$) for GitHub.
Then, 500 projects were randomly sampled from each cohort,
resulting in a total of 1500 projects for each platform,
and a final dataset of size 3000.
This process is pictured in @fg:dataset-cohorts.

#figure(
  // TODO
  rect(fill: red, height: 10em, lorem(5)),
  caption: [Splitting the intermediate datasets into cohorts to obtain the final dataset],
) <fg:dataset-cohorts>

== Evaluation Framework <method:evaluation>

As there is no public dataset of projects vulnerable to class pollution,
evaluation has to be predominantly done manually.
There are 5 projects known to be or have been vulnerable, and those were
analysed separately, as none of them is present in the final dataset.

Each of the hits produced by the tool manually tagged as either vulnerable
or not vulnerable (i.e., a false positive).
The reasons for a hit to not be vulnerable were also stored alongside
the verdict, and are later presented in @results.
