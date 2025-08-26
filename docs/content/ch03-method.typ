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

=== Comparison with Prototype Pollution

#text(fill: red, lorem(50))

// TODO: compare to existing research

== Data Collection <method:data-collection>

In order to answer @rq-widespread[] and @rq-cmp-pp[],
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

==== @pypi

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

Some packages were so old they did not provide any wheels nor source tarballs,
but instead only provided the legacy eggs format.
Other packages were deleted, did not follow conventional filename formats
(#link("https://peps.python.org/pep-0625/")[PEP 625]),
or some of their files were missing from the latest version.
The 6 packages where that was the case were ignored for simplicity.

==== GitHub

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

Furthermore, again to aid with reproducibility of this research,
the last revision of the default branch of each repository was saved
in the dataset.
That revision will be the one analysed later by the tool described in
@thing.

For the final dataset, the GitHub Search API, as well as the latest revision
of each repository, were queried on #datetime(year: 2025, month: 8, day: 14).display().

=== Sample Size

There are 8822 Python repositories with more
than 1000 stars on GitHub.
Similarly, the aforementioned @pypi dataset contains #(15000 - 6) entries.
These are too many projects, so only a subset of those
are used for the analysis.

In order to ensure a representative population, the GitHub dataset was
split into three cohorts: the 1000 most starred, the 1000 least
starred, and the remaining repositories.
Then, 500 repositories were picked randomly from each of the cohorts,
resulting in an intermediate dataset of 1500 repositories.
The process was again repeated for the @pypi dataset, but instead splitting into
the 3000 most downloaded, the 3000 least downloaded, and the remaining packages.
Similarly, 500 packages were picked randomly from each of the cohorts,
resulting into another intermediate dataset of 1500 packages.
This process is pictured in @fg:dataset-cohorts.

#figure(
  // TODO
  rect(fill: red, height: 10em, lorem(5)),
  caption: [
    Splitting the intermediate datasets into cohorts to obtain
    the final dataset
  ],
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
