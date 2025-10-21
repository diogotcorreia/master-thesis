#import "../utils/global-imports.typ": codly, pep, zero
#import "../utils/constants.typ": TheTool
#import "./ch05-results.typ": case_study_considered, projects_elapsed_seconds, projects_success, type_i_error_rate

#import zero: num

= Discussion <discussion>

In this chapter, an interpretation of the results is presented with regards to
the research questions in @discussion:rq,
while mitigations to this class of vulnerabilities is discussed
in @discussion:mitigations.
Then, limitations of the developed implementation and method taken are
discussed in @discussion:limitations,
while proposals and ideas for future work are laid out in @discussion:futurework.

== Research Questions <discussion:rq>

In this thesis, a tool that analyses projects in search of class pollution
vulnerabilities has been developed.
This resulted in a list of projects that could be vulnerable
to this novel attack vector.
Furthermore, an in-depth literature study has been conducted to better
highlight what code constructs can lead to class pollution and which
gadgets can be used during an exploit.

=== Causes and Consequences of Class Pollution

In @rq-causes-consequences[], it was asked what the root causes for class
pollution were, and what were the possible consequences of a successful
exploit.
This research question has already been answered in @bg:lit-review, but has
since been corroborated with the results from @results:case-study.
The proof-of-concept exploits presented in the case study validate that class
pollution in Python is not just a theoretical exploit, but that it can have real
consequences in applications deployed today.

=== Tool Design and Implementation <discussion:tool-design>

With @rq-tool-design[], the goal was to discover how to
design a tool that can both efficiently and accurately detect class pollution.
While #TheTool can be considered efficient, only taking up to
#projects_elapsed_seconds.median seconds to analyse most projects,
its precision could still be improved.

The results obtained during the empirical study reveal that the Type-I error
rate of #TheTool is acceptable, at #type_i_error_rate% false positives
when considering projects, though slightly higher when considering issues individually.
These rates reflect the complexity of performing static code analysis of Python
programs, where the lack of type annotations and complex language features
hinder the ability of taint analysis tools such as Pysa to correctly track
the taint flow in a program.

It was frequent for Pysa to report taint traces that were affected by taint
broadening, that is, where it considered an entire object to be tainted
when only parts of it were tainted.
While this might be useful for other applications of taint analysis, this
is almost never relevant for detecting class pollution, as the value
returned by `getattr` needs to flow without modifications to `setattr`.
For this reason, #TheTool was coded to discard some of the issues containing
broadening during post-processing.
However, as evidenced by the number of issues being marked as false positive
due to _Modified Reference_, further post-processing needs to be done to
ensure these are correctly filtered out.

Regarding Type-II errors, that is, false negatives, it is unfortunately not
possible to evaluate #TheTool in that regard due to the lack of a labeled
dataset to test against.
Given the scarcity of prior work in Python class pollution research, there is no
exhaustive list of projects vulnerable to it, apart from the very few used in
@results:micro-benchmarks, of which #TheTool managed to successfully identify
all of them.

However, #TheTool was still able to successfully identify many projects with
potential class pollution vulnerabilities, all of which have been compiled into
a table in @detailed-results.
Despite the number of false positives, this demonstrates that the implemented design,
that is, the use of static taint analysis, could be a path forward for detecting
class pollution in Python codebases.

Lastly, it is worth emphasising the two experiments ran alongside the
empirical study, with the goal of deciding whether to apply certain changes
to #TheTool.

The first of which, the installation of dependencies, as outlined in
@results:install-deps, is a clear regression in both efficiency and precision.
Due to the lack of a standard for declaring and pinning dependencies in
the past, it is often difficult to successfully install all the dependencies
for a project, resulting in either resolution or build errors.
This has since been greatly improved with the addition of `pyproject.toml`
and `pylock.toml`, but given that the latter was only officially
standardised in March of 2025 in #pep(751), most projects in the dataset understandably
did not include a dependency lockfile in their repositories.
Furthermore, the observed analysis time increased drastically, not just because
of dependency installation, but also due to Pysa taking significantly more
time to analyse all dependencies in addition to the primary project in question.
Moreover, with regards to false positive rates, the inclusion of
third-party code not only increased the amount of taint broadening that occurred,
but also reported duplicate issues for different projects that used the same
dependencies, which were usually false positives.
As a result, installing dependencies is clearly not beneficial for the
detection of class pollution.

