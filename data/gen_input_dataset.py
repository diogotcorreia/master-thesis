import json
import os
from pathlib import Path
import random
import tomli_w

save_path = Path(os.path.dirname(os.path.realpath(__file__))) / "github" / "data"

MOST_STARRED_SIZE = 1000
MOST_STARRED_PICK = 500
MIDDLE_PICK = 500
LEAST_STARRED_SIZE = 1000
LEAST_STARRED_PICK = 500

with open(save_path / "all-repos.json") as f:
    repos = json.load(f)["repos"]

repos.sort(key=lambda r: r["stars"], reverse=True)

most_starred = repos[:MOST_STARRED_SIZE]
middle = repos[MOST_STARRED_SIZE:-LEAST_STARRED_SIZE]
least_starred = repos[-LEAST_STARRED_SIZE:]

selected_repos = (
    random.choices(most_starred, k=MOST_STARRED_PICK)
    + random.choices(middle, k=MIDDLE_PICK)
    + random.choices(least_starred, k=LEAST_STARRED_PICK)
)

# avoid leaving the least starred for last during analysis
random.shuffle(selected_repos)


def process_repo(repo):
    meta = {
        "repo_url": f"https://github.com/{repo['full_name']}",
        "stars": repo["stars"],
    }
    if repo["homepage"]:
        # toml doesn't accept None values
        meta["homepage"] = repo["homepage"]

    return {
        # replace / with ., since the former isn't a valid file name character
        # github users/orgs cannot contain a dot, so this is a good separator
        "id": f"gh.{repo['full_name'].replace('/', '.')}",
        "src": {
            # TODO get stuff from pypi instead, whenever possible
            "kind": "github",
            "full_name": repo["full_name"],
            "rev": repo["rev"],
            # This will have to be adjusted manually if needed
            "basedir": "",
        },
        "extra_dependencies": [],
        "meta": meta,
    }


result = {
    "repos": list(map(process_repo, selected_repos)),
    "resolve_dependencies_opts": {
        "denylisted_packages": [
            "pywin32",  # windows only
            "gssapi",  # fails to build under nix
        ],
        # some packages are not directly available on PyPI
        "additional_wheel_repos": [
            "https://download.pytorch.org/whl/torch_stable.html",
            "https://pytorch-geometric.com/whl/torch-2.3.0+cu121.html",
        ],
    },
}

out_path = Path(os.path.realpath(".")) / "dataset.toml"

with open(out_path, "wb") as f:
    tomli_w.dump(result, f)

print(f"Saved dataset of size {len(selected_repos)} to {out_path}")
