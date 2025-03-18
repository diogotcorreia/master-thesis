# Modify Unrelated Class

This example shows how to pollute an attribute of an unrelated class that is
present in the global scope of the class.
This can also be used to pollute global variables in general.

A requirement for this to work is that the class must have a function definition,
since functions save the global scope they were defined in.

- **Path:** `__init__.__globals__["Class"].ATTR`
- **Bracket Notation Needed?** Yes
