#import "../utils/global-imports.typ": zero
#import "./ch05-results.typ": data_filtered

#import zero: num

#let mk_platform_data(list, platform) = {
  list
    .filter(project => project.at("platform") == platform)
    .filter(project => project.at("issues").len() != 0)
    .sorted(key: project => -project.at("popularity"))
}

#let pypi_projects = mk_platform_data(data_filtered, "PyPI")
#let gh_projects = mk_platform_data(data_filtered, "GitHub")

#let get_version_fmt(project) = {
  let version = project.at("version")
  if project.at("platform") == "GitHub" {
    version.slice(0, count: 10)
  } else {
    version
  }
}

#let mk_issues_table(projects, version_label, popularity_label) = {
  set text(size: 8pt)
  set table.cell(breakable: false)
  show table.cell.where(x: 2): set align(right)
  table(
    columns: (auto, auto, auto, auto, 11.5em),
    align: horizon,
    stroke: 0.5pt,
    table.header([*Name*], [*#version_label*], [*#popularity_label*], [*Issues*], [*Issue Labels*]),
    ..projects
      .map(project => {
        (
          raw(project.at("name")),
          raw(get_version_fmt(project)),
          num(project.at("popularity")),
          [#project.at("issues").len()],
          {
            let vulnerable_count = project
              .at("issues")
              .filter(issue => issue.at("label").at("kind") == "Vulnerable")
              .len()
            let not_vulnerable_counts = project
              .at("issues")
              .filter(issue => issue.at("label").at("kind") == "NotVulnerable")
              .map(issue => issue.at("label").at("reasons"))
              .flatten()
              .fold((:), (acc, reason) => {
                let kind = reason.at("kind")
                let prev = acc.at(kind, default: 0)
                acc.insert(kind, prev + 1)
                acc
              })

            if vulnerable_count > 0 {
              text(fill: red)[*Vulnerable (#vulnerable_count)*]
              if not_vulnerable_counts.len() > 0 {
                linebreak()
              }
            }
            not_vulnerable_counts.pairs().map(entry => [#entry.at(0) (#entry.at(1))]).join(linebreak())
          },
        )
      })
      .flatten(),
  )
}

= Detailed Analysis Results <detailed-results>

The tables below provide a detailed description of the obtained results,
highlighting the projects that were deemed vulnerable.
For convenience, the tables have been split based on the platform of
the project, and sorted by popularity, either downloads or stars.
As previously mentioned, it is possible for one issue to have multiple
labels, hence why summing the label counts might yield more than the number
of issues for a given project.

== PyPI

#mk_issues_table(pypi_projects, "Version", "Downloads")

== GitHub

#mk_issues_table(gh_projects, "Commit SHA", "Stars")
