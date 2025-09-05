#import "../utils/constants.typ": TheTool
#import "../utils/global-imports.typ": cve
#import "./ch05-results.typ": raw_data, vulnerable_projects

= Conclusion <conclusion>

In this work, a literature review has been conducted that shows
how the careless use of the `getattr` and `setattr` functions in Python
can lead to a novel security vulnerability known as class pollution.
While this vulnerability can seem innocuous at first,
it has become clear that when combined with other apparently benign
pieces of code, so-called gadgets,
it can allow escalation to severe vulnerabilities such as @rce.

Moreover, a tool, named #TheTool,
has been developed to aid with finding the dangerous constructs
that can lead to class pollution,
and it has good precision and performance.
Notably, it is able to detect class pollution in all currently
known vulnerable projects.

Furthermore, an empirical study has been conducted on the latest
version of #raw_data.len() popular open-source Python projects,
where #TheTool has detected potential vulnerabilities in
#vulnerable_projects.len() of them.
This shows that while this is an uncommon vulnerability,
it is possible for it to go unnoticed in many projects.

Then, a case study has been conducted in one vulnerable project,
and it has been shown how to approach potentially vulnerable code
in order to build a successful exploit.
This resulted in #cve("CVE-2025-58367") being published for the affected project,
showing that class pollution is not just a theoretical vulnerability,
but it can severely affect production code.

As a final note,
the results of the accompanying literature review and this thesis as a whole
will hopefully be able to generate awareness for
developers to be careful when using the `getattr`/`setattr` constructs,
and for researchers to further investigate this topic and ways to detect
and prevent class pollution in Python.
