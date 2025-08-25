// data analysis
#import "../utils/global-imports.typ": lq

#let TheTool = text(fill: red)[The Tool]

#let pypi_color = rgb("#006dad")
#let gh_color = rgb("#08872B")

#let raw_data = json("../assets/summary.json")

#let filter_by_platform(list, platform) = {
  list.filter(project => project.at("platform") == platform)
}
#let filter_by_has_issues(list, has_issues) = {
  list.filter(project => (project.at("issues").len() == 0) != has_issues)
}
#let filter_by_is_vulnerable(list, is_vulnerable) = {
  list.filter(project => (
    (project.at("issues").any(issue => issue.at("label").at("kind") == "Vulnerable")) == is_vulnerable
  ))
}

#let pypi_projects = filter_by_platform(raw_data, "PyPI")
#let gh_projects = filter_by_platform(raw_data, "GitHub")

#let has_issues_pypi_projects = filter_by_has_issues(pypi_projects, true)
#let has_issues_gh_projects = filter_by_has_issues(gh_projects, true)
#let has_issues_projects = filter_by_has_issues(raw_data, true)
#let no_issues_pypi_projects = filter_by_has_issues(pypi_projects, false)
#let no_issues_gh_projects = filter_by_has_issues(gh_projects, false)
#let no_issues_projects = filter_by_has_issues(raw_data, false)

#let vulnerable_pypi_projects = filter_by_is_vulnerable(has_issues_pypi_projects, true)
#let vulnerable_gh_projects = filter_by_is_vulnerable(has_issues_gh_projects, true)
#let vulnerable_projects = filter_by_is_vulnerable(has_issues_projects, true)
#let not_vulnerable_pypi_projects = filter_by_is_vulnerable(has_issues_pypi_projects, false)
#let not_vulnerable_gh_projects = filter_by_is_vulnerable(has_issues_gh_projects, false)
#let not_vulnerable_projects = filter_by_is_vulnerable(has_issues_projects, false)

// text
= Results and Analysis <results>

#lorem(100)

== Literature Review <results:lit-review>

#lorem(50)

== Analysis Results <results:analysis>

Out of the #raw_data.len() projects analysed, a total of #no_issues_projects.len()
(#{ (no_issues_projects.len() / raw_data.len()) * 100 }%)
did not have any issues found by #TheTool.
Furthermore, amongst the remaining #has_issues_projects.len() projects with issues,
only #vulnerable_projects.len() have at least one issue that was deemed vulnerable.
As can be seen by @fg:projects-issue, the amount of vulnerable projects varies
slightly by platform, with only #vulnerable_pypi_projects.len() @pypi projects
being vulnerable in contrast with #vulnerable_gh_projects.len() GitHub projects.

#figure(
  caption: [
    Visualisation of how many projects have been found to possibly
    contain a class pollution vulnerability, discriminated by platform.
  ],
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
