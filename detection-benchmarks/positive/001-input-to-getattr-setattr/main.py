text1: str = input()
text2: str = input()
text3: str = input()
text4: str = input()

class A:
    def __init__():
        pass

a = A()

foo = getattr(a, text1)
bar = getattr(foo, text2)
setattr(bar, text3, text4)
