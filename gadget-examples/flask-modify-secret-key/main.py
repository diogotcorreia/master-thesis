import os
from flask import Flask, session, request
app = Flask(__name__)

# Set secret key to random bytes
app.secret_key = os.urandom(64)

@app.route("/")
def hello():
    print(app.secret_key)
    if 'username' in session:
        return f"Hello {session["username"]}!"
    else:
        return "Hello!"

@app.route("/merge", methods=['POST'])
def merge_route():
    data = request.get_json()
    merge(data, foo)

    return "OK!"

class Foo:
    def __init__(self):
        pass

foo = Foo

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

if __name__ == "__main__":
    app.run()
