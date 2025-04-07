text1: str = input()
text2: str = input()
text3: str = input()

class A:
    FOOBAR = 1
    def __init__():
        pass

a = A()

foo = getattr(a, text1)
bar = getattr(foo, "FOOBAR")
setattr(bar, text2, text3)
