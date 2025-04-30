text1: str = input()
text2: str = input()
text3: str = input()

class User:
    def __init__():
        pass

    def get(self, keys):
        obj = self
        for key in keys:
            obj = getattr(obj, key)
        return obj

def update(obj, key: str, value: str):
    setattr(obj, key, value)

def foo(user: User, bar: str, baz: str, value: str):
    obj = user.get([bar])
    update(obj, baz, value)

foo(User(), text1, text2, text3)
