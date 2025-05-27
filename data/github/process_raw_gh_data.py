import json
import os
import re
from pathlib import Path

files = []

save_path = Path(os.path.dirname(os.path.realpath(__file__))) / "data"
file_format = re.compile(r"^search-page(\d+)\.json$")

with os.scandir(save_path) as it:
    for entry in it:
        if entry.is_file() and re.match(file_format, entry.name):
            files.append(save_path / entry.name)

print(f"Getting data from {len(files)} file(s)")

# some data is repeated, deduplicate it
seen_repos = set()

all_repos = []

for path in files:
    with open(path, "r") as f:
        repos = json.load(f)["data"]["items"]
        for repo in repos:
            id = repo["id"]
            if id in seen_repos:
                # we have processed this repo, skip
                continue
            seen_repos.add(id)

            all_repos.append(
                {
                    "full_name": repo["full_name"],
                    "stars": repo["stargazers_count"],
                    "homepage": repo["homepage"] or "",
                    "default_branch": repo["default_branch"],
                    "test": {"a": "b"},
                }
            )

all_repos.sort(key=lambda repo: repo["stars"], reverse=True)

dest = save_path / "all-repos.json"

with open(dest, "w") as f:
    json.dump({"repos": all_repos}, f)

print(f"Saved {len(all_repos)} repositories to {dest}")