On the other hand, the other experiment regarding counting the calls to
`getattr`, as outlined in @results:getattr-count,
is unquestionably a success when it comes to the precision of #TheTool.
While some issues were incorrectly filtered out,
those had suffered taint broadening
and it is therefore expected that Pysa might have failed to correctly
propagate the count of calls to `getattr`.

To conclude, as an answer to @rq-tool-design[], the results indicate that
the use of static taint analysis is a promising way of detect class
pollution in Python,
despite the need for some improvements to reduce the rate of false positives.

=== Prevalence in Real World Projects

Regarding @rq-widespread[], it has become clear from the results that not many
projects are vulnerable to class pollution.
This is likely due to the several constructs
that need to be present for attacks to be possible,
which are constructs not frequently used when
building Python applications.

Even when projects were deemed vulnerable,
from the examples in @code:vulnerable-labels it is clear that the exploitability
of any vulnerable code that contains negative features is significantly lower
than when no negative features are present.
Furthermore, when no features at all are present, the code is still not trivially
exploitable, since only gadgets within the same class hierarchy, and the class
hierarchy of its attributes, can be used, as explored in @bg:lit-review.

During human review of the vulnerabilities found, it stood out that many
of the projects, particularly those from the GitHub dataset, were @ml related.
For those projects, the vulnerable functions were mostly used to handle instances
of `torch.nn.Module`, a neural network module, and set parameters and weights
for the neural networks.
These usually made certain assumptions about the objects being traversed,
and were frequently labeled with _Additional Constraints_.

Moreover, something that became clear from the GitHub projects
analysed was that they were not always supposed to be used as an application,
but could simply contain Python scripts for other tasks.
One example is the *adobe-fonts/source-han-sans* repository, which mostly
contains fonts but has two Python scripts as part of the build process.
Another example is *sajjadium/ctf-archives*, a repository that contains
archives for @ctf competitions, and which was included in the dataset because the
predominant language in the repository is Python.

The reverse of this problem is that projects that might heavily use Python could
be missing from the dataset because the predominant language is not Python.
For example, a web application whose repository contains 51% HTML and 49% Python
code would be classified as an HTML repository by GitHub instead.
For this reason, it appears that the @pypi dataset yielded better results
when it comes to analysing relevant packages in which a vulnerability could
have a meaningful impact.

On a different note, when comparing these results to similar vulnerabilities
in other languages, namely prototype pollution in JavaScript, it is not
easy to determine which one is clearly more prevalent.
A stark difference between the two languages is that prototype
pollution in JavaScript is usually exploitable if it exists at all, whereas
class pollution in Python requires that the vulnerable function uses
`__getitem__` during traversal, sometimes `__setitem__` for setting
the values, and that the traversal does not start from a builtin type like
a dictionary, in order to have any meaningful possibility of exploitation.

#let prevalence_cp = case_study_considered.len()
#let total_cp = projects_success.len()
#let prevalence_rate_cp = calc.round((prevalence_cp / total_cp * 100), digits: 2)
#let prevalence_pp = 2738
#let total_pp = 1000000
#let prevalence_rate_pp = calc.round((prevalence_pp / total_pp * 100), digits: 2)

When performing a purely quantitative comparison against the results obtained
by #cite(form: "prose", <probetheproto>),
prototype pollution appears to be thrice as prevalent as class pollution.
To perform a fair comparison, only the vulnerabilities found that were labeled
with _Dict Access_ and _Supports `__setitem__`_ are being accounted for,
which results in an prevalence of #num(prevalence_cp) in #num(total_cp) (#prevalence_rate_cp%)
versus a prevalence of #num(prevalence_pp) in #num(total_pp) (#prevalence_rate_pp%) for
prototype pollution.
The gap is even more significant if only the single confirmed exploitable project is
accounted for.
However, this is not a perfect comparison, as the domain and type of applications
is clearly different.
Furthermore, this comparison might change once there is further research
on finding gadgets for class pollution, perhaps showing it could be easier
to exploit some of the findings from this degree project.

