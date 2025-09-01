#import "../utils/global-imports.typ": codly, gls-shrt

= Background and Root Causes <bg>

This chapter provides background on code-reuse attacks in multiple programming languages,
followed by a brief explanation of relevant Python internals and the results of a
literature review on causes and consequences of class pollution in Python.
Given that very little research has been done on this topic -- there is only a
blog post @pp-python-blog and two works @pp-python @pp-python-prevention that go over mostly
the same content -- there are currently no state-of-the-art tools that can detect Python class
pollution.
For this reason, this chapter goes over similar vulnerabilities in other languages instead,
such as prototype pollution in JavaScript (@bg:js-pp) and object injection in PHP (@bg:php-oi).
Then, internal structures and behaviour of the Python language and interpreter will be explored
in @bg:python, along with the results of the literature review in @bg:lit-review,
in order to provide context for the rest of this project, where the techniques
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
  caption: "Property discovery through the prototype chain",
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

#figure(caption: [Example gadget demonstrating how enumerable properties can be used to
  set arbitrary properties of #gls-shrt("dom") elements])[
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
cookie manipulation, and/or URL manipulation.

=== Mitigations

There are multiple mitigations possible, as shown by #cite(<pp-arteau>, form: "prose").
Firstly, one could freeze the prototype using `Object.freeze(Object.prototype)`, which
would make it immutable and disallow attackers from changing its properties.
Alternatively, but less effectively, developers could create objects that do not inherit
from the root prototype by using `Object.create(null)`.

== PHP Object Injection <bg:php-oi>

In PHP, inheritance can be achieved through the use of classes, similarly to Java and C++.
Notably, the language does not have a root class, which means that, unlike JavaScript,
it is not possible to pollute a root object that affects every object in the application.

However, attackers can take advantage of PHP's deserialisation and serialisation features,
which convert arbitrary objects into a string and vice-versa, and use them to create
objects with types the application did not expect @php-object-injection.

Another relevant language feature is magic methods, which are called by PHP on various actions
@php-magic-methods.
For instance, the `__sleep` method is called before serialisation, `__wakeup` is called after
deserialisation, `__destruct` is called when an object is about to be destroyed because there
is no longer any reference to it, and many more @php-object-injection @php-magic-methods.
When used in conjunction with dynamic dispatch, an attacker can take advantage of any class
in the application as a gadget, possibly achieving vulnerabilities like @rce, as demonstrated
by @code:php-oi-rce @php-object-injection.

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
      return shell_exec($this->cmd); // can be abused if attacker controls cmd
    }
  }

  // O:3:"Bar":1:{s:3:"cmd";s:9:"uname -sr"}
  $obj = unserialize($_GET["data"]);

  echo $obj->output; // prints "Linux 6.6.83"
  ```
] <code:php-oi-rce>

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

// https://docs.python.org/3/reference/datamodel.html#special-method-names

In Python, most objects have double underscore (dunder) methods and
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
such as, converting an object to a string (`__str__()`), subclass initialisation
(`__init__subclass__()`), listing names of the object's scope (`__dir__()`),
and much more.

Additionally, some of the dunder methods and properties can be used to traverse
the data stored by a Python program.
One great example of this is that all functions capture the scope they are defined
in, making a reference to all global variables in that scope available
through `__globals__`, as can be seen on @code:python-function-globals.

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

In Python, data in objects can be stored in different ways;
it can either be an attribute of an object, or it can be an item
in a container (dictionaries, lists, and tuples are examples of containers).

This is an important distinction because it dictates how that data
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
dynamically, is done through the bracket-notation, which is once again
syntactic sugar for calling `__getitem__` or `__setitem__`, as shown in
@code:python-access-items-containers.

#figure(caption: [Accessing items inside containers, such as dictionaries and lists])[
  ```py
  foo = {"bar": 123}
  qux = "bar"

  foo.bar # AttributeError
  foo["bar"] # 123
  foo[qux] # 123
  ```
] <code:python-access-items-containers>

This will be an important distinction later on.

=== Class Inheritance

// https://docs.python.org/3/tutorial/classes.html

Contrary to JavaScript's prototype-based inheritance described in @bg:js-pp,
Python uses a class-based approach to inheritance.
Like in C++, classes may have one or more superclasses, called bases.

If a class is defined without explicitly declaring a base class, it
automatically inherits from the `object` class.
The `object` class is special because it is immutable, hence it is
impossible to add or change its attributes, as exemplified in @code:python-object-immutable.

#figure(caption: [Python classes inherit from the immutable `object` class])[
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
@python-reference-manual have been analysed in order to
compile the causes and consequences of class pollution.

As such, the results of this literature review are presented
in this section.

=== Dangerous Constructs

The classic way to achieve class pollution is accessing the properties
`__init__.__globals__` of an object (i.e., not a primitive)
through `getattr`, and then using a combination of `getattr` and `__getitem__`
(commonly used through subscription, `[]`, of dictionary and lists).
This is possible because, as shown previously by @code:python-function-globals,
functions capture the global scope they are declared in, allowing an attacker
to move laterally throughout the program.

Given the requirement of traversing various attributes, a vulnerable function is usually
recursive, and somehow sets or merges a value into an existing object, as exemplified
by @code:cp-merge @pp-python-blog.

#figure(caption: [A merge function vulnerable to class pollution, which takes two objects,
  merging their attributes or entries recursively.])[
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

Unfortunately, both `__globals__` and `__builtins__`
#footnote[
  `__builtins__` might, under certain specific circumstances, return a module instead,
  which can be traversed using `getattr`.
  However, most of the time, it returns a `dict`.
]
return a dictionary, which
cannot be traversed using `getattr`.
This results in a big limitation for the exploitation of class pollution:
to traverse outside a class hierarchy, the construct needs to use not only
`getattr`, but to fallback to `__getitem__` when it encounters a dictionary or list.

Sometimes, vulnerable constructs that use `__getitem__` only do so when the key is numeric,
presumably to traverse a list or tuple.
This is not very useful in the context of traversing a dictionary, because there is
no way to obtain a list from a dictionary without a function call (e.g., through `.values()`).
Another possible way to traverse using only attribute accesses and lists would be
through the `__subclasses__()` method of the `object` class, which returns a list
of all classes that extend `object` (all classes that don't explicitly declare a base),
but that also requires a function call.

In case only `getattr` and `setattr` are used in the vulnerable construct,
the gadgets are limited to the ones present in the class hierarchy of the given object,
which can be traversed through `__base__`.
An example of a gadget that works inside the same class hierarchy can be found
in @code:gadget-getattr-only @pp-python-blog.

#figure(caption: [Gadget inside the same class hierarchy. Polluting `DEFAULT_CMD`
  results in #gls-shrt("rce")])[
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

To sum up, for a vulnerable construct to be able to use many gadgets, it needs to use
both `getattr` and `__getitem__`, and then either `setattr` or `__setitem__`.

=== Possible Gadgets

While this work is mostly focused on finding dangerous constructs rather than gadgets,
it is still important to highlight some of them, both for the relevance of this
degree project, as well as to aid with creating a proof of concept when reporting
vulnerabilities.

==== Mutating Built-ins

An easy way of creating a @dos is to change the value of a builtin.
Assuming the payload can only be a string, then changing the value of
`__builtins__.list` to e.g., `"foo"` will cause all calls to `list()`
to crash.
Obviously, if the payload can be a function, then it is possible to achieve @rce
this way.
One might argue that simply accessing an attribute that doesn't exist can
already cause the program to crash, but in that case, the program might
catch the exception (or verify that the attribute exists before accessing it)
because it could be expected that it might not exist.
However, the program is definitely not expecting the type of `list` to have changed
to a string.
The usage of these gadget is illustrated in @code:gadget-builtins.

#figure(caption: [How polluting a frequently used built-in
  can cause a #gls-shrt("dos") vulnerability])[
  ```py
  class Foo:
    def __init__(self):
      pass

  foo = Foo()

  glbs = getattr(getattr(foo, "__init__"), "__globals__")
  glbs["__builtins__"]["list"] = "foobar"

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

