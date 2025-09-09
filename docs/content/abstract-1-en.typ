Over the past few decades,
code reuse attacks have shown how malicious attackers
can alter a program's normal execution flow
by taking advantage of benign code already present in the application.
Class Pollution in the Python programming language
is a novel variant of a code reuse attack,
where a malicious actor is able to surgically mutate a variable
in any part of the application
in order to trigger a change in its execution flow.

However, there has been little to no research done on class pollution,
and there is also no readily-available tool that can detect it.
For this reason,
as part of this degree project,
a literature review on the causes and consequences of class pollution
has been conducted,
in addition to the development of a tool, named Classa,
capable of detecting class pollution.

Additionally, an empirical study on the prevalence of class pollution
in real-world Python code has been performed
by running Classa against a dataset of 3000 Python projects,
revealing a critical vulnerability in a popular PyPI package
with more than 30 million downloads.
This vulnerability allowed for Denial of Service and Remote Code Execution,
having since been responsibly disclosed and patched.

Altogether, the results revealed that while
not many real-world Python projects are susceptible to class pollution,
it is a vulnerability that must be accounted for when
building a secure application
due to the serious consequences it can lead to.
