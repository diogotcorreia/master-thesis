#import "../utils/constants.typ": TheTool
#import "../content/ch05-results.typ": raw_data

Over the past few decades,
code reuse attacks have shown how malicious actors
can alter a program's intended execution flow
by taking advantage of benign code already present in the application.
Class Pollution in the Python programming language
is a novel variant of a code reuse attack,
which can enable a malicious party to surgically mutate a variable
in any part of the application
in order to trigger a change in its execution flow.

However, until now,
little to no research has explored class pollution in detail,
and no tool is readily-available to detect it.
For this reason,
as part of this degree project,
a literature review on the causes and consequences of class pollution
has been conducted,
in addition to the methodical development of a tool
capable of detecting class pollution,
#TheTool.

Additionally, an empirical study on the prevalence of class pollution
in real-world Python code has been performed
by running #TheTool against a dataset of #raw_data.len() Python projects,
revealing, most notably, a critical vulnerability in a popular PyPI package
with more than 30 million downloads.
This vulnerability allowed for Denial of Service and Remote Code Execution,
having since been responsibly disclosed and patched.

Altogether, the results revealed that while
not many real-world Python projects are susceptible to class pollution,
it is a vulnerability that must be accounted for when
building a secure application
due to the serious consequences it can lead to.
