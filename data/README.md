# Dataset

This directory contains the scripts used to obtain the dataset of repositories and projects
the tool has been be tested against.
While you can run the scripts manually to recreate the dataset (instructions below),
a pre-compiled dataset is included in the [releases tab] of this project for convenience and reproducibility.

## Generating dataset

Before generating a combined dataset, it is necessary to generate a dataset for
both GitHub repositories and PyPI packages.

### GitHub

Running `./github/01_get_repos.py` will generate a list of all the Python GitHub repos with
at least 1000 stars.
The script supports resuming a stopped session, and respects GitHub's rate-limit.
This then needs to be pre-processed by another script, since it saves the raw response
from GitHub.

Then, running `./github/02_fetch_refs.py` will fetch the latest commit in the default branch
of all repositories.
This script also supports resuming a stopped session.

Finally, running `./github/03_process_raw_gh_data.py` will generate a JSON file that
merges the previously fetched data and strips out unnecessary information.

### PyPI

Running `./pypi/get-top-packages.py` will fetch the latest version of the top 15 000 PyPI packages,
and pick an appropriate wheel or source distribution for each one.

### Final Dataset

Running `./gen_input_dataset.py` will generate a `dataset.toml` in the current
directory, containing a random subset of packages.
This file can be fed directly into the tool present in this repository, which will analyse
these packages for class pollution vulnerabilities.

[releases tab]: https://github.com/diogotcorreia/master-thesis/releases
