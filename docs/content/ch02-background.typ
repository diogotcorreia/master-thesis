#import "../utils/constants.typ": TheTool
#import "../utils/global-imports.typ": codly, fletcher, gls-shrt
#import fletcher: diagram, edge, node

= Background and Root Causes <bg>

This chapter provides background on code-reuse attacks in multiple programming languages,
followed by a brief explanation of relevant Python internals and the results of a
literature review on causes and consequences of class pollution in Python.
Given that very little research has been done on this topic -- there is only a
blog post @pp-python-blog and two works @pp-python @pp-python-prevention
with very similar content -- there are currently no state-of-the-art tools that can detect Python class
pollution.
For this reason, this chapter goes over similar vulnerabilities in other languages instead,
such as prototype pollution in JavaScript (@bg:js-pp) and object injection in PHP (@bg:php-oi).

Then, internal structures and behaviour of the Python language and interpreter are explored
in @bg:python, along with the results of the literature review in @bg:lit-review,
in order to provide context for the rest of this project, where the techniques
used in the aforementioned languages will be applied to Python,
showing how class pollution can be achieved.

Finally, @bg:static-analysis goes over the concepts of static code analysis and taint analysis,
and introduces the basic workings of Pysa, an open-source tool used by #TheTool.

== JavaScript Prototype Pollution <bg:js-pp>

Unlike most object-oriented languages, inheritance in JavaScript is prototype-based.
This means that all objects in JavaScript have a `__proto__` property pointing to another
object, and so on, until the root prototype is reached @pp-arteau[pp.~5-7].
When accessing a property that does not exist in a given object,
the JavaScript runtime will follow this prototype chain in an attempt to find that property
in a parent object,
as illustrated by @fg:prototype-chain.

#let js_proto_chain = [#figure(
  caption: [Property discovery through the prototype chain],
  diagram(
    spacing: (20mm, 0mm),
    node-stroke: luma(80%),
    node(
      (0, 0),
      [
        *`myobj`*
        #align(left)[
          `a: "foobar"` \
          `c: true`
        ]
      ],
      shape: rect,
      name: <a>,
    ),
    node(
      (1, -1),
      align(left)[
        `a: 42` \
        `b: 1337`
      ],
      name: <b>,
    ),
    node(
      (2, -2),
      [
        *`Object.prototype`*
        #align(left)[
          `d: 7`
        ]
      ],
      name: <c>,
    ),
    node(
      (2, -0.2),
      align(left)[
        `myobj.a` is `"foobar"` \
        `myobj.b` is `1337` \
        `myobj.c` is `true` \
        `myobj.d` is `7` \
        `myobj.e` is `undefined`
      ],
      stroke: stroke(paint: black, dash: "dashed"),
      shape: rect,
    ),

    edge(<a>, <b>, "->", [`__proto__`], label-angle: right, bend: 30deg),
    edge(<b>, <c>, "->", [`__proto__`], label-angle: right, bend: 30deg),
  ),
) <fg:prototype-chain>]
#js_proto_chain

However, this particular language feature also opens JavaScript applications
to new kinds of attacks, namely prototype pollution.
This attack was first introduced by #cite(<pp-arteau>, form: "prose")
in #cite(<pp-arteau>, form: "year"), highlighting how it could be used in real-world
applications to obtain unauthenticated @rce and other dangerous vulnerabilities.
The key to prototype pollution is that all objects, by default, inherit from the same,
mutable, root prototype.
Critically, this means that any property added to the root prototype
will become available to most objects in the
application.
This simple mechanism can lead to serious consequences,
as demonstrated by #cite(<ghunter>, form: "prose")
#cite(<probetheproto>, form: "prose"), and #cite(<silent-spring>, form: "prose").

The exploitation of prototype pollution requires two steps:
(1) finding constructs that allow setting properties in the root prototype,
and (2) finding gadgets to hijack.
There are various constructs that can allow an attacker to pollute the root prototype,
but @code:pollute-proto shows one in its most basic form, requiring three variables to
be controlled by an attacker @pp-arteau[p.~8].
In this example, the prototype is accessed through the `__proto__` property of `obj`,
and then the property `foo` is set to the value `"bar"`.
Other more advanced constructs include, for instance, recursive functions,
which enable setting multiple properties at various depths in the prototype,
allowing for even more control over gadgets @pp-arteau[p.~9].

