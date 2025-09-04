text1: str = input()
text2: str = input()
text3: str = input()

class A:
    def __init__():
        pass

a = A()

# just a single call to getattr is not enough
foo = getattr(a, text1)
setattr(foo, text2, text3)
