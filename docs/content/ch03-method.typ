#import "../utils/global-imports.typ": pep

= Methods <method>

This chapter goes over over the research methods used in
this degree project, along with how they are fit for this work.
Firstly, @method:research-process describes the research method
used to answer the established research questions.
Then, @method:data-collection goes over how the dataset used for
@rq-widespread was obtained and its characteristics.

== Research Process <method:research-process>

To answer @rq-tool-design[] and @rq-widespread[],
different processes need to be defined, and are therefore
described by each of the subsections below.
Regarding @rq-causes-consequences[],
it has already been addressed by a systematic literature review
in @bg:lit-review, consequently it is not included in this section.

Additionally, @fg:research-process provides a visual
representation of the research process adopted in this
thesis, as outlined below.

#figure(
  // TODO
  rect(fill: red, height: 10em, lorem(5)),
  caption: "Visual representation of the research process",
) <fg:research-process>

=== Tool Design <method:tool-design>

To fulfill @rq-tool-design[], there is the need to decide how
to build a tool that can detect class pollution.
Taking into account the results of the literature review,
the cornerstone requirement is that it can find code where the
return value of `getattr` is passed onto the arguments of `setattr`.
As this is a classic taint analysis problem, a static taint analysis
tool, Pysa, has been chosen as the base for this tool.

However, Pysa offers many different settings and
approaches to configuring the project for taint analysis,
as well as metadata alongside the results,
revealing the need to optimally adjust settings and procedures during analysis.
For this reason, various combinations of settings, taint modules,
project configurations, and more,
were tested against custom-built artificial benchmarks,
as well as projects known to be vulnerable,
in order to decide what approach to take for the final design.
These benchmarks, while not perfect,
model common constructs that can lead to class pollution
and are a great replacement for the lack of a larger dataset of
known-vulnerable packages.

A major decision for the design of the tool is whether to consider
each project's dependencies during analysis.
While taking dependencies into account should, in theory,
increase the accuracy and scope of the taint analysis,
it comes with a trade off in complexity and execution time.
There are also significant challenges when regarding
the installation of those dependencies that need to be overcome,
as the Python ecosystem is quite fragmented when it comes to
dependency handling.

Furthermore, another relevant design choice is which taint models
to define, as in, which sources and sinks should exist.
Evidently, the there must be a source in the return value of `getattr`,
and a sink in the first argument of `setattr`,
but there are other sources and sinks to consider as well.
For instance, Pysa has functionality for partial sinks,
where it requires two or more sources to reach the same
sink at the same time, i.e., in the same call site.
Using this feature, it is possible to focus on code exploitable
using class pollution by forcing the second parameter
of `setattr` to be tainted by user controlled input.

Finally, Pysa offers the option to annotate taint flows with _features_,
also known as breadcrumbs,
which enables post-processing of the resulting issues to eliminate false positives.
Recalling the literature review, a requirement for successful exploitation
of class pollution is being able to traverse an arbitrary number of attributes.
Therefore, an interesting feature to save is how many times the taint flows
through `getattr` before reaching the sink.
This can then be used to filter out code where there is only a single
call to `getattr`.

These three design ideas were tested against the aforementioned
benchmarks, and the results are presented in @results:tweaks.

=== Vulnerability Prevalence

As a means to determine the prevalence of class pollution, as
outlined by @rq-widespread[], an empirical study is performed
where the designed tool is tested against
a dataset of Python libraries and applications.
In this study, the tool will analyse each project individually
to determine if it has any code that is vulnerable to class pollution.
Then, to determine the precision of the designed tool,
each of the reported hits is then manually tagged as either vulnerable
or not vulnerable (i.e., a false positive).
Additionally, the reasons for each verdict were also stored alongside it,
as a means to help future work.

Furthermore, a case study is conducted,
where one of the packages deemed vulnerable is investigated in more detail.
Here, the causes for detection will be highlighted,
and, if applicable,
a proof of concept exploit will be created to demonstrate
the impact of the vulnerability.

Finally, the results from the empirical study,
and the case study to a lesser extent,
are used to inductively infer the prevalence
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

=== Sampling <method:sampling>

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
#pep(427)) of the latest version
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

=== Sample Size <method:sample-size>

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
