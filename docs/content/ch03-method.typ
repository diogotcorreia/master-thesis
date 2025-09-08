#import "../utils/constants.typ": gh_color, pypi_color
#import "../utils/global-imports.typ": fletcher, pep
#import fletcher: diagram, edge, node, shapes

= Methods <method>

This chapter goes over over the research methods used in
this degree project, along with how they are fit for this work.
Firstly, @method:research-process describes the research method
used to answer the established research questions.
Then, @method:data-collection goes over how the dataset used for
@rq-widespread[] was obtained and its characteristics.

== Research Process <method:research-process>

To answer @rq-tool-design[] and @rq-widespread[],
different processes need to be defined, and are therefore
described by each of the subsections below.
@rq-causes-consequences[] is not included in this section because
it has already been addressed by a systematic literature review
in @bg:lit-review.

=== Tool Design <method:tool-design>

To fulfill @rq-tool-design[], it is necessary to decide how
to build a tool that can effectively detect class pollution in arbitrary Python programs.
Taking into account the results of the literature review,
the cornerstone requirement for such a detector is that it can find code where the
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
are small custom-written Python programs that
model common constructs that can lead to class pollution
and are a great replacement for the lack of a larger dataset of
known-vulnerable packages.

Importantly, a major design decision for such a tool is whether to consider
each project's dependencies during analysis.
While taking dependencies into account should, in theory,
increase the accuracy and scope of the taint analysis,
it comes with a trade off in complexity and execution time.
There are also significant challenges that need to be overcome regarding
the installation of those dependencies,
as the Python ecosystem is quite fragmented when it comes to
dependency handling.

Furthermore, another relevant design choice is which taint models
to define, as in, which sources and sinks should exist.
Evidently, there must be a source in the return value of `getattr`,
and a sink in the first argument of `setattr`,
but there are other sources and sinks to consider as well.
For instance, Pysa has functionality for partial sinks,
where it requires two or more sources to reach the same
sink at the same time, i.e., in the same call site.
Using this feature, it is possible to focus on code exploitable
using class pollution by requiring the second parameter
of `setattr` to be tainted by user controlled input for an issue to be raised.

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

=== Vulnerability Prevalence <method:vuln-prevalence>

As a means to determine the prevalence of class pollution,
the primary concern of @rq-widespread[],
this project's work includes an empirical study,
where the designed tool is tested against
a dataset of Python libraries and applications.
Concretely, the developed tool is used to
analyse each project individually and
determine if it has any code that could be vulnerable to class pollution.
Afterwards, to determine the precision of the designed tool,
each of the reported hits is manually tagged as either vulnerable
(i.e., a true positive) or not vulnerable (i.e., a false positive)
and stored together with the concrete reasons for why it was
tagged that way (as a means to help future work).

Moreover, in order to better understand class pollution in a real-world scenario,
one package in particular is selected from those deemed vulnerable,
so that it can be investigated in more detail in a case study.
Here, the package is explored in detail,
the causes for detection are laid out,
and a proof-of-concept exploit is presented
to demonstrate and assess the impact of the vulnerability.

Finally, the results obtained from the empirical study
(and, to some extent, the case study),
can be used to inductively infer the prevalence of class pollution
over the entire universe of Python applications.

== Data Collection <method:data-collection>

As described in @method:vuln-prevalence,
in the course of answering @rq-widespread[],
it became necessary to select a set of Python applications
to analyse for potential susceptibility to class pollution.
The present section describes how this list of projects was obtained,
and why the selection procedure ensures the external validity of the experiments.

Automated data collection was an important part of this process:
multiple Python scripts were created to facilitate the various steps
described in this section.
Instructions on how to run the scripts to obtain the dataset
as described below can be found in the `data` directory of the
accompanying repository and in @usage.

=== Sampling <method:sampling>