#let js_pp_pollute = [#figure(caption: "Example construct that would pollute the root prototype")[
  ```js
  const obj = {}; // some object
  const key1 = "__proto__"; // attacker-controlled
  const key2 = "foo"; // attacker-controlled
  const value = "bar"; // attacker-controlled

  // Object.prototype points to the root prototype
  console.log(Object.prototype); // {}
  obj[key1][key2] = value;
  console.log(Object.prototype); // { foo: 'bar' }
  const other_obj = {};
  console.log(other_obj.foo); // 'bar'
  ```
] <code:pollute-proto>]
#js_pp_pollute

Once the prototype has been polluted, the second step is finding a gadget, i.e.,
a benign piece of code that, given attacker-controlled properties, changes its execution
path and performs security-sensitive operations @ghunter.
@code:pp-gadget shows an example where polluting the property `admin` with any truthy value
would result in the program outputting possibly sensitive information.

#let js_pp_gadget = [#figure(caption: "Example gadget, granting access to admin-only information")[
  ```js
  const user = { username: "johndoe" };
  // If Object.prototype.admin is polluted, this is true
  if (user.admin) {
    printSuperSecretInformation(); // Oh no :(
  }
  ```
] <code:pp-gadget>]
#js_pp_gadget

Apart from the accessing of specific properties,
another powerful type of gadgets are those that make use of for-loops.
These take advantage of the fact that the properties added to the prototype are
enumerable, meaning for-loops iterate over them as well @pp-arteau[p.~17].
This can be very flexible for attackers, as it allows more freedom over which properties
can be controlled, such as in the example in @code:pp-enumerable, where properties from
an object are set on a @dom element.
The `innerHTML` property of a @dom element contains the HTML representation
of its children,
which can be updated by assigning it a string containing HTML code @mdn-innerhtml.
In the example below (@code:pp-enumerable), polluting `innerHTML` would lead to @xss, as the for-loop would
iterate over that property as well.

#figure(caption: [Example gadget demonstrating how enumerable properties can be used to
  set arbitrary properties of #gls-shrt("dom") elements])[
  ```js
  const attributes = {
    href: "https://example.com",
    innerText: "this is a link"
  };
  // element already has an innerHTML defined
  const element = document.createElement("a");

  // If Object.prototype.innerHTML is polluted,
  // this iterates over href, innerText, AND innerHTML
  for (const attr in attributes) {
    element[attr] = attributes[attr];
  }
  document.body.append(element);
  ```
] <code:pp-enumerable>

As already mentioned, extensive research has been conducted on the topic of JavaScript prototype
pollution, including in both server-side and client-side JavaScript.
For instance, #cite(<ghunter>, form: "prose") and #cite(<silent-spring>, form: "prose")
have identified various universal gadgets in NodeJS (a server-side JavaScript runtime) which
when combined with prototype pollution can result in @rce, @ssrf,
privilege escalation, path traversal, and more.
These are called universal gadgets since they rely on built-in modules in NodeJS instead of
third-party packages.
When it comes to the client-side, that is, JavaScript running in web browsers,
#cite(<probetheproto>, form: "prose") has found that it is possible to pollute the
root prototype via the URL in certain websites, possibly leaving them vulnerable to @xss,
cookie hijacking, and/or URL manipulation.

=== Mitigations

There are multiple mitigations possible, as shown by #cite(<pp-arteau>, form: "prose").
Firstly, one could freeze the root prototype using `Object.freeze(Object.prototype)`, which
would make it immutable and disallow attackers from changing its properties.
Alternatively, but less ergonomically, developers could create objects that do not inherit
from the root prototype by using `Object.create(null)` instead of `{}`.

Furthermore, #cite(<ghunter>, form: "prose")
also show that it is possible to protect against prototype pollution
by explicitly verifying each access to properties
to ensure they are owned by the object itself and not by the prototype.
This verification can be achieved by calling `Object.hasOwn(obj, 'prop')`,
which returns true if and only if the property exists directly in the given object.

== PHP Object Injection <bg:php-oi>

In PHP, inheritance can be achieved through the use of classes, similarly to Java and C++.
Notably, the PHP language does not have a root class, which means that, unlike JavaScript,
it is not possible to pollute a root object that affects every object in the application.

However, attackers can take advantage of PHP's deserialisation and serialisation features,
which convert arbitrary objects into a string and vice-versa, and use them to create
objects with types the application did not expect @php-object-injection.

Another relevant language feature is magic methods, which are called by PHP
during various lifetime stages @php-magic-methods.
For instance, the `__sleep` method is called before serialisation, `__wakeup` is called after
deserialisation, `__destruct` is called when an object is about to be destroyed because there
are no longer any references to it, and many more @php-object-injection @php-magic-methods.
When used in conjunction with dynamic dispatch, an attacker can take advantage of any class
in the application as a gadget, possibly achieving vulnerabilities such as @rce @php-object-injection.

