# Dataset

This directory contains the dataset of repositories and projects the tool will be tested against.
While you can run the scripts manually to recreate the dataset (instruction below),
a pre-compiled dataset is included for convenience and reproducibility.

## Generating dataset

Running `./github/get_repos.py` will generate a list of all the Python GitHub repos with
at least 1000 stars.
The script supports resuming a stopped session, and respects GitHub's rate-limit.
This then needs to be pre-processed by another script, since it saves the raw response
from GitHub.

Then, running `./github/process_raw_gh_data.py` will generate a JSON file that
merges the previously fetched data and strips out unnecessary information.

Finally, running `./gen_input_dataset.py` will generate a `dataset.toml` in the current
directory, containing a random subset of packages.
This file can be fed directly into the tool present in this repository, which will analyse
them for class pollution vulnerabilities.
