#import "../utils/constants.typ": TheTool
#import "../utils/global-imports.typ": pep

= #TheTool <thing>

#TheTool is a @cli tool that can run taint analysis on any Python project,
coming preloaded with taint models to discover class pollution, as per the
goals of this project.
This chapter describes the design of this tool in @thing:design,
enumerates the built-in taint models in @thing:taint-models,
and explains its implementation in @thing:impl.

== Software Design <thing:design>

#figure(
  // TODO
  rect(fill: red, height: 10em, [
    ALT: A flowchart style diagram that shows all the steps taken
    during the analysis of the full dataset.
  ]),
  caption: [Analysis pipeline for each entry in the dataset using #TheTool],
) <fg:tool-flowchart>

The architecture of the tool can be divided into four major steps:
optionally resolving dependencies; running taint analysis;
result processing; and issue labeling.
Additionally, two external tools are heavily used by #TheTool:
*uv*#footnote[https://docs.astral.sh/uv/], a modern Python package
manager by Astral, is used for resolving and installing dependencies;
and *Pysa*#footnote[https://pyre-check.org/docs/pysa-basics/],
a static analyser by Meta (formerly Facebook), is used to perform
taint analysis on a Python project.

Analysis starts with by reading the provided
dataset file and performing actions for each project in it.
Firstly, if not already done, the source is downloaded,
either from PyPI or from GitHub, and the tarball saved to disk.
Secondly, the downloaded archive is extracted to a working directory,
where the analysis will be performed.
Thirdly, optionally and if enabled, requirement files are searched to
compile a list of all dependencies, and then *uv* is used to install
them.
Then, the Pysa configuration files are setup in the analysis directory,
and Pysa begins running.
Lastly, once taint analysis is done, the results from Pysa are read,
processed to remove false positives, and saved to a report file
in the JSON format.

Then, a human has to go through all the issues raised by Pysa
and label them as either vulnerable or not vulnerable, and why.
This step is aided by #TheTool, by allowing a user to quickly
inspect the issue and apply a label to it.

Finally, analysis ends with the results being combined into
a single `summary.json` file,
which stores a high-level view of the issues found.

Further information on how each of these stages is implemented
can be found on @thing:impl.

=== Dependencies

As mentioned, #TheTool is able to detect which dependencies
are needed for a given project and install them before
performing taint analysis.
While Pysa can work without installing the dependencies of the
project being analysed, it benefits from more information
in order to provide accurate taint propagation.
Otherwise, Pysa would fallback to the so-called obscure models
when reaching references to third-party code,
which just assume that all taint from the arguments of a function
call is propagated to its outputs.
Furthermore, installing dependencies has the benefit that the
dependencies of the project are also analysed for class pollution,
therefore significantly increasing the number of projects analysed.

However, installing dependencies can significantly slow down analysis,
as well as introduce false positives, as later explored in @results:install-deps.
For that reason, installing dependencies is optional and is
disabled by default.

== Taint Models <thing:taint-models>

Out of the box, #TheTool provides Pysa taint models that are able to
identify class pollution, as can be seen in @code:pysa-taint-models.
These models assume that class pollution can be identified by a flow from
the return value of `getattr` (`TaintSource`) to the first argument of `setattr` (`TaintSink`),
given the conclusion of the literature review in @bg:lit-review.

#figure(caption: [Pysa taint models that detect class pollution])[
  ```py
  @SkipObscure
  def getattr(
      __o: TaintInTaintOut[Via[customgetattr]],
      __name,
      __default: TaintInTaintOut[LocalReturn],
  ) -> TaintSource[CustomGetAttr, ViaValueOf[__name, WithTag["get-name"]]]: ...

  @SkipObscure
  def setattr(
      __o: TaintSink[CustomSetAttr],
      __name,
      __value,
  ): ...
  ```
] <code:pysa-taint-models>

While class pollution can also be achieved using `__setitem__` as a sink instead of
`setattr`, Pysa does not accurately support this due to the lack of type information,
so it was assumed that most instances of class pollution would at least contain
a call to `setattr`.
Similarly, `__getitem__` is not accounted for, since taint already flows through it to
the sink.

