= Background <bg>

This chapter provides background on code-reuse attacks in multiple programming languages,
followed by a brief explanation of relevant Python internals.
Given that very little research has been done on this topic -- there is only a
blog post @pp-python-blog and two works @pp-python @pp-python-prevention that go over mostly
the same content -- there are currently no state-of-the-art tools that can detect Python class
pollution.
For this reason, this chapter go over similar vulnerabilities in other languages instead,
such as prototype pollution in JavaScript (@bg:js-pp) and object injection in PHP (@bg:php-oi).
Then, internal structures and behaviour of the Python language and interpreter will be explored
in @bg:python in order to provide context for the rest of this project, where the techniques
used in the aforementioned languages will be applied to Python, resulting in class pollution.

Finally, @bg:static-analysis goes over what static code analysis and taint analysis are and
how Pysa, a tool used in this project, works.

== JavaScript Prototype Pollution <bg:js-pp>

Unlike most object-oriented languages, inheritance in JavaScript is prototype-based.
This means that all objects in JavaScript have a `__proto__` property pointing to another
object, and so on, until they reach the root prototype @pp-arteau[pp.~5-7].
For this reason, when accessing a property that does not exist in a given object,
the JavaScript runtime will attempt to find that property in the prototype chain,
as illustrated by @fg:prototype-chain.

#figure(
  // TODO do a flowchart-style graph that shows getting the property from the root
  // prototype when it is not set in the object
  rect(fill: red, height: 10em, lorem(5)),
  caption: "Property discovery through the prototype chain"
) <fg:prototype-chain>

The prototype pollution attack was first introduced by #cite(<pp-arteau>, form: "prose")
in #cite(<pp-arteau>, form: "year"), highlighting how it could be used in real-world
applications to obtain unauthenticated @rce and other dangerous vulnerabilities.
The key to prototype pollution is that all objects, by default, inherit from the same,
mutable, root prototype.
Therefore, any property added to this prototype will be added to most objects in the
application, which, as demonstrated by #cite(<ghunter>, form: "prose")
#cite(<probetheproto>, form: "prose") and #cite(<silent-spring>, form: "prose"), can cause
serious consequences.

The exploitation of prototype pollution requires two steps: finding constructs that
allow setting properties in the root prototype, and finding gadgets.
There are various constructs that can allow an attacker to pollute the root prototype,
but @code:pollute-proto shows one in its most basic form, requiring three variables to
be controlled by an attacker @pp-arteau[p.~8].
In this example, the prototype is accessed through the `__proto__` property of `obj`,
and then the property `foo` is set to the value `"bar"`.
Other more advanced constructs can include recursive functions, which can allow setting
multiple properties at various depths in the prototype, allowing for even more
control over gadgets @pp-arteau[p.~9].

#figure(caption: "Example construct that would pollute the root prototype")[
  ```js
  let obj = {}; // some object
  let key1 = "__proto__"; // attacker-controlled
  let key2 = "foo"; // attacker-controlled
  let value = "bar"; // attacker-controlled

  // Object.prototype points to the root prototype
  console.log(Object.prototype); // {}
  obj[key1][key2] = value;
  console.log(Object.prototype); // { foo: 'bar' }
  ```
] <code:pollute-proto>

Once the prototype has been polluted, the second step is finding a gadget, that is,
a benign piece of code that given attacker-controlled properties changes its execution
path and performs security-sensitive operations @ghunter.
@code:pp-gadget shows an example where polluting the property `admin` with any truthy-value
would result in the program printing possibly sensitive information.

#figure(caption: "Example gadget, granting access to admin-only information")[
  ```js
  let user = { username: "johndoe" };

  if (user.admin) {
    printSuperSecretInformation();
  }
  ```
] <code:pp-gadget>

Apart from accessing specific properties, another powerful type of gadgets are those
composed of for-loops.
These take advantage of the fact that the properties added to the prototype are
enumerable, meaning for-loops iterate over them as well @pp-arteau[p.~17].
This can be very flexible for attackers, as it allows more freedom over which properties
can be controlled, such as in the example in @code:pp-enumerable, where properties from
an object are set on a @dom element.
In this example, polluting `innerHTML` would lead to @xss, as the for-loop would
iterate over that property as well.

#figure(caption: [
  Example gadget demonstrating how enumerable properties can be used to
  set arbitrary properties of @dom elements
])[
  ```js
  let attributes = {
    href: "https://example.com",
    innerText: "this is a link"
  };
  let element = document.createElement("a");

  for (let attr in attributes) {
    element[attr] = attributes[attr];
  }
  document.body.append(element);
  ```
] <code:pp-enumerable>

As already mentioned, there has been extensive research about JavaScript prototype
pollution, including in both server-side and client-side JavaScript.
For instance, #cite(<ghunter>, form: "prose") and #cite(<silent-spring>, form: "prose")
have identified various universal gadgets in NodeJS, a server-side JavaScript runtime, which
can result in @rce, @ssrf, privilege escalation, path traversal, and more, when combined with prototype pollution.
These are called universal gadgets since they rely on built-in modules in NodeJS instead of
third-party packages.
When it comes to the client-side, that is, JavaScript running in browsers,
#cite(<probetheproto>, form: "prose") has found that it is possible to pollute the
root prototype via the URL in certain websites, possibly leaving them vulnerable to @xss,
cookie manipulation, and/or url manipulation.

=== Mitigations

There are multiple mitigations possible, as shown by #cite(<pp-arteau>, form: "prose").
Firstly, one could freeze the prototype using `Object.freeze(Object.prototype)`, which
would make it immutable and disallow attackers from changing its properties.
Alternatively, but less effectively, developers could create objects that do not inherit
from the root prototype by using `Object.create(null)`.

== PHP Object Injection <bg:php-oi>

- class-based inheritance
- magic methods
- deserialisation/serialisation

== Python <bg:python>

The *Python programming language* was created in 1991 by Guido van Rossum and has since
seen immense adoption from the programming community, with more than 50% of the respondents
of the 2024 Stack Overflow Survey having worked with it or wanting to @stack-overflow-survey-2024-most-popular.
It is used for many applications, such as scripting, web applications, machine learning, and much
more.
Some high-profile open-source programs that extensively use Python are
#link("https://github.com/home-assistant/core")[Home Assistant],
#link("https://github.com/element-hq/synapse")[Matrix Synapse]
and
#link("https://github.com/ansible/ansible")[ansible],
along with many companies like Netflix, Google and Reddit
that use it for their products as well.
For this reason, Python is a very valuable target for malicious attackers
and therefore extremely relevant for security researchers.

=== Dunder Methods & Properties

- used for internal stuff
- show `__init__`, `__str__`, `__add__`, etc

=== Object Attributes

- setattr/getattr
- how inheritance works
- classes
- immutable object class

=== Dictionaries

- bracket syntax
- `__setitem__/__getitem__`

== Static Code Analysis <bg:static-analysis>

- analyse source code directly; no execution
- difficult in python due to dynamic/lax typing

#lorem(20)

=== Taint Analysis

=== Pysa

== Previous Work

#lorem(50)
