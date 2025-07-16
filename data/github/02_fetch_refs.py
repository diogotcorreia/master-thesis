import json
import os
import re
import subprocess
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
# also, keep track of already known revs
seen_repos = set()

dest = save_path / "revs.txt"
with open(dest, "a+") as revs_file:
    revs_file.seek(0)
    for line in revs_file:
        data = line.split("\t")
        id = data[1].strip()
        branch = data[2].strip()
        seen_repos.add((id, branch))

    if len(seen_repos) > 0:
        print(f"Resuming... {len(seen_repos)} revs already known")

    for path in files:
        with open(path, "r") as f:
            repos = json.load(f)["data"]["items"]
            for repo in repos:
                id = repo["id"]
                branch = repo["default_branch"]
                key = (str(id), branch)
                if key in seen_repos:
                    # we have processed this repo, skip
                    continue
                seen_repos.add(key)

                print(f"Fetching rev of {repo['full_name']}")

                res = subprocess.run(
                    ["git", "ls-remote", repo["clone_url"], f"refs/heads/{branch}"],
                    capture_output=True,
                )
                assert res.stderr == b""
                lines = res.stdout.strip().split(b"\n")
                data = lines[0].decode('utf-8').split("\t")
                ref = data[1]
                assert ref == f"refs/heads/{branch}"
                rev = data[0]
                assert len(rev) == 40  # sha1 hex length

                revs_file.write(f"{rev}\t{id}\t{branch}\n")

print(f"Saved {len(seen_repos)} revs to {dest}")