Apart from @code:gadget-getattr-only, a common example is showing
how changing the app key in a Flask application allows an attacker to
forge any cookies, and possibly bypassing authentication, as shown
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
use it to control certain behaviour.
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
for the current program, as shown by @code:gadget-pythonpath-hijack.
As for `COMSPEC`, it is only useful on Windows, where it can be used to achieve
@rce when a call to `subprocess.Popen` is made @pp-python-blog.

#figure(caption: [Hijacking of Python's import path
  (`PYTHONPATH`/`sys.path`) leads to #gls-shrt("rce")])[
  #codly.codly(header: box(height: 9pt)[`main.py`])
  ```py
  import sys
  # pollute PYTHONPATH
  sys.path[0] = "./uploads"

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
Changing one of these values affects all future calls to the respective function,
if they do not include a value for the given parameter.

Modifying the values of `__defaults__` can be challenging because tuples are immutable,
so `__defaults__` would need to be polluted in one go, as a tuple.
It is not common for user input to be converted to a tuple (e.g., during JSON deserialization),
so this might be out of reach for most exploits, but nonetheless worth mentioning.
However, `__kwdefaults__` is a dictionary, meaning it is possible to pollute individual
values.
It might be more attractive to pollute functions specific to a certain application,
but one gadget available in the `subprocess` module is the `Popen` constructor,
which takes a `umask` named parameter.
Polluting this could be used, for example, to force all files created by child processes
to be world-readable and world-writable.
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
However, this does not work on classes defined natively in CPython, at the C++
level, because those are immutable.
Furthermore, all of their methods lack any reference to `__globals__`,
as well as `__defaults__` and `__kwdefaults__`.
In practice, this means that even given a function vulnerable to class
pollution, if traversal starts in a native class, such as a `dict`,
`list` or `tuple`, the code is not exploitable.

=== Summary // TODO: is there a better way to name this?

The results of this literature review let us answer @rq-causes-consequences[].
In summary, class pollution can be exploited via recursive calls to
`getattr` and `__getitem__`, finalised by a call to `setattr` or `__setitem__`.
Many gadgets become accessible when it is possible to traverse through the
`__globals__` attribute of a function, which can result in @dos, authentication
bypass, or even @rce.
== Static Code Analysis <bg:static-analysis>

- analyse source code directly; no execution
- difficult in python due to dynamic/lax typing

#lorem(20)

=== Taint Analysis

=== Pysa

== Previous Work

#lorem(50)
