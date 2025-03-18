# Gadget Examples

This directory contains some examples of possible gadgets when class pollution
is achieved through a recursive merge-like function, such as the following:

```py
def merge(src, dst):
    for k, v in src.items():
        if hasattr(dst, '__getitem__'):
            if dst.get(k) and isinstance(v, dict):
                merge(v, dst.get(k))
            else:
                dst[k] = v
        elif hasattr(dst, k) and isinstance(v, dict):
            merge(v, getattr(dst, k))
        else:
            setattr(dst, k, v)
```

## Source

Gadgets were inspired by the following sources:

- https://blog.abdulrah33m.com/prototype-pollution-in-python/
