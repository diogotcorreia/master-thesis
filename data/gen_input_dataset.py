import json
import os
from pathlib import Path
import random
import tomli_w


def pick_with_cohorts(lst, cohort_splits, cohort_pick):
    assert len(cohort_splits) + 1 == len(cohort_pick)
    cohort_splits = [0, *cohort_splits, None]

    cohorts = [lst[a:b] for a, b in zip(cohort_splits, cohort_splits[1:])]
    assert len(cohorts) == len(cohort_pick)

    result = []
    for i, cohort in enumerate(cohorts):
        result += random.choices(cohort, k=cohort_pick[i])

    # avoid having the cohorts separated during analysis
    random.shuffle(result)
    return result


save_path_gh = (
    Path(os.path.dirname(os.path.realpath(__file__)))
    / "github"
    / "data"
    / "all-repos.json"
)

with open(save_path_gh) as f:
    gh_repos = json.load(f)["repos"]


gh_repos.sort(key=lambda r: r["stars"], reverse=True)

gh_repos = pick_with_cohorts(
    gh_repos,
    [1000, -1000],  # split in top 1000 repos, bottom 1000, and the others
    [500, 500, 500],  # get 500 from each cohort
)

save_path_pypi = (
    Path(os.path.dirname(os.path.realpath(__file__))) / "pypi" / "data" / "data.json"
)

pypi_packages = []
with open(save_path_pypi) as f:
    for line in f:
        pypi_packages.append(json.loads(line))


pypi_packages.sort(key=lambda r: r["downloads"], reverse=True)

pypi_packages = pick_with_cohorts(
    pypi_packages,
    [3000, -3000],  # split in top 3000 packages, bottom 3000, and the others
    [500, 500, 500],  # get 500 from each cohort
)


def process_gh_repo(repo):
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
            "kind": "github",
            "full_name": repo["full_name"],
            "rev": repo["rev"],
            # This will have to be adjusted manually if needed
            "basedir": "",
        },
        "extra_dependencies": [],
        "meta": meta,
    }


def process_pypi_package(pkg):
    meta = {
        "downloads": pkg["downloads"],
    }

    return {
        "id": f"pypi.{pkg['name']}",
        "src": {
            "kind": "pypi",
            "name": pkg["name"],
            "version": pkg["version"],
            "download_url": pkg["url"],
            "filename": pkg["filename"],
        },
        "meta": meta,
    }


result = {
    "repos": list(map(process_gh_repo, gh_repos))
    + list(map(process_pypi_package, pypi_packages)),
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

print(f"Saved dataset of size {len(result["repos"])} to {out_path}")
