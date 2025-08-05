#let TheTool = text(fill: red)[The Tool]

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
  rect(fill: red, height: 10em, lorem(5)),
  caption: [
    Analysis pipeline for each entry in the dataset using #TheTool.
  ],
) <fg:tool-flowchart>

The architecture of the tool can be divided into three major steps:
resolving dependencies; running taint analysis; and result processing.
Additionally, two external tools are heavily used by #TheTool:
*uv*#footnote[https://docs.astral.sh/uv/], a modern Python package
manager by Astral, is used for resolving and installing dependencies;
and *Pysa*#footnote[https://pyre-check.org/docs/pysa-basics/],
a static analyser by Meta (formerly Facebook), is used to perform
taint analysis on a Python project.

Each of these three steps plays a major role in order to obtain
a successful analysis.
While Pysa can work without installing the dependencies of the
project being analysed, it benefits from more information
in order to provide accurate taint propagation.
Otherwise, Pysa would fallback to the so-called obscure models,
which just assume that all taint from the arguments of a function
call is propagated to its outputs.
Furthermore, installing dependencies has the benefit that the
dependencies of the project are also analysed for class pollution,
therefore significantly increasing the number of projects analysed.
After the analysis is performed, there is also a need to parse
Pysa's output, which is done by compiling the information
present in the output into a list of taint traces that highlight
how the taint flows from the source to the sink.
Further information on how each of these stages is implemented
can be found on @thing:impl.

Finally, #TheTool prints a summary of the analysis, highlighting
which projects might have class pollution, errors, warnings, and
those that are deemed safe from class pollution.

=== Analysis Outcome

#lorem(50)

== Taint Models <thing:taint-models>

#lorem(50)

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

#text(fill:red, lorem(50))

// - python scripts (3 scripts + random picker)
// - save cache, etc
// - explain fields saved
// - format of the dataset

=== #TheTool CLI <thing:cli>

// TODO explain commands

The CLI contains various subcommands, of which the most important
one is `e2e`, which runs the entire pipeline for a given dataset.
There are also subcommands `analyse` and `results`, which run the pipeline
for a single project and analyse results from Pysa, respectively.
For briefness, only the implementation of `e2e` will be explained,
as the other subcommands use parts of this implementation as well.
This subcommand takes a mandatory dataset file in the TOML format,
and may take an optional _workdir_, of which the default is a
temporary directory.

Firstly, before any analysis can be done, the tool needs to fetch
the code it wants to analyse.
To achieve this, it uses the GitHub repository and Git revision present in
the dataset to download a tarball from `github.com/<repo>/archive/<rev>.tar.gz`.
This is then saved into the `workdir/tarballs` directory,
so if the analysis is run again, there is no need to re-download the code.
While GitHub is the only supported source for fetching code, the implementation
and dataset format can be easily extended to support other sources in the future.
Then, for each analysis, this code is unpacked into the `workdir/analysis/<dir>/src`
directory, where `<dir>` is a directory named after the project being analysed
and a timestamp, so that there can exist multiple directories for each project.

Secondly, to handle resolving and installing dependencies,
#TheTool uses uv, which has been chosen for its speed,
ease of use, and support for modern Python features,
such as PEP751 (`pylock.toml`).
Another relevant feature of uv when performing batch analysis of many
projects is that the dependencies are saved in a single place on the
system, and then hard linked for each project, saving a lot of disk space.
Before the analysis, all dependency files
(e.g., `requirements.txt`, `pyproject.toml`, etc.) present in the repository
are fed into uv which outputs a `pylock.toml`.
// TODO: explain different kinds of dependency files?
This lock file is later used to install these dependencies into the
`workdir/analysis/<dir>/deps` directory, so Pysa can use them during analysis.
It is frequent that some Python packages require linking against system
libraries during a build, even if that is irrelevant for the analysis,
so, for that reason, some common native dependencies (e.g., database drivers,
crypto libraries, etc.) are provided via Nix.

// TODO
