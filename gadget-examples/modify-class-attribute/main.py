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


class Foo:
    MY_ATTR = "default value"
    pass


payload1 = {"MY_ATTR": "bar"}

payload2 = {"__class__": {"MY_ATTR": "foobar"}}

foo_obj1 = Foo()
foo_obj2 = Foo()
print(foo_obj1.MY_ATTR)  # default value
print(foo_obj2.MY_ATTR)  # default value
merge(payload1, foo_obj1)

print(foo_obj1.MY_ATTR)  # bar
print(foo_obj2.MY_ATTR)  # default value

merge(payload2, foo_obj1) # notice we are still merging with foo_obj1

print(foo_obj1.MY_ATTR)  # bar
print(foo_obj2.MY_ATTR)  # foobar

# Note that foo_obj1 is still printing "bar" because it is set at the object level.
# On the other hand, foo_obj2 does not have that attribute, so it is searched in the
# class definition instead.