For example, the code in @code:php-oi-rce shows how
insecure deserialisation can lead to @rce
by taking advantage of the class hierarchy of
`Foo` and `Bar` already present in the program.
While the program is expecting to deserialise an object of type `Foo`,
an attacker provides a payload that results in an object of type `Bar`.
Since `Foo` is a superclass of `Bar`,
the program continues running without any issues,
but it has unexpectedly executed potentially malicious code.

#figure(caption: [Example showing how deserialising data can result in #gls-shrt("rce")
  in PHP, by taking advantage of inheritance and dynamic dispatch])[
  ```php
  <?php
  class Foo {
    public ?string $output;

    public function __wakeup() {
      $this->output = $this->foobar();
    }

    public function foobar() {
      return "hello world"; // benign
    }
  }

  class Bar extends Foo {
    public string $cmd;

    public function foobar() {
      // can be abused if attacker controls cmd
      return shell_exec($this->cmd);
    }
  }

  // O:3:"Bar":1:{s:3:"cmd";s:9:"uname -sr"}
  $obj = unserialize($_GET["data"]);

  echo $obj->output; // prints "Linux 6.6.83"
  ```
] <code:php-oi-rce>

== Python <bg:python>

The *Python#footnote(link("https://www.python.org/")) programming language*
was created in 1991 by Guido van Rossum and has since
seen immense adoption from the programming community, with more than 55%
of the 49,000+ respondents of the 2025 Stack Overflow Survey having worked
or wanting to work with it @stack-overflow-survey-2025-most-popular.
It is used for many use cases, such as scripting, web applications, machine learning, and much
more.
Some high-profile open-source programs that extensively use Python are
#link("https://github.com/home-assistant/core")[Home Assistant],
#link("https://github.com/element-hq/synapse")[Matrix Synapse],
and
#link("https://github.com/ansible/ansible")[ansible],
along with many companies such as Netflix @python-at-netflix,
Google @python-at-google,
and Reddit @reddit-written-in
that use it for their products as well.
For this reason, Python is a very valuable target for malicious attackers
and thus also extremely relevant for security researchers.

=== Language Fundamentals

Python is an interpreted programming language that is easy to learn and use,
which is reflected in its popularity.
While the present subsection does not aim to be a complete introduction
to the language,
it provides important background for readers not yet familiar with Python.

The Python language supports multiple programming paradigms,
including procedural, object-oriented, and functional programming.
It is possible to write statements outside of functions, which will be
executed as soon as the file is loaded by the interpreter,
but developers can also use functions and classes to organise their code.
Additionally, Python is a dynamically typed language,
meaning it does not require explicit type declarations,
nor does it enforce typing of variables during runtime,
but rather of values.
Nevertheless, developers can still optionally specify types for variables
and function arguments,
but those are not checked at runtime and are only used for static analysis.

There are a few built-in types in the language,
including primitives such as integers, strings, booleans,
but also more complex types such as lists, dictionaries, and functions.
Internally, all of these types extend the `object` type,
either directly or indirectly.

Given its object-oriented paradigm,
it is possible to define new types by declaring classes,
which inherit from `object` by default
but can also extend other existing classes.
The constructor of a class is called `__init__`,
and can be customised to accept additional parameters.

@code:python-101 shows a simple Python program
which demonstrates how to use the just-described languages constructs.
In particular, it declares a class `Car` with a constructor that
takes seat count and color,
along with a function that compares two cars.
Note that all type hints (such as `seats: int`) are optional
and ignored by the interpreter;
they are only included here for readability.

#figure(caption: [Simple Python code showcasing the basic functionality
  of the language])[
  #set text(size: 10.2pt)
  ```py
  class Vehicle:
      def __init__(self, seats: int):
          self.seats = seats

  class Car(Vehicle):  # Car extends Vehicle
      def __init__(self, seats: int, color: str, extra: dict):
          super().__init__(seats)
          self.color = color
          self.extra = extra

      def is_passenger_van(self) -> bool:
          return self.seats >= 7

      # Overriding __str__ allows customising the string
      # representation of this object
      def __str__(self):
          return f"Car of color {self.color} with {self.seats} seats"

  # Variables can change type
  BEST_COLOR = 123456
  print(type(BEST_COLOR)) # <class 'int'>
  BEST_COLOR = "#e83d84"
  print(type(BEST_COLOR)) # <class 'str'>

  def find_best_car(cars):
      for car in cars:
          if car.is_passenger_van() and car.color == BEST_COLOR:
              return car
      return None

  # Dictionaries contain key-value pairs
  # and can be created using curly braces
  car1_extra = {"vin": "VNVJ4000X61163499"}

  car1 = Car(9, BEST_COLOR, car1_extra)
  car2 = Car(5, "#ffffff", {})
  # A list can be created using square brackets
  cars = [car1, car2]

  best_car = find_best_car(cars)
  print(f"The best car is: {best_car}")
  # The best car is: Car of color #e83d84 with 9 seats
  ```
] <code:python-101>


