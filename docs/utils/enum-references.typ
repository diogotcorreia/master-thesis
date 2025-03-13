// Source: https://github.com/typst/typst/issues/779#issuecomment-2702268234

/// Metadata marker for enum items labels,
/// used to allow reference with the `enum-label` function
#let enu-label-mark = metadata("enumeration_label")

/// Add a label to an enumeration item.
///
/// Used as:
/// ```typ
/// + #enum-label("first")first
/// + second
///   + third #enum-label[third]
///
/// I can ref @first and @third[It.]
/// // I can ref Item~1 and It.~3
/// ```
///
/// The label can be used anywhere in the enumeration item.
/// Calling enum-label works with str or text content.
#let enum-label(label) = {
  if type(label) == content {
    // informative error message
    assert(label.has("text"), message: "enum-label requires text content")
    label = label.text
  }
  [#enu-label-mark#std.label(label)]
}

/// Counter name for tracking of enumeration items
#let enum-counter-name = "enum-counter"
/// State for tracking the numbering format of enumeration items
#let enum-numbering-state = state("enum-numbering", none)

/// Wrapper for enum numbering to allow for a references to enum items.
/// The desired numbering format is passed as an argument (str or function)
/// To reference an item use `enum-label` function.
///
/// ```typ
///
/// #set enum(numbering: wrapped-enum-numbering("1.1"), full: true)
/// + #enum-label("one")first
/// #set enum(numbering: wrapped-enum-numbering("I.1"), start: 2)
/// + second
///   + third #enum-label[another]
///
// One is @one[] and another is @another[] // One is 1 and another is II.2
/// ```
#let wrapped-enum-numbering(numbering) = {
  let enum-numbering = (..it) => {
    enum-numbering-state.update(x => numbering)
    counter(enum-counter-name).update(it.pos())
    std.numbering(numbering, ..it)
  }
  enum-numbering
}


/// Copy from tools4typst
/// return true if value is an empty array, dictionary, string or content
#let is-empty(value) = {
  let empty-values = (
    array: (),
    dictionary: (:),
    str: "",
    content: [],
  )
  let t = repr(type(value))
  if t in empty-values {
    return value == empty-values.at(t)
  } else {
    return value == none
  }
}


#let setup_enum_references(content) = {
  show ref: it => {
    let el = it.element
    if el != none and el.func() == metadata and el == enu-label-mark {
      let supp = it.supplement
      if supp == auto {
        supp = "Item"
      }
      // get the counter value in the correct format according to location
      let loc = el.location()
      let ref-counter = context numbering(state("enum-numbering").at(loc), ..counter(enum-counter-name).at(loc))
      if is-empty(supp) {
        link(el.location(), ref-counter)
      } else {
        link(el.location(), box([#supp~#ref-counter]))
      }
    } else {
      it
    }
  }

  content
}
