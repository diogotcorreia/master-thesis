// KTH theme

// Originally contributed by Pol Dellaiera - https://github.com/drupol
// Forked as KTH theme by Diogo Correia - https://github.com/diogotcorreia

#import "./global-imports.typ": touying
#import touying: *

/// Default slide function for the presentation.
///
/// - config (dictionary): is the configuration of the slide. Use `config-xxx` to set individual configurations for the slide. To apply multiple configurations, use `utils.merge-dicts` to combine them.
///
/// - repeat (int, auto): is the number of subslides. The default is `auto`, allowing touying to automatically calculate the number of subslides. The `repeat` argument is required when using `#slide(repeat: 3, self => [ .. ])` style code to create a slide, as touying cannot automatically detect callback-style `uncover` and `only`.
///
/// - setting (dictionary): is the setting of the slide, which can be used to apply set/show rules for the slide.
///
/// - composer (array, function): is the layout composer of the slide, allowing you to define the slide layout.
///
///   For example, `#slide(composer: (1fr, 2fr, 1fr))[A][B][C]` to split the slide into three parts. The first and the last parts will take 1/4 of the slide, and the second part will take 1/2 of the slide.
///
///   If you pass a non-function value like `(1fr, 2fr, 1fr)`, it will be assumed to be the first argument of the `components.side-by-side` function.
///
///   The `components.side-by-side` function is a simple wrapper of the `grid` function. It means you can use the `grid.cell(colspan: 2, ..)` to make the cell take 2 columns.
///
///   For example, `#slide(composer: 2)[A][B][#grid.cell(colspan: 2)[Footer]]` will make the `Footer` cell take 2 columns.
///
///   If you want to customize the composer, you can pass a function to the `composer` argument. The function should receive the contents of the slide and return the content of the slide, like `#slide(composer: grid.with(columns: 2))[A][B]`.
///
/// - bodies (arguments): is the contents of the slide. You can call the `slide` function with syntax like `#slide[A][B][C]` to create a slide.
#let slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  align: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  if align != auto {
    self.store.align = align
  }
  let header(self) = {
    set std.align(top)
    grid(
      columns: (3.3em, 1fr, 8em),
      box(
        width: 100%,
        inset: 0.4em,
        std.align(center, utils.call-or-display(self, self.store.header-left)),
      ),
      box(
        height: 100%,
        std.align(
          horizon,
          text(
            fill: self.colors.tertiary,
            weight: "bold",
            size: 1.2em,
            utils.call-or-display(self, self.store.header),
          ),
        ),
      ),
      box(
        fill: self.colors.secondary-lighter,
        width: 100%,
        inset: 0.5em,
        radius: (bottom-left: 10pt),
        std.align(
          left + horizon,
          text(
            fill: self.colors.tertiary,
            size: 0.7em,
            utils.call-or-display(
              self,
              self.store.header-right,
            ),
            weight: "bold",
          ),
        ),
      ),
    )
  }
  let self = utils.merge-dicts(
    self,
    config-page(
      header: header,
      margin: (top: 3em, x: 3.3em),
    ),
  )
  let new-setting = body => {
    show: std.align.with(self.store.align)
    show: setting
    body
  }
  touying-slide(
    self: self,
    config: config,
    repeat: repeat,
    setting: new-setting,
    composer: composer,
    ..bodies,
  )
})