=== Dunder Methods & Properties

// https://docs.python.org/3/reference/datamodel.html#special-method-names

In Python, most objects have double-underscore (dunder) methods and
properties that are used internally by the interpreter.
Some of these methods and properties are meant to be overridden by users,
like `__init__()` and `__add__()`, while others are meant to aid the interpreter,
like `__base__`.

In reality, some of Python's syntax is simply syntactic sugar for calling these
dunder methods.
For instance, the expression `foo + bar` is interpreted by Python
as `type(foo).__add__(foo, bar)`.
This allows for very expressive customisability for developers, not only by
overloading operators, but also by changing the behaviour of common constructs,
such as converting an object to a string (`__str__()`), subclass initialisation
(`__init__subclass__()`), listing names of the object's scope (`__dir__()`),
and much more.

Additionally, some of the dunder methods and properties can be used to traverse
the data stored by a Python program.
One great example of this is that all functions capture the scope they are defined
in, making a reference to all global variables in that scope available
through `__globals__`, as can be seen in @code:python-function-globals.

#figure(caption: [Functions in Python capture the global scope and make
  it available through `__globals__`])[
  ```py
  FOO = "hello world"

  def bar():
    pass

  print(bar.__globals__)
  # {'FOO': 'hello world', 'bar': <function bar at 0x7f4b144c9800>, ...}
  ```
] <code:python-function-globals>

This behaviour can be extremely useful for attackers when exploiting vulnerabilities
in Python like @ssti.

=== Object Attributes and Item Containers

Besides simple variables,
in Python data can be stored as either an *object's attribute*,
or as an *item in a container*.
Common containers (Python's term for what are commonly called collections)
include dictionaries, lists, and tuples.

This attribute/item distinction is important because it dictates how that data
can be accessed.
In case of an attribute, it can be accessed statically through dot-notation,
and dynamically through the built-in `getattr` and its writing counterpart
`setattr`, as exemplified in @code:python-access-attributes.

#figure(caption: [Statically and dynamically accessing attributes of Python objects])[
  ```py
  foo = Foo()
  # access attribute `bar` of `foo`
  foo.bar

  qux = "bar"
  # access attribute `bar` of `foo` as well
  getattr(foo, qux)
  ```
] <code:python-access-attributes>

On the other hand, accessing items inside containers, both statically and
dynamically, is accomplished with bracket notation, which is once again
syntactic sugar for calling `__getitem__` or `__setitem__`, as shown in
@code:python-access-items-containers.

#figure(caption: [Accessing items inside containers, such as dictionaries and lists])[
  ```py
  foo = {"bar": 123}
  qux = "bar"

  foo.bar # AttributeError
  foo["bar"] # 123
  foo[qux] # 123
  foo.__getitem__(qux) # 123
  ```
] <code:python-access-items-containers>

=== Class Inheritance

// https://docs.python.org/3/tutorial/classes.html

Contrary to JavaScript's prototype-based inheritance described in @bg:js-pp,
Python uses a class-based approach.
Like in C++, classes may have one or more superclasses, called bases.

If a class is defined without explicitly declaring a base class, it
automatically inherits from the `object` class.
The `object` class is special because it is immutable, hence it is
impossible to add or change its attributes, as exemplified in @code:python-object-immutable.

#figure(caption: [Python classes inherit from the immutable `object` class])[
  #set text(size: 10pt)
  ```py
  class A:
    pass

  print(A.__bases__) # (<class 'object'>,)

  # TypeError: cannot set 'foo' attribute of immutable type 'object'
  A.__bases__[0].foo = "bar"
  ```
] <code:python-object-immutable>

Furthermore, and perhaps intuitively, all attributes present or modified on a base
class are present on the subclasses if they are otherwise undeclared,
as shown in @code:python-attribute-inheritance.

