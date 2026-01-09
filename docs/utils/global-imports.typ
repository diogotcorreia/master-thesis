// Keep all imports in one place to avoid versions scattered around multiple files
#import "@preview/codly-languages:0.1.8"
#import "@preview/codly:1.3.0"
#import "@preview/fletcher:0.5.8"
#import "@preview/glossarium:0.5.9"
#import "@preview/headcount:0.1.0"
#import "@preview/kthesis:0.1.3"
#import "@preview/lilaq:0.4.0" as lq
#import "@preview/subpar:0.2.2"
#import "@preview/zero:0.4.0"
#import "@preview/touying:0.6.1"

#let gls-shrt = glossarium.gls-short.with(link: true)

#let cve(id) = link("https://www.cve.org/CVERecord?id=" + id, id)
#let gh(name) = link("https://github.com/" + name, name)
#let pep(number) = {
  [PEP #number#footnote(link("https://peps.python.org/pep-0" + str(number) + "/"))]
}
