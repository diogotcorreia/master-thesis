# Modify Superclass Attribute

This example shows how to pollute an attribute of the superclass (base class).
In case of a class hierarchy with more levels, one can keep adding `.__base__`
to go up a level.

- **Path:** `__class__.__base__.ATTR`
- **Bracket Notation Needed?** No