#figure(caption: [Classes inherit attributes from their bases])[
  #set text(size: 10pt)
  ```py
  class A:
    pass

  class B(A):
    pass

  b = B()
  print(b.foo) # AttributeError

  A.foo = "bar"
  print(b.foo) # bar

  B.foo = "qux"
  print(b.foo) # qux
  ```
] <code:python-attribute-inheritance>

== Class Pollution in Python <bg:lit-review>

Class pollution is a type of vulnerability
where a malicious actor modifies a specific variable in a program
with the goal of modifying its execution flow.
This action is usually achieved by traversing through the aforementioned
dunder methods and variables,
as those provide a larger attack surface.
Similarly to prototype pollution, it requires two steps:
(1) finding a vulnerable function that allows mutating arbitrary variables;
and (2) finding gadgets that can be hijacked by modifying the value of a variable.


To answer @rq-causes-consequences[], a literature review has been performed
that unveils which constructs can lead to class pollution and under which
circumstances they are exploitable.
Given the lack of abundant scientific work on this topic,
the review has been complemented with articles and technical blog
posts from outside the research community.
Additionally, given its thoroughness, the Python specification
@python-reference-manual has been used to investigate further
constructs that can result in class pollution.

In total, two papers @pp-python-prevention @pp-python-blog,
one blog post @pp-python, and The Python Reference Manual
@python-reference-manual,
along with some existing vulnerability advisories
@mesop-cve
@django-unicorn-cve
@sverchok-cve
@pydash-cve,
have been analysed in order to
compile the causes and consequences of class pollution.

The results of this literature review are presented
in this section.

=== Dangerous Constructs

The classic way to achieve class pollution is accessing the property
`__init__.__globals__` of an object (i.e., not a primitive)
through `getattr`, and then using a combination of `getattr` and `__getitem__`
(this last one commonly invoked through subscription, `[]`, of dictionary and lists).
This is possible because, as previously shown in @code:python-function-globals,
functions capture the global scope they are declared in, allowing an attacker
to move laterally throughout the program.

Given the requirement of traversing various attributes, a vulnerable function is usually
recursive, and in some way sets or merges a value into an existing object @pp-python-blog.
Such function is exemplified by `merge` in @code:cp-merge,
which merges two objects recursively,
using `__getitem__`/`__setitem__` if the object is a dictionary,
or `getattr`/`setattr` otherwise.
In this example,
this function is then used to traverse the properties of an object of type `A`
in order to pollute the `MY_VAR` global variable.

#figure(caption: [A merge function vulnerable to class pollution, which takes two objects,
  merging their attributes or entries recursively])[
  #set text(size: 10pt)
  // FIXME: codly has a bug where setting this annotation will make code blocks
  // later in the document fail to compile for some reason
  /*#codly.codly(
    annotation-format: none,
    annotations: (
      (
        start: 13,
        end: 28,
        content: block(width: 14em, inset: 1em)[
          Example exploit, which illustrates how the value
          of `MY_VAR` can be changed by traversing `__init__` and `__globals__`
        ],
      ),
    ),
  )*/
  ```py
  def merge(src, dst):
    for k, v in src.items():
      if hasattr(dst, "__getitem__"):
        if dst.get(k) and isinstance(v, dict):
          merge(v, dst.get(k))
        else:
          dst[k] = v
      elif hasattr(dst, k) and isinstance(v, dict):
        merge(v, getattr(dst, k))
      else:
        setattr(dst, k, v)

  MY_VAR = "foo"
  class A:
    def __init__(self):
      pass

  # exploit
  merge(
    {
      "__init__": {
        "__globals__": {
          "MY_VAR": "bar",
        },
      },
    },
    A()
  )
  print(MY_VAR) # "bar"
  ```
] <code:cp-merge>

Another way to escape the current context is to get the `__builtins__`
property of a module, but that is not as common since it requires the vulnerable
construct to be executed on a module instead of on an object.
Additionally, it is an implementation detail and might not be available in
Python implementations other than CPython.

Unfortunately, both `__globals__` and `__builtins__` return a dictionary
#footnote[
  `__builtins__` might, under certain specific circumstances, return a module instead,
  which can be traversed using `getattr`.
  However, most of the time, it returns a `dict`.
],
which cannot be traversed using `getattr`.
This results in a significant limitation for the exploitation of class pollution:
to traverse outside a class hierarchy, the construct needs to not only use
`getattr`, but to fall back to `__getitem__` when it encounters a dictionary or list.
This could be uncommon due to the conventional usage of `dataclass`es
#footnote(link("https://docs.python.org/3/library/dataclasses.html"))
to store information instead of dictionaries,
in strongly-typed modern Python applications.