/// Title slide for the presentation. You should update the information in the `config-info` function. You can also pass the information directly to the `title-slide` function.
///
/// Example:
///
/// ```typst
/// #show: university-theme.with(
///   config-info(
///     title: [Title],
///     logo: emoji.school,
///   ),
/// )
///
/// #title-slide(subtitle: [Subtitle])
/// ```
///
/// - config (dictionary): is the configuration of the slide. Use `config-xxx` to set individual configurations for the slide. To apply multiple configurations, use `utils.merge-dicts` to combine them.
///
/// - extra (string, none): is the extra information for the slide. This can be passed to the `title-slide` function to display additional information on the title slide.
#let title-slide(
  config: (:),
  extra: none,
  ..args,
) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(
    self,
    config,
    config-common(
      freeze-slide-counter: true,
      show-strong-with-alert: false,
    ),
    config-page(
      footer: none,
      fill: self.colors.tertiary,
      background: context {
        let f = page.width / 1920
        place(top + left, curve(
          stroke: self.colors.primary-lighter,
          curve.move((-5.5 * f, 213.5 * f)),
          curve.line((213.5 * f, 213.5 * f)),
          curve.line((-4.5 * f, 648.5 * f)),
          curve.move((426.12 * f, -6.5 * f)),
          curve.line((426.12 * f, 215.07 * f)),
          curve.cubic((426.12 * f, 332.11 * f), (331.24 * f, 427 * f), (214.19 * f, 427 * f)),
          curve.line((-5.5 * f, 427 * f)),
        ))
        place(top + right, scale(x: -100%, curve(
          stroke: self.colors.primary-lighter,
          curve.move((427.13 * f, 1080.31 * f)),
          curve.cubic((427.13 * f, 955.36 * f), (325.84 * f, 854.06 * f), (200.88 * f, 854.06 * f)),
          curve.line((-4.5 * f, 854.06 * f)),
        )))
      },
    ),
  )
  let info = self.info + args.named()
  info.authors = {
    let authors = if "authors" in info {
      info.authors
    } else {
      info.author
    }
    if type(authors) == array {
      authors
    } else {
      (authors,)
    }
  }
  let body = {
    std.align(
      center + horizon,
      {
        if info.logo-white != none {
          text(fill: self.colors.neutral-lightest, box(width: 5em, info.logo-white))
        }
        block(
          inset: (y: 0em, x: 3em),
          breakable: false,
          {
            text(size: 1.5em, fill: self.colors.neutral-lightest, strong(info.title))
            if info.subtitle != none {
              parbreak()
              text(size: 1em, fill: self.colors.neutral-lightest, info.subtitle)
            }
          },
        )
        set text(size: .8em)
        grid(
          columns: (1fr,) * calc.min(info.authors.len(), 3),
          column-gutter: 1em,
          row-gutter: 1em,
          ..info.authors.map(author => text(
            fill: self.colors.secondary,
            author,
          ))
        )
        if info.date != none {
          place(bottom + left, text(size: .5em, fill: self.colors.secondary, utils.display-info-date(self)))
        }
      },
    )
  }
  touying-slide(self: self, body)
})


/// New section slide for the presentation. You can update it by updating the `new-section-slide-fn` argument for `config-common` function.
///
/// Example: `config-common(new-section-slide-fn: new-section-slide.with(numbered: false))`
///
/// - config (dictionary): is the configuration of the slide. Use `config-xxx` to set individual configurations for the slide. To apply multiple configurations, use `utils.merge-dicts` to combine them.
///
/// - level (int, none): is the level of the heading.
///
/// - numbered (boolean): is whether the heading is numbered.
///
/// - body (auto): is the body of the section. This will be passed automatically by Touying.
#let new-section-slide(
  config: (:),
  level: 1,
  numbered: true,
  body,
) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(
    self,
    config,
    config-common(
      show-strong-with-alert: false,
    ),
    config-page(
      fill: self.colors.tertiary,
      background: context {
        let f = page.width / 1920
        place(top + left, curve(
          stroke: self.colors.primary-lighter,
          curve.move((1066.04 * f, -3 * f)),
          curve.line((1066.04 * f, 426.38 * f)),
          curve.cubic((948.93 * f, 426.38 * f), (854 * f, 331.45 * f), (854 * f, 214.34 * f)),
          curve.line((1921.5 * f, 214.34 * f)),
          curve.move((1493 * f, 0 * f)),
          curve.cubic((1493 * f, 235.83 * f), (1684.17 * f, 427 * f), (1920 * f, 427 * f)),
        ))
      },
    ),
  )
  let slide-body = {
    if self.info.logo-white != none {
      place(top + left, text(fill: self.colors.neutral-lightest, box(width: 3em, self.info.logo-white)))
    }
    set std.align(bottom + left)
    show: pad.with(right: 30%)
    set text(size: 2em, fill: self.colors.neutral-lightest, weight: "bold")
    stack(
      dir: ttb,
      spacing: .65em,
      utils.display-current-heading(level: level, numbered: numbered),
      v(1em),
      body,
    )
  }
  touying-slide(self: self, slide-body)
})