Additionally, these models contain extra annotations (e.g., `Via`, `ViaValueOf`, `WithTag`, etc.)
that instruct Pysa to collect information that can later be used to filter out
false positives.

== Implementation <thing:impl>

There are various parts directly and indirectly related to
the implementation of #TheTool.
To ensure the reproducibility of the experiments, Nix has
been used to provide fixed versions of Pysa, uv, Python,
the Rust compiler, and more, as described in @thing:nix.
Then, the various scripts used to generate a dataset
as described in @method:data-collection, were made using Python
and are explained in @thing:dataset-gen.
Finally, the @cli for #TheTool has been made using Rust, as outlined
in @thing:cli, due to its performance, correctness,
and the author's familiarity with the language.

The full source code for #TheTool can be found in the accompanying repository
#footnote(link("https://github.com/diogotcorreia/master-thesis"))
on GitHub.

=== Nix <thing:nix>

While Nix is not the cornerstone of this project, it is still
nonetheless important for ensuring the reproducibility of the
results.
Due to its build sandbox and pinned inputs, using Nix ensures the
environment is the same regardless of the underlying Linux distribution,
even well into the future.
This is especially important given that this project uses an unstable
version of Pysa, with some patches applied, and Nix allows this
setup to be easily reproduced at any point in time.
Additionally, other programs necessary for building and running
#TheTool, such as Python and the Rust compiler, are also pinned.
Instructions on how to use this environment can be found on @usage.

=== Dataset Generator <thing:dataset-gen>

To run #TheTool across a large number of projects,
a `dataset.toml` file is needed,
containing source information about each project that needs
to be analysed.
This TOML file contains information for each project,
such as a unique identifier,
information for downloading the source code,
and some metadata such as number of starts or download count.
In case of @pypi projects, the source information contains the package
name, the version, an archive name,
and a direct download URL for the respective archive.
On the other hand, for GitHub projects, the owner and repository name
are stored, along with a commit revision to use.

For this reason, some Python scripts have been developed to automatically
gather a dataset matching the specifications outlined in @method:data-collection.
These scripts gather packages from @pypi and repositories from GitHub,
and then randomly sample 3000 projects across both datasets,
saving them in the aforementioned TOML format.

#heading(level: 4, numbering: none, outlined: false)[PyPI]

Expanding on what has already been outlined in @method:sampling,
once the list of the 15 thousand most downloaded @pypi packages
is saved, a script is run to determine the latest version of
each package and its download URL.
While this seems trivial at first, not all packages provide so-called
wheels for every operating system, requiring some decision logic to
decide which file needs to be downloaded during analysis.

To fetch information about a package, the script uses the JSON-based Simple API
as defined by #pep(691), which provides the list of versions as
well as a list of all downloadable archives across all versions.
The latest version is saved, along with all the archives belonging to that version.

Then, it is necessary to decide which archive is the best to perform taint analysis
on.
While it is unlikely this will have a significant impact since only the `.py`
are relevant for Pysa, some projects could have a different build system
per platform.
For that reason, archives are sorted according to preference, and then
the preferred archive is the one that has its download URL saved in the dataset.
For the purposes of this experiment, binary distributions (wheels) are preferred
over source distributions, and between binary distributions, preference is based
on platform, opting for a universal wheel whenever possible and
falling back to Linux, MacOS and Windows archives if not, in this order.
Other compatibility tags of each wheel, as defined in #pep(425),
are also taken into account, such as ABI, and implementation tags,
where a universal archive is preferred, but accepting a CPython archive
as well.
If a source binary is chosen, the script prefers a `.tar.gz` archive
as defined by #pep(625), but also accepts `.tar.bz2`, `.tgz` and `.zip`
as long as they follow the same file name convention.

#heading(level: 4, numbering: none, outlined: false)[GitHub]