In conclusion, as an answer to @rq-widespread[], it has become clear that while
class pollution is not prevalent in most Python applications, it is still
a vulnerability that needs to be accounted for.
Notably, the obtained results show that when it is exploitable,
the consequences can be very serious and potentially even lead to @rce.

== Mitigations <discussion:mitigations>

When it comes to mitigating class pollution, the solution is rather simple:
restrict traversal on keys that start and end in `__`.
For most applications, this change would not affect functionality and
would prevent this vulnerability.
An example implementation of this fix is presented in @code:cp-fix.

#let mitigation_example = [#figure(
  caption: [Mitigating class pollution by forbidding dunder attributes
    during traversal],
  [
    #set text(size: 0.75em)
    #codly.codly(highlighted-lines: (4, 5))
    ```py
    def setattr_recursive(obj: any, path: str, value: any) -> None:
      path = path.split(".")
      for name in path[:-1]:
        if path.startswith("__") and path.endswith("__"):
          raise ValueError("traversing dunder attributes is not allowed")
        module = getattr(module, name)
      setattr(module, path[-1], value)
    ```
  ],
) <code:cp-fix>]
#mitigation_example

However, for certain libraries or applications, that mitigation might break
functionality as it could be necessary to traverse through other,
benign, dunder attributes.
One compromise solution found by the developers of *pydash* has been to forbid only
problematic dunder attributes such as `__globals__` and `__builtins__`
#footnote(link("https://github.com/dgilland/pydash/issues/180")).
While this does not defend against gadgets in the same class hierarchy,
it still defeats all the potentially dangerous gadgets that
could be present in other parts of the application.

== Limitations <discussion:limitations>

While this project attempts to design and implement a tool that can detect
class pollution, it is the first of its kind and therefore some aspects
have been simplified, or even entirely skipped, in the name of simplicity.

For instance, it is important to recall that the goal of this thesis is
simply to detect class pollution, which is just one part of the puzzle.
To successfully exploit this vulnerability, suitable gadgets need to
be found, which is out of the scope of this project.
The gadgets that have been presented throughout this document are mostly
already known, or in the case of the one showed during the case study,
they were immediately apparent from the surrounding context.
These gadgets have only been used to demonstrate the possible consequences
of class pollution.

Moreover, the developed tool has only been designed for detecting the simplest
form of class pollution, where traversal is only performed through class attributes
and dictionary entries.
It is certainly possible to achieve class pollution through more complex
traversals, which could include, for instance, function calls, but those
were ignored during the evaluation phase of this project.

It is also known that #TheTool falls short in certain cases even when trying
to detect the aforementioned simplest form of class pollution.
One such case is when the traversal does not contain `setattr`, but only
`__setitem__`.
While this is a less ideal exploitation scenario, it is still a valid
candidate for class pollution.
Support for detecting this situation has not been implemented due to
some limitations of Pysa regarding its taint models;
in particular, it is not possible to define a taint model for a class
method where the object type is `unknown`, which is often the resulting type
of a call to `getattr` due to the lack of typing.
An attempt was made to declare a model for `object.__setitem__`,
but it would fail to apply to its subclasses properly, mainly again due
to the lack of typing.

== Future Work <discussion:futurework>

As this is a novel type of vulnerability,
there is much future work that can
and should still be conducted on the topic.

Firstly, a second iteration of #TheTool should be developed,
learning from the results obtained in this degree project.
For example, it would beneficial to be able to automatically assign features
to each detected issue instead of relying on manual labeling.
This new tool could then be evaluated against this project's results,
available in @detailed-results and the accompanying repository.
Furthermore, as Pysa has demonstrated certain limitations when it
comes to detecting class pollution, it could be worth exploring
other static analysis tools such as GitHub's CodeQL
#footnote(link("https://codeql.github.com/")).

Secondly, as has already been discussed, this thesis did not have the
goal of researching possible gadgets for class pollution.
That is then a possible area for future research, as a complement to
this degree project, and would unlock automating the scan for
full-chain class pollution exploits.

Lastly, but nonetheless important,
a focus on improving the user experience for users of #TheTool
would encourage wider adoption.
For instance, the results are currently saved to a JSON file,
but there is no user-friendly interface to explore them.
Such interface would help developers and maintainers understand
where and how their code could be vulnerable.
