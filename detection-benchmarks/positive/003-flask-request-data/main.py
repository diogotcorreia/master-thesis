from flask import Flask, request
app = Flask(__name__)

@app.route("/", methods=['POST'])
def hello():
    data = request.data
    merge(data, {})

    return "OK!"

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
