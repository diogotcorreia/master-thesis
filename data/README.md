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

// TODO