In some cases, vulnerable constructs that use `__getitem__` only do so when the key is numeric,
presumably to traverse a list or tuple.
This is not very useful in the context of traversing a dictionary, because there is
no way to obtain a list from a dictionary without a function call (e.g., through `.values()`),
which `getattr` cannot do.
Another possible way to traverse using only attribute accesses and lists would be
through the `__subclasses__()` method of the `object` class, which returns a list
of all classes that extend `object` (i.e., every class that does not explicitly declare a base),
but that also requires a function call.

In case only `getattr` and `setattr` are used in the vulnerable construct,
the gadgets are limited to the ones present in the class hierarchy of the given object,
which can be traversed through `__base__`.
An example of a gadget that works inside the same class hierarchy can be found
in @code:gadget-getattr-only @pp-python-blog.

#figure(caption: [Gadget inside the same class hierarchy. Polluting `DEFAULT_CMD`
  results in #gls-shrt("rce")])[
  #set text(size: 10pt)
  ```py
  from os import popen

  class Foo:
    DEFAULT_CMD = 'echo hello'

  class Bar(Foo): pass

  class Qux(Foo):
    def run(self):
      return popen(self.DEFAULT_CMD).read().strip()

  bar = Bar()
  qux = Qux()

  qux.run() # returns 'hello'
  bar.__class__.__base__.DEFAULT_CMD = "whoami" # exploit
  qux.run() # returns 'user'
  ```
] <code:gadget-getattr-only>

Finally, after having traversed to a gadget, the final step in class pollution is to
set the attribute to a desired value.
Again, depending on the type of the parent, this can either be done with `setattr`
or `__setitem__`.

To sum up, for a vulnerable construct to be able to offer a wide attack surface
with larger freedom of gadget election,
it needs to use
both `getattr` and `__getitem__`, and then also either `setattr` or `__setitem__`.

=== Possible Gadgets

While this work is mostly focused on finding dangerous constructs rather than gadgets,
it is still important to highlight some of them,
both as motivation for this degree project,
and to aid with creating a proof-of-concept when reporting vulnerabilities.

==== Mutating Built-ins

An easy way of crafting a @dos attack is to change the value of a language builtin.
Assuming the payload can only be a string, then changing the value of
`__builtins__.list` to e.g., `"foo"` will cause all calls to `list()`
to crash.
Evidently, if the payload can be a function, then it is possible to achieve @rce
this way.
One might argue that simply accessing an attribute that does not exist can
already cause the program to crash, but in that case, the program might
catch the exception (or verify that the attribute exists before accessing it)
because it could be expected that it might not exist.
However, it is unlikely the developers of the program accounted for
the type of `list` changing to a string,
resulting in a crash when the `list()` function in invoked.
The usage of this gadget is illustrated in @code:gadget-builtins.

#figure(caption: [How polluting a frequently used built-in
  can cause a #gls-shrt("dos") vulnerability])[
  #set text(size: 9.8pt)
  ```py
  class Foo:
    def __init__(self):
      pass

  foo = Foo()

  # polluting the builtin "list"
  glbs = getattr(getattr(foo, "__init__"), "__globals__")
  glbs["__builtins__"]["list"] = "foobar"

  # DoS gadget by having changed the type of "list"
  list([1, 2, 3]) # TypeError: 'str' object is not callable
  ```
] <code:gadget-builtins>

==== Signing keys, URLs, Commands

Many "constants" or attributes are available throughout Python programs
that control the behaviour of the code, from cryptographic keys
used to sign data, URLs for requests, or even commands to be executed
in a shell.
Changing one of these might allow an attacker to bypass authorization,
exfiltrate data, or even achieve @rce.

Apart from @code:gadget-getattr-only, a common gadget example is showing
how changing the app key in a Flask application allows an attacker to
forge any cookies, thus possibly bypassing authentication, as shown
in @code:gadget-flask-key @pp-python-blog.

#figure(caption: [A Flask application that contains a gadget in the form of a cookie
  signing key. A valid cookie can be generated using a tool like
  #link("https://github.com/Paradoxis/Flask-Unsign")[Flask-Unsign]])[
  ```py
  import os
  from flask import Flask, session

  app = Flask(__name__)
  app.secret_key = os.urandom(64) # random bytes

  @app.route("/admin")
  def admin():
      if "is_admin" in session and session["is_admin"]:
        # oops!
        pass

  @app.route("/vulnerable")
  def vulnerable():
    # this endpoint is vulnerable to class pollution and
    # can change app.secret_key
    pass

  if __name__ == "__main__":
      app.run()
  ```
] <code:gadget-flask-key>