/// Focus on some content.
#let focus-slide(
  config: (:),
  level: 1,
  numbered: true,
  body,
) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(
    self,
    config,
    config-common(
      show-strong-with-alert: false,
    ),
    config-page(
      fill: self.colors.secondary-lighter,
      background: context {
        let f = page.width / 1920
        place(top + right, scale(x: -100%, curve(
          stroke: self.colors.secondary,
          curve.move((-5.5 * f, 213.5 * f)),
          curve.line((213.5 * f, 213.5 * f)),
          curve.line((-4.5 * f, 648.5 * f)),
          curve.move((426.12 * f, -6.5 * f)),
          curve.line((426.12 * f, 215.07 * f)),
          curve.cubic((426.12 * f, 332.11 * f), (331.24 * f, 427 * f), (214.19 * f, 427 * f)),
          curve.line((-5.5 * f, 427 * f)),
        )))
      },
    ),
  )
  let slide-body = {
    if self.info.logo != none {
      place(top + left, text(fill: self.colors.neutral-lightest, box(width: 3em, self.info.logo)))
    }
    set std.align(horizon + center)
    show: pad.with(x: 15%)
    set text(size: 2em, fill: self.colors.tertiary, weight: "bold")
    body
  }
  touying-slide(self: self, slide-body)
})


// Create a slide where the provided content blocks are displayed in a grid and coloured in a checkerboard pattern without further decoration. You can configure the grid using the rows and `columns` keyword arguments (both default to none). It is determined in the following way:
///
/// - If `columns` is an integer, create that many columns of width `1fr`.
/// - If `columns` is `none`, create as many columns of width `1fr` as there are content blocks.
/// - Otherwise assume that `columns` is an array of widths already, use that.
/// - If `rows` is an integer, create that many rows of height `1fr`.
/// - If `rows` is `none`, create that many rows of height `1fr` as are needed given the number of co/ -ntent blocks and columns.
/// - Otherwise assume that `rows` is an array of heights already, use that.
/// - Check that there are enough rows and columns to fit in all the content blocks.
///
/// That means that `#matrix-slide[...][...]` stacks horizontally and `#matrix-slide(columns: 1)[...][...]` stacks vertically.
///
/// - config (dictionary): is the configuration of the slide. Use `config-xxx` to set individual configurations for the slide. To apply multiple configurations, use `utils.merge-dicts` to combine them.
#let matrix-slide(
  config: (:),
  columns: none,
  rows: none,
  ..bodies,
) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(
    self,
    config-common(freeze-slide-counter: true),
    config-page(margin: 0em),
  )
  touying-slide(
    self: self,
    config: config,
    composer: components.checkerboard.with(columns: columns, rows: rows),
    ..bodies,
  )
})


