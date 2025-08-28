// data analysis
#import "../utils/global-imports.typ": lq
#import "../utils/constants.typ": TheTool, gh_color, pypi_color

#let raw_data = json("../assets/summary.json")

#let filter_list(list, predicate, inv: false) = {
  if inv {
    list.filter((..args) => not predicate(..args))
  } else {
    list.filter(predicate)
  }
}

#let by_platform(platform) = {
  project => project.at("platform") == platform
}
#let by_has_issues(project) = {
  project.at("issues").len() > 0
}
#let by_is_vulnerable(project) = {
  project.at("issues").any(issue => issue.at("label").at("kind") == "Vulnerable")
}

#let median(list) = {
  let sortedList = list.sorted()
  let len = sortedList.len()
  if calc.rem(len, 2) == 0 {
    let middle = calc.quo(len, 2)
    (sortedList.at(middle - 1) + sortedList.at(middle)) / 2
  } else {
    let middle = calc.quo(len, 2)
    sortedList.at(middle)
  }
}

#let calc_popularity(list) = {
  let popularity = list.map(project => project.at("popularity"))
  let min = calc.min(..popularity)
  let max = calc.max(..popularity)
  let median = median(popularity)
  (
    popularity: popularity,
    min: min,
    max: max,
    median: median,
  )
}

#let pypi_projects = filter_list(raw_data, by_platform("PyPI"))
#let gh_projects = filter_list(raw_data, by_platform("GitHub"))

#let pypi_popularity = calc_popularity(pypi_projects)
#let gh_popularity = calc_popularity(gh_projects)

#let total_runtime_seconds = raw_data.map(project => project.at("elapsed_seconds")).sum()

#let has_issues_pypi_projects = filter_list(pypi_projects, by_has_issues)
#let has_issues_gh_projects = filter_list(gh_projects, by_has_issues)
#let has_issues_projects = filter_list(raw_data, by_has_issues)
#let no_issues_pypi_projects = filter_list(pypi_projects, by_has_issues, inv: true)
#let no_issues_gh_projects = filter_list(gh_projects, by_has_issues, inv: true)
#let no_issues_projects = filter_list(raw_data, by_has_issues, inv: true)

#let vulnerable_pypi_projects = filter_list(has_issues_pypi_projects, by_is_vulnerable)
#let vulnerable_gh_projects = filter_list(has_issues_gh_projects, by_is_vulnerable)
#let vulnerable_projects = filter_list(has_issues_projects, by_is_vulnerable)
#let not_vulnerable_pypi_projects = filter_list(has_issues_pypi_projects, by_is_vulnerable, inv: true)
#let not_vulnerable_gh_projects = filter_list(has_issues_gh_projects, by_is_vulnerable, inv: true)
#let not_vulnerable_projects = filter_list(has_issues_projects, by_is_vulnerable, inv: true)

// text
= Evaluation <results>

As part of @rq-tool-design[] and @rq-widespread[], this degree project aims
to evaluate the performance of #TheTool in regards to its accuracy at
detecting class pollution.
#TheTool is first tested against a small set of handcrafted benchmarks,
as per @results:micro-benchmarks, and then executed on dataset
consisting of popular @pypi and GitHub packages, as described in @results:analysis.

Finally, in @results:case-study, a case study is performed on a popular
library that is vulnerable to class pollution, enabling @rce on a
real-world application.

== Micro Benchmarking <results:micro-benchmarks>

#text(fill: red, lorem(100))

== Empirical Study <results:analysis>

#text(fill: red, lorem(20))

=== Dataset

#let gh_total_count = 8822
#let gh_date = datetime(year: 2025, month: 7, day: 16)
#let pypi_total_count = 15000
#let pypi_excluded_count = 6
#let pypi_dataset_date = datetime(year: 2025, month: 8, day: 1)
#let pypi_version_date = datetime(year: 2025, month: 8, day: 14)

