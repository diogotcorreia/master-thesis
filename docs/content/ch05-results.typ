// data analysis
#import "../utils/global-imports.typ": codly, headcount, lq, subpar
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

#let calc_error_stage_dist(list) = {
  list.fold((:), (acc, project) => {
    let stage = project.at("error_stage")
    acc.insert(stage, acc.at(stage, default: 0) + 1)
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

#let projects_error = filter_list(raw_data, by_has_error)
#let pypi_projects_error = filter_list(projects_error, by_platform("PyPI"))
#let gh_projects_error = filter_list(projects_error, by_platform("GitHub"))
#let error_stage_dist = calc_error_stage_dist(projects_error)
#let pypi_error_stage_dist = calc_error_stage_dist(pypi_projects_error)
#let gh_error_stage_dist = calc_error_stage_dist(gh_projects_error)

#let projects_success = filter_list(raw_data, by_has_error, inv: true)
#let pypi_projects = filter_list(projects_success, by_platform("PyPI"))
#let gh_projects = filter_list(projects_success, by_platform("GitHub"))

#let pypi_popularity = calc_popularity(pypi_projects)
#let gh_popularity = calc_popularity(gh_projects)

#let total_runtime_seconds = raw_data.map(project => project.at("elapsed_seconds")).sum()
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
Ignoring the analysis of failed projects, the total runtime excluding manual work is
just #format_time(success_runtime_seconds).
During analysis, #TheTool has been run exclusively on a shared machine with an
AMD EPYC 7742 64-core processor and 512GB of memory, although limited to
using only 32 cores.

Unfortunately, #projects_error.len() projects failed to be analysed,
mostly due to the aforementioned bug in Pysa,
and, as such, these projects were excluded from the remaining results below.
@tbl:error-stage shows how many projects failed in each stage of the analysis,
discriminated by platform.

#figure(caption: [Count of projects that failed in each analysis stage, by platform])[
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
    table.header([Stage], [@pypi], [GitHub], [Total]),
    [Setup], [#pypi_error_stage_dist.at("Setup")], [#gh_error_stage_dist.at("Setup")], [#error_stage_dist.at("Setup")],

    [Analysis],
    [#pypi_error_stage_dist.at("Analysis")],
    [#gh_error_stage_dist.at("Analysis")],
    [#error_stage_dist.at("Analysis")],

    table.hline(start: 0, stroke: stroke(dash: "dashed")),
    [Total], [#pypi_projects_error.len()], [#gh_projects_error.len()], [#projects_error.len()],
  )
] <tbl:error-stage>

Out of the #projects_success.len() projects successfully analysed,
a total of #no_issues_projects.len()
(#{ calc.round(no_issues_projects.len() / projects_success.len(), digits: 3) * 100 }%)
did not have any issues found by #TheTool.
Furthermore, amongst the remaining #has_issues_projects.len() projects with issues,
only #vulnerable_projects.len() have at least one issue that was deemed vulnerable.
As can be seen by @fg:projects-issue, the amount of vulnerable projects varies
slightly by platform, with only #vulnerable_pypi_projects.len() @pypi projects
being vulnerable in contrast with #vulnerable_gh_projects.len() GitHub projects.
From a projects perspective, this means there is a Type-I error rate of
#calc.round((not_vulnerable_projects.len() / has_issues_projects.len()) * 100, digits: 1)%.

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
        let color = if align == top { white } else { black }
        lq.place(x - 0.2, y, pad(0.2em, text(fill: color, [#y])), align: align)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        let align = if y > 200 { top } else { bottom }
        let color = if align == top { white } else { black }
        lq.place(x + 0.2, y, pad(0.2em, text(fill: color, [#y])), align: align)
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
    height: 7cm,
    legend: (position: left + top),
    ylabel: [Number of Issues],
    xaxis: (
      ticks: ("Vulnerable", "Not Vulnerable").enumerate(),
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
        let align = if y > 150 { top } else { bottom }
        let color = if align == top { white } else { black }
        lq.place(x - 0.2, y, pad(0.2em, text(fill: color, [#y])), align: align)
      }),
    ..x_gh
      .zip(y_gh)
      .map(((x, y)) => {
        let align = if y > 150 { top } else { bottom }
        let color = if align == top { white } else { black }
        lq.place(x + 0.2, y, pad(0.2em, text(fill: color, [#y])), align: align)
      }),
  )
] <fg:issue-label>

Each vulnerable issue has additionally been labeled with a feature list, which
helps to rank them regarding exploitability.
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
      caption: [Vulnerable code that has been not labeled with any features],
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

// TODO description of non-vulnerable reasons

#figure(
  caption: [Visualisation of the reasons why issues were deemed not vulnerable,
    discriminated by platform of the respective project.],
)[
  #let all_features = (
    "Other": [Other],
    "AttrAllowList": [Attribute Allowlist],
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
    height: 7cm,
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
] <fg:not-vuln-issue-reaasons>

// TODO code examples for non-vulnerable reasons

== Case Study: Vulnerable Library <results:case-study>