/// Touying university theme.
///
/// Example:
///
/// ```typst
/// #show: university-theme.with(aspect-ratio: "16-9", config-colors(primary: blue))`
/// ```
///
/// The default colors:
///
/// ```typ
/// config-colors(
///   primary: rgb("#04364A"),
///   secondary: rgb("#176B87"),
///   tertiary: rgb("#448C95"),
///   neutral-lightest: rgb("#ffffff"),
///   neutral-darkest: rgb("#000000"),
/// )
/// ```
///
/// - aspect-ratio (string): is the aspect ratio of the slides. Default is `16-9`.
///
/// - align (alignment): is the alignment of the slides. Default is `top`.
///
/// - progress-bar (boolean): is whether to show the progress bar. Default is `true`.
///
/// - header (content, function): is the header of the slides. Default is `utils.display-current-heading(level: 2)`.
///
/// - header-right (content, function): is the right part of the header. Default is `self.info.logo`.
///
/// - footer-columns (tuple): is the columns of the footer. Default is `(25%, 1fr, 25%)`.
///
/// - footer-a (content, function): is the left part of the footer. Default is `self.info.author`.
///
/// - footer-b (content, function): is the middle part of the footer. Default is `self.info.short-title` or `self.info.title`.
///
/// - footer-c (content, function): is the right part of the footer. Default is `self => h(1fr) + utils.display-info-date(self) + h(1fr) + context utils.slide-counter.display() + " / " + utils.last-slide-number + h(1fr)`.
#let university-theme(
  aspect-ratio: "16-9",
  align: top,
  progress-bar: true,
  header-left: self => self.info.logo,
  header: utils.display-current-heading(level: 2, style: auto),
  header-right: utils.display-current-heading(level: 1),
  footer-columns: (25%, 1fr, 25%),
  footer-a: self => self.info.author,
  footer-b: self => if self.info.short-title == auto {
    self.info.title
  } else {
    self.info.short-title
  },
  footer-c: self => {
    grid(
      columns: (1fr,) * 2,
      utils.display-info-date(self),
      // ensure the page numbers don't jump around (as much)
      box(
        width: 4em,
        align(right, context utils.slide-counter.display() + " / " + utils.last-slide-number),
      ),
    )
  },
  bib: none,
  ..args,
  body,
) = {
  show: touying-slides.with(
    config-page(
      paper: "presentation-" + aspect-ratio,
      header-ascent: 0em,
      footer-descent: 0em,
      margin: (top: 2em, bottom: 1.25em, x: 2em),
      footer: self => {
        set std.align(center + bottom)
        set text(size: .4em)
        {
          let cell(..args, it) = components.cell(
            ..args,
            inset: 1mm,
            std.align(horizon, text(fill: self.colors.secondary, it)),
          )
          show: block.with(width: 100%, height: auto)
          show: pad.with(bottom: 1em)
          grid(
            columns: self.store.footer-columns,
            rows: 1.5em,
            cell(utils.call-or-display(
              self,
              self.store.footer-a,
            )),
            cell(utils.call-or-display(
              self,
              self.store.footer-b,
            )),
            cell(utils.call-or-display(
              self,
              self.store.footer-c,
            )),
          )
        }
      },
    ),
    config-common(
      slide-fn: slide,
      new-section-slide-fn: new-section-slide,
      show-strong-with-alert: false,
    ),
    config-methods(
      init: (self: none, body) => {
        set text(size: 25pt, font: "Figtree")
        show heading.where(level: 3): set text(fill: self.colors.primary)
        show heading.where(level: 4): set text(fill: self.colors.primary)

        body
      },
      alert: utils.alert-with-primary-color,
    ),
    config-colors(
      primary: rgb("#004791"),
      primary-lighter: rgb("#0029ed"),
      secondary: rgb("#6298D2"),
      secondary-lighter: rgb("#def0ff"),
      tertiary: rgb("#000061"),
      neutral-lightest: rgb("#ffffff"),
      neutral-darkest: rgb("#000000"),
    ),
    // save the variables for later use
    config-store(
      align: align,
      progress-bar: progress-bar,
      header-left: header-left,
      header: header,
      header-right: header-right,
      footer-columns: footer-columns,
      footer-a: footer-a,
      footer-b: footer-b,
      footer-c: footer-c,
    ),
    ..args,
  )

  body
}