==== Overriding Environment Variables

Overriding the environment variables in `os.environ` can be very powerful
since many parts of a Python program, including the standard library,
use them to control their behaviour.
A common example is hijacking `PATH`, so that shell commands executed by name
could instead run an attacker-controlled program.
This would require an attacker that can write to a file in a known location,
which is common practice in web applications that accept user uploads.
However, the file needs to be executable, which the attacker might not be
able to easily achieve.
A simplified example, where the attacker controls a file named "whoami"
in the current directory, can be seen in @code:gadget-path-hijack.

#figure(caption: [Path hijacking of a `os.popen` call leads to #gls-shrt("rce")])[
  #codly.codly(header: box(height: 9pt)[`whoami`])
  ```sh
  #!/usr/bin/env bash
  echo "you've been pwned, this is not whoami!"
  ```
  #codly.codly(header: box(height: 9pt)[`main.py`])
  ```py
  import os

  # pollute PATH
  os.environ["PATH"] = "."
  # .
  # ├── main.py
  # └── whoami

  print(os.popen("whoami").read().strip())
  # prints "you've been pwned, this is not whoami!"
  ```
] <code:gadget-path-hijack>

Other interesting variables to pollute are `PYTHONPATH` and `COMSPEC`.
The former is used by Python to locate imported modules, but is only read when
the program is first started.
Nonetheless, it could be useful in cases when another Python program is launched
as a child process.
Additionally, the contents of the `sys.path` list can be directly manipulated
using class pollution as well, which achieves the same goal as modifying `PYTHONPATH`
for the current process, as shown by @code:gadget-pythonpath-hijack.
As for `COMSPEC`, it is only useful on Windows systems, where it can be used to achieve
@rce when a call to `subprocess.Popen` is made @pp-python-blog.

#figure(caption: [Hijacking of Python's import path
  (`PYTHONPATH`/`sys.path`) leads to #gls-shrt("rce")])[
  #codly.codly(header: box(height: 9pt)[`main.py`])
  ```py
  import sys
  # pollute PYTHONPATH
  sys.path[0] = "./uploads"

  # simply importing runs the code
  import subprocess
  ```
  #codly.codly(header: box(height: 9pt)[`uploads/subprocess.py`])
  ```py
  print("pwned, hello from subprocess.py")
  ```
  #codly.codly(number-format: none)
  ```shell
  $ python main.py
  pwned, hello from subprocess.py
  ```
  #codly.codly(number-format: numbering.with("1"))
] <code:gadget-pythonpath-hijack>

==== Function Default Parameters

As mentioned previously, Python relies heavily on dunder properties for its internals.
One of those cases is when handling default parameters of functions, where it stores
the defaults in `__defaults__` (a tuple) and `__kwdefaults__` (a dictionary),
for unnamed and named parameters respectively.
Changing one of these values affects all future calls to the respective function
that omit a value for the given parameter.

Modifying the values of `__defaults__` can be challenging because tuples are immutable,
so `__defaults__` would need to be polluted in one go, as a tuple.
It is not common for user input to be converted to a tuple (e.g., during JSON deserialization),
so this might be out of reach for most exploits, but nonetheless worth mentioning.
However, `__kwdefaults__` is a dictionary, meaning it is possible to pollute individual
values.

It might be more attractive to pollute userland functions specific to a certain application,
but there are also universal gadgets present in the Python standard library.
For instance, one gadget available in the `subprocess` module is the `Popen` constructor,
which takes a `umask` named parameter.
Polluting this could be used, for example, to force all files created by child processes
to be world-readable and world-writable
#footnote[
  As can be seen from @code:gadget-umask,
  it might not always be possible to make files world-executable,
  as it depends on the program that is creating the files.
  For instance, `touch` never tries to make files executable,
  therefore the resulting permissions for `super-secret` are 0666 instead of 0777.
].
This is illustrated by @code:gadget-umask, where it is worth noting that
`os.popen` calls `subprocess.Popen` under the hood, which highlights that the
program does not need to call a gadget directly for it to be effective.

