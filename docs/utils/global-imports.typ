// Keep all imports in one place to avoid versions scattered around multiple files
#import "@preview/codly-languages:0.1.8"
#import "@preview/codly:1.3.0"
#import "@preview/fletcher:0.5.8"
#import "@preview/glossarium:0.5.9"
#import "@preview/headcount:0.1.0"
#import "@preview/kthesis:0.1.2"
#import "@preview/lilaq:0.4.0" as lq
#import "@preview/subpar:0.2.2"
#import "@preview/zero:0.4.0"

#let gls-shrt = glossarium.gls-short.with(link: true)

#let cve(id) = link("https://www.cve.org/CVERecord?id=" + id, id)
#let gh(name) = link("https://github.com/" + name, name)
#let pep(number) = {
  [PEP #number#footnote(link("https://peps.python.org/pep-0" + str(number) + "/"))]
}

// https://github.com/typst/typst/issues/2196
#let content-to-string(it) = {
  if type(it) == str {
    it
  } else if type(it) != content {
    str(it)
  } else if it.has("text") {
    it.text
  } else if it.has("children") {
    it.children.map(content-to-string).join()
  } else if it.has("child") {
    content-to-string(it.child)
  } else if it.has("body") {
    to-string(it.body)
  } else if it == [ ] {
    " "
  }
}
