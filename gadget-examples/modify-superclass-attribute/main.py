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


class Foobar:
    MY_ATTR = "default value"
    pass


class Foo(Foobar):
    pass


class Bar(Foobar):
    pass


payload = {"__class__": {"__base__": {"MY_ATTR": "pwned"}}}

foo = Foo()
bar = Bar()
print(foo.MY_ATTR)  # default value
print(bar.MY_ATTR)  # default value

merge(payload, foo)

print(foo.MY_ATTR)  # pwned
print(bar.MY_ATTR)  # pwned