#figure(caption: [Polluting umask of all child processes created through `subprocess.Popen`])[
  #codly.codly(header: box(height: 9pt)[`main.py`])
  ```py
  import os
  import subprocess

  os.popen("touch before")

  # pollute
  subprocess.Popen.__init__.__kwdefaults__["umask"] = 0o000
  os.popen("touch super-secret")

  ```
  #codly.codly(number-format: none)
  ```shell
  $ python main.py
  $ ls -o before super-secret
  -rw-r--r-- 1 dtc 0 Aug 26 18:31 before
  -rw-rw-rw- 1 dtc 0 Aug 26 18:31 super-secret
  ```
  #codly.codly(number-format: numbering.with("1"))
] <code:gadget-umask>

=== Limitations <bg:cp-limitations>

A commonality between the gadgets in the previous section is that they
either require access to `__globals__` to perform some kind of traversal,
or need to exist in the same class hierarchy as the start traversal object.
However, this does not work on classes defined natively in CPython
#footnote[CPython is one of many Python interpreter implementations, and is written in C.
  Given its status as the reference implementation, it is the most widely used.],
at the C level,
because those are immutable.
Furthermore, all of their methods lack any reference to `__globals__`,
as well as `__defaults__` and `__kwdefaults__`.
In practice, this means that even given a function vulnerable to class
pollution, if traversal starts in a native class, such as a `dict`,
`list` or `tuple`, the code is not exploitable.

=== Summary

The results of this literature review let us answer @rq-causes-consequences[].
In summary, class pollution can be exploited via recursive calls to
`getattr` and `__getitem__`, finalised by a call to `setattr` or `__setitem__`.
Additionally, many gadgets become accessible when it is possible to traverse through the
`__globals__` attribute of a function, which can result in @dos,
Authorization Bypass, or even @rce.

== Static Code Analysis <bg:static-analysis>

To find dangerous constructs in a codebase it is necessary to perform
code analysis.
Static code analysis is the analysis of a program without
running its code,
in contrast with its dynamic counterpart,
where analysis is performed at runtime.

Performing static analysis has several advantages, such as
wider coverage of the entire program
and fast performance,
but also some drawbacks due to the lack of runtime information,
such as an increased rate of false positives and negatives.
Notably, its accuracy is negatively impacted
by the lack of strict typing information
in programming languages such as Python,
given that it cannot, for example,
accurately resolve function calls of untyped objects.

Despite its drawbacks,
given the problem at hand
it is very capable of discovering calls to the global builtins
`getattr` and `setattr`,
and is therefore useful for this degree project.

=== Taint Analysis

Through taint analysis,
it is possible to identify all flows, if any,
from a given source A to a given sink B.
For instance, considering `foo()` as a source and `bar(value)` as a sink,
a taint analyser can detect if,
in the given code,
the return value of `foo()` can ever affect the parameter of `bar(value)`.

This mechanism works by tracking what variables
depend on each other throughout the program,
through assignments,
conditional branches,
and other operations.

=== Pysa

Pyre#footnote(link("https://pyre-check.org/"))
is a static type checker for Python,
created my Meta (formerly Facebook)
for internal use but also as an open-source project.
Pyre ships with Pysa,
a security-focused static taint analysis tool
that can be used to detect insecure data flows.

Pysa can be configured via a JSON file,
defining which sources and sinks exist,
and rules declaring which source/sink combinations should raise
so-called issues if detected.
Additionally, it needs taint models to be declared,
which instruct Pysa to consider certain functions and/or variables
as the configured sources and sinks.
These model files have a syntax similar to Python typing files,
but instead of specifying types for each function argument
and return value,
they specify sources and sinks,
along with other more advanced directives.
An example taint model can be found in @code:pysa-model-example.

#figure(caption: [Example Pysa taint models that detect flows from `foo` to `bar`])[
  ```py
  def mymodule.foo() -> TaintSource[MySource]: ...

  def mymodule.bar(value: TaintSink[MySink]): ...
  ```
] <code:pysa-model-example>

In addition to `TaintSource` and `TaintSink`,
Pysa has other directives that can be useful during analysis,
such as the `Via` family of directives,
which add extra information to taint flows passing through it.
For instance, they can add an extra "feature" tag (sometimes called breadcrumbs)
to the flow or
can save the value of a certain function parameter,
which can be useful information to have during post-processing.

However, Pysa is not perfect:
due to the size and complexity of some Python programs,
Pysa might not be able to accurately keep track of every taint flow
in the program,
sometimes collapsing (also known as broadening) the taint of a given object,
that is, assuming an entire object is tainted instead of just a single field.
For example, if `foo.a` is tainted,
Pysa might collapse its taint and assume `foo` as whole is tainted.
This is unwanted behaviour for detecting class pollution,
given that the return value of `getattr` must flow unchanged to `setattr`.
