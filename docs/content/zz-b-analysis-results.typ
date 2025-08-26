#let raw_data = json("../assets/summary.json")

#let mk_platform_data(list, platform) = {
  list
    .filter(project => project.at("platform") == platform)
    .filter(project => project.at("issues").len() != 0)
    .sorted(key: project => -project.at("popularity"))
}

#let pypi_projects = mk_platform_data(raw_data, "PyPI")
#let gh_projects = mk_platform_data(raw_data, "GitHub")

#let mk_issues_table(projects, popularity_label) = {
  set text(size: 8pt)
  set table.cell(breakable: false)
  table(
    columns: (auto, auto, auto, 11.5em),
    align: horizon,
    stroke: 0.5pt,
    table.header([*Name*], [*#popularity_label*], [*Issues*], [*Issue Labels*]),
    ..projects
      .map(project => {
        (
          raw(project.at("name")),
          [#project.at("popularity")],
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

== @pypi

#mk_issues_table(pypi_projects, "Downloads")

== GitHub

#mk_issues_table(gh_projects, "Stars")