To obtain a list of Python GitHub repositories with more than 1000 stars,
GitHub's Search API was used,
namely the `/search/repositories` endpoint.
While this endpoint has a limit of 100 items per page and a maximum of 10
pages (effectively a 1000 items limit), it is possible to tweak the
search parameters to bypass this restriction.
In particular, one can first search for all the repositories with more
than 1000 stars, sorted by most stars, and then search only for repositories
with less than the star amount of the last repository in the previous query.
All requests made to the GitHub API respect the rate-limit and appropriately
wait if it is exceeded, with safeguards in place in case this logic fails.
Additionally, all responses are cached to reduce the amount of requests needed.

Then, this list is passed to a separate script that fetches the latest revision
of the default branch for each repository.
This is implemented through the `git ls-remote` command, as GitHub claims
it does not have a rate limit for Git operations @gh-git-operations-limit.
This Git command fetches the latest revision for each reference (branches, tags)
in the remote repository, and the output is then parsed and validated to ensure
the correct reference has been fetched.
All this data is again cached to prevent querying GitHub multiple times
for the same data.

Finally, the list of repositories and revisions is joined together in the
same file, ready to be sampled.

#heading(level: 4, numbering: none, outlined: false)[Sampling]

A separate script handles sampling the 3000 projects from both sources,
picking 1500 from each platform.
This script has two main roles: performing the random sampling, and writing
the final `dataset.toml` file in the format expected by #TheTool.
The sampling is done via Python's `random.sample` function,
ran for each cohort,
as defined previously in @method:sample-size.
Then, for each project,
the script generates a unique identifier,
in the format `pypi.<name>` for @pypi packages
and `gh.<owner>.<repo>` for GitHub repositories,
compiles all the required source information
and metadata in the required format,
and finally writes to the `dataset.toml` file.

=== #TheTool CLI <thing:cli>

The CLI contains various subcommands, of which the most important
one is `e2e`, which runs the entire automated pipeline for a given dataset.
Then, the subcommand `label` starts prompting the user to manually label
the issues found, while the `summary` subcommand generates the `summary.json`
file as previously explained.
There are also subcommands `analyse` and `results`, which run the pipeline
for a single project and analyse results from Pysa, respectively,
but will not be explained here as they simply execute parts of the
actions carried out by `e2e`.
For usage instructions, see @usage.


==== Automated Pipeline

The automated pipeline can be triggered by providing a dataset file to
the `e2e` subcommand.
#TheTool will then run until completion without human interaction, and
report on which projects contain issues, that is, code that could be
vulnerable to class pollution.
To achieve this, a series of steps are performed sequentially,
for each project in the dataset.

Firstly, before any analysis can be done, the tool needs to fetch
the code it wants to analyse.
For @pypi repositories, it simply downloads the archive from the provided URL.
For GitHub repositories, it uses the repository name and Git revision present in
the dataset to download a tarball from `github.com/<repo>/archive/<rev>.tar.gz`.
This is then saved into the `workdir/tarballs` directory,
so if the analysis is run again, there is no need to re-download the code.
While @pypi and GitHub are the only supported source for fetching code, the implementation
and dataset format can be easily extended to support other sources in the future.
Then, for each analysis, this code is unpacked into the `workdir/analysis/<dir>/src`
directory, where `<dir>` is a directory named after the ID of the project being analysed
and a timestamp, so that there can exist multiple directories for each project.

Secondly, to handle resolving and installing dependencies,
when enabled,
#TheTool uses uv, which has been chosen for its speed,
ease of use, and support for modern Python features,
such as #pep(751) (`pylock.toml`).
Another relevant feature of uv when performing batch analysis of many
projects is that the dependencies are saved in a single place on the
system, and then hard linked for each project, saving a lot of disk space.
Before the analysis, all dependency files
(e.g., `requirements.txt`, `pyproject.toml`, etc.) present in the repository
are fed into uv which outputs a `pylock.toml`.
This lock file is later used to install these dependencies into the
`workdir/analysis/<dir>/deps` directory, so Pysa can use them during analysis.
It is frequent that some Python packages require linking against system
libraries during a build, even if that is irrelevant for the analysis,
so, for that reason, some common native dependencies (e.g., database drivers,
crypto libraries, etc.) are provided via Nix.