#let format_popularity(n) = {
  if n >= 1000000000 {
    [#calc.quo(n, 1000000000)B]
  } else if n >= 1000000 {
    [#calc.quo(n, 1000000)M]
  } else if n >= 1000 {
    [#calc.quo(n, 1000)k]
  } else {
    str(n)
  }
}

As mentioned in @method:data-collection, the tool has been run on a set of
@pypi and GitHub projects, for a total of #raw_data.len() projects.

The public @pypi download count dataset used contained a total of
#pypi_total_count entries, as of #pypi_dataset_date.display().
Some packages were so old they did not provide any wheels nor source tarballs,
but instead only provided the legacy eggs format.
Other packages were deleted, did not follow conventional filename formats
(#link("https://peps.python.org/pep-0625/")[PEP 625]),
or some of their files were missing from the latest version.
The #pypi_excluded_count packages where that was the case were ignored for simplicity,
resulting in #(pypi_total_count - pypi_excluded_count) valid entries.
Then, #pypi_projects.len() packages were sampled according to the method described in
@method:data-collection, and a link to their latest wheel or source tarball was
saved on #pypi_version_date.display().

On the other hand, as of #gh_date.display(), there were only #gh_total_count Python
repositories with more than 1000 stars on GitHub.
Similarly, of the #gh_total_count repositories, #gh_projects.len()
were sampled as previously described, and their latest revision (i.e., commit)
information was fetched on the same date.


#let popularity-tick-formatter(ticks, ..) = {
  ticks.map(format_popularity)
}
#figure(
  caption: [
    Popularity (downloads for @pypi, stars for GitHub) distribution for the
    projects in the dataset
  ],
  [
    #lq.diagram(
      width: 11cm,
      height: 2.5cm,
      yaxis: (ticks: (block(width: 1.4cm)[@pypi],).enumerate()),
      xaxis: (position: top, mirror: true, format-ticks: popularity-tick-formatter),
      xscale: "log",
      xlabel: [Downloads],
      lq.hboxplot(stroke: pypi_color, y: 0, pypi_popularity.popularity),
    )

    #lq.diagram(
      width: 11cm,
      height: 2.5cm,
      yaxis: (ticks: (block(width: 1.4cm)[GitHub],).enumerate()),
      xaxis: (format-ticks: popularity-tick-formatter),
      xscale: "log",
      xlabel: [Stars],
      lq.hboxplot(stroke: gh_color, y: 0, gh_popularity.popularity),
    )
  ],
) <fg:popularity-distribution>

Due to the sampling method used, the final dataset contains a wide range of packages
when it comes to their popularity.
For @pypi packages, the download count ranges from #format_popularity(pypi_popularity.min)
to #format_popularity(pypi_popularity.max) downloads, with a median of
#format_popularity(pypi_popularity.median) downloads.
For GitHub packages, the star count ranges from #format_popularity(gh_popularity.min)
to #format_popularity(gh_popularity.max) stars, with a median of
#format_popularity(gh_popularity.median) stars.
The distribution for each platform can be visualised on @fg:popularity-distribution.

=== Results

#let format_time(seconds) = {
  [#calc.round(seconds / (60 * 60), digits: 1) hours]
}

#let manual_categorisation_time_seconds = 39608 // from timewarrior

Analysing the projects in the dataset using #TheTool took a total of
#format_time(total_runtime_seconds) of runtime, and an additional
#format_time(manual_categorisation_time_seconds) of manual labeling work
by a single person. However, the runtime duration is skewed by a few
projects that triggered a bug in Pysa and got stuck in a loop, being killed
after a 30 minute timeout.
// TODO: say runtime without timed out projects
During analysis, #TheTool has been run exclusively on a shared machine with an
AMD EPYC 7742 64-core processor and 512GB of memory, although limited to
using only 32 cores.

Out of the #raw_data.len() projects analysed, a total of #no_issues_projects.len()
(#{ (no_issues_projects.len() / raw_data.len()) * 100 }%)
did not have any issues found by #TheTool.
Furthermore, amongst the remaining #has_issues_projects.len() projects with issues,
only #vulnerable_projects.len() have at least one issue that was deemed vulnerable.
As can be seen by @fg:projects-issue, the amount of vulnerable projects varies
slightly by platform, with only #vulnerable_pypi_projects.len() @pypi projects
being vulnerable in contrast with #vulnerable_gh_projects.len() GitHub projects.

#figure(
  caption: [Visualisation of how many projects have been found to possibly
    contain a class pollution vulnerability, discriminated by platform.],
)[
  #let x_pypi = range(3)
  #let y_pypi = (
    vulnerable_pypi_projects.len(),
    not_vulnerable_pypi_projects.len(),
    no_issues_pypi_projects.len(),
  )
  #let x_gh = range(3)
  #let y_gh = (
    vulnerable_gh_projects.len(),
    not_vulnerable_gh_projects.len(),
    no_issues_gh_projects.len(),
  )

  #lq.diagram(
    width: 10cm,
    height: 7cm,
    legend: (position: left + top),
    ylabel: [Number of Projects],
    xaxis: (
      ticks: ("Vulnerable", "Only False Positives", "No Issues").enumerate(),
      subticks: none,
    ),
    yaxis: (exponent: none),

    lq.bar(
      x_pypi,
      y_pypi,
      offset: -0.2,
      width: 0.4,
      fill: pypi_color,
      label: [@pypi],
    ),
    lq.bar(
      x_gh,
      y_gh,
      offset: 0.2,
      width: 0.4,
      fill: gh_color,
      label: [GitHub],
    ),

    ..x_pypi
      .zip(y_pypi)
      .map(((x, y)) => {
        let align = if y > 200 { top } else { bottom }
        lq.place(x - 0.2, y, pad(0.2em)[#y], align: align)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        let align = if y > 200 { top } else { bottom }
        lq.place(x + 0.2, y, pad(0.2em)[#y], align: align)
      }),
  )
] <fg:projects-issue>

== Case Study: Vulnerable Library <results:case-study>
