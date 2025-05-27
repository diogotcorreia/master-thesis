import json
import os
from pathlib import Path
import random
import tomli_w

save_path = Path(os.path.dirname(os.path.realpath(__file__))) / "github" / "data"

DATASET_SIZE = 5

with open(save_path / "all-repos.json") as f:
    repos = json.load(f)["repos"]

selected_repos = random.choices(repos, k=DATASET_SIZE)


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
            # TODO pin rev from latest tag and/or default branch
            "rev": repo["default_branch"],
            # This will have to be adjusted manually if needed
            "basedir": "",
        },
        "extra_dependencies": [],
        "meta": meta,
    }


result = {
    "repos": list(map(process_repo, selected_repos)),
}

out_path = Path(os.path.realpath(".")) / "dataset.toml"

with open(out_path, "wb") as f:
    tomli_w.dump(result, f)

print(f"Saved dataset of size {len(selected_repos)} to {out_path}")