Thirdly, #TheTool writes the necessary configuration files for Pysa
in the analysis directory,
namely `.pyre_configuration`, `taint.pyre_config`
#footnote[
  It is worth noting that the `.pyre_config` extension is a modification to
  Pysa made for this project, since the `.config` extension sometimes collided
  with existing files in the projects, and is implemented via a patch in the Nix
  package.
] and `sources_sinks.pysa`.
Then, it executes Pysa to perform the analysis by invoking it
via the command line and capturing its stdout.

After the analysis is performed, there is also a need to parse
Pysa's output, which is done by compiling the information
present in the `pysa-results/taint-output.json` file
into a list of taint traces that highlight
how the taint flows from the source to the sink.

Unfortunately, Pysa lacks documentation about its output format,
as it is made to be used with their own tool,
sapp#footnote(link("https://github.com/facebook/sapp")).
This was an implementation challenge, as it made reconstructing entire
flow from source to sink quite difficult.
Fortunately, reading the source code for sapp helped with parsing
the relevant data, and #TheTool is able to accurately reconstruct
the appropriate traces.

To reduce the amount of false positives, issues that are labeled
by Pysa with features `tito-broadening` or `obstruct:model` are discarded.
The former means that taint collapsing occurred on a taint-in-taint-out
function, while the latter indicates that Pysa could not fully analyse
the code because parts of it are missing,
usually due to some dependencies not being installed.
These are both strong indicators that the taint does not flow directly
from the source to the sink,
as in, the return value of `getattr` is modified before reaching `setattr`,
which is a requirement to achieve class pollution,
as outlined in @bg:lit-review.
Hence, these issues are automatically discarded in this phase.

Furthermore, the tool also supports filtering out issues based on
the presence of the `via:customgetattr` feature,
as defined in the taint models shown in @code:pysa-taint-models.
When this feature is present, it means there are at least two
`getattr` calls chained together,
which is a requirement for class pollution, in accordance with @bg:lit-review.
Therefore, the lack of this feature tag is a strong indicator that
the issue is a false positive,
so the issue can be automatically discarded.

Finally, the #TheTool finishes the automated pipeline by writing
a JSON report for each project, which includes some information
from the dataset, such as name, source, and popularity, but
also the results from the analysis, namely
the issues found,
errors if any,
the duration of the analysis,
raw issue count from Pysa before filtering,
and list of installed dependencies if any.

==== Manual Labeling

Once the reports have been generated for all projects in the dataset,
a user can invoke the `label` subcommand to start a manual labeling session.
When invoked, #TheTool will search the reports directory for all the
reports and find the issues that are not yet labeled.

Then, the user is presented with the source code of the potentially vulnerable
package,
annotated with the various steps of the taint trace and with the source
and sink highlighted.
This allows the user to quickly identify the source and sink, and look at
the surrounding context to determine the label to apply to the issue.

Once the user has decided the label to apply,
they can select the appropriate label and reasoning in the prompt that
shows up beneath the source code.
This data is then saved into the same JSON report file by updating its
contents.

=== Removed Features

During early development of the #TheTool, a different approach to
taint models was taken.
Instead of using only the models shown in @code:pysa-taint-models,
it contained models with `UserControlled` sources
for many popular Python frameworks and libraries,
which then allowed it to configure Pysa to look for places where the
`UserControlled` and `CustomGetAttr` sources reached a sink at
the same time.

This required the installation of dependencies,
as well as keeping track of which dependencies and respective versions
were installed,
in order to load the appropriate taint models into Pysa.

It was also necessary to manually write taint models for each popular library.
While Pysa ships with some taint models for third-party libraries
by default, some of them were outdated,
and therefore had to be manually fixed.
This would have been a significant part of the work,
and even then it would never cover all versions of all used libraries,
and it was one of the reasons this approach was abandoned.

The full list of reasons for abandoning this approach,
as well as related discussion, can be found in @results:user-controlled-taint
and @discussion respectively.