When deciding what projects to analyse, both Python libraries and
applications were considered.
While @pypi (the most used Python package repository) contains mostly libraries,
many open-source applications are present exclusively on GitHub,
so both sources were equally used for this degree
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
for this dataset,
accounting to around 9000 repositories.
For the purposes of this experiment, a project's star count was deemed
a good indicator of its real-world usefulness and its overall usage.
Additionally, a repository is deemed a "Python repository" if its most used
language is Python, as per GitHub's linguist library, which determines
language distribution by file type and size @gh-linguist.

Furthermore, again to aid with the reproducibility of this research,
the last revision (i.e., git commit hash) of the default branch of
each repository was saved in the dataset.

=== Sample Size <method:sample-size>

Both the @pypi and GitHub datasets contain too many entries to
be analysed in a reasonable time, given the scope of this degree project.
For that reason, only a subset of entries in each dataset will be
taken into account during evaluation.

#let n_pypi = 3000
#let n_github = 1000
#let cohort_size = 500
#let platform_size = cohort_size * 3
#let dataset_size = platform_size * 2

In order to ensure a representative population, each dataset was sorted
by popularity (downloads for the @pypi dataset, and stars for GitHub's),
and then split into three cohorts: the $N$ least popular projects,
the $N$ most popular projects, and the remaining projects.
The value of $N$ has been chosen based on the number of total entries
for each platform, and has been fixed as #box($N = #n_pypi$) for @pypi and
#box($N = #n_github$) for GitHub.
Then, #cohort_size projects were randomly sampled from each cohort,
resulting in a total of #platform_size projects for each platform,
and a final dataset of size #dataset_size.
This process is pictured in @fg:dataset-cohorts.

#figure(
  [
    #set text(size: 9pt)
    #diagram(
      spacing: (0mm, 15mm),
      node-stroke: luma(70%),
      node((0, 0), [#n_pypi packages], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((0, 1), [#cohort_size \ packages], width: 2cm),
      edge("dr", "-|>"),
      node((1, 0), [... packages], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((1, 1), [#cohort_size \ packages], width: 2cm),
      edge("d", "-|>"),
      node((2, 0), [#n_pypi packages], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((2, 1), [#cohort_size \ packages], width: 2cm),
      edge("dl", "-|>"),

      node(enclose: ((0, 2), (2, 2)), [*Final Dataset:* #dataset_size projects]),

      node(
        enclose: ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, -1)),
        fill: pypi_color.lighten(90%),
        stroke: pypi_color,
        align(center + top)[*@pypi Packages*],
      ),
      node(
        enclose: ((0, 0), (1, 0), (2, 0)),
        shape: shapes.stretched-glyph.with(
          glyph: sym.arrow,
          dir: top,
          length: 100% + -2cm,
          sep: -.2em,
          label: [sorted by downloads],
        ),
      ),

      node((0, 4), [#n_github repositories], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((0, 3), [#cohort_size \ repositories], width: 2cm),
      edge("ur", "-|>"),
      node((1, 4), [... repositories], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((1, 3), [#cohort_size \ repositories], width: 2cm),
      edge("u", "-|>"),
      node((2, 4), [#n_github repositories], width: 4.2cm),
      edge("-|>", label: [_randomly pick_], label-side: center),
      node((2, 3), [#cohort_size \ repositories], width: 2cm),
      edge("ul", "-|>"),

      node(
        enclose: ((0, 3), (1, 3), (2, 3), (0, 4), (1, 4), (2, 4), (1, 5)),
        fill: gh_color.lighten(90%),
        stroke: gh_color,
        align(center + bottom)[*GitHub Repositories*],
      ),
      node(
        enclose: ((0, 4), (1, 4), (2, 4)),
        shape: shapes.stretched-glyph.with(
          glyph: sym.arrow,
          dir: bottom,
          length: 100% + -2cm,
          sep: -.2em,
          label: [sorted by stars],
        ),
      ),
    )
  ],
  caption: [Splitting the intermediate datasets into cohorts to obtain the final dataset],
) <fg:dataset-cohorts>
