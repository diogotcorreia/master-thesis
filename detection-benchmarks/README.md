# Detection Benchmarks

This directory contains various artificial tests that can be used to evaluate the
accuracy of the detection tool.

## Folder Structure

There are two directories: `positive` and `negative`.
The `positive` directory contains code that is vulnerable to class pollution and
should be detected as such, while the `negative` directory contains code
that is NOT, which is used to test the false positive rate of the tool.

Each directory then contains a directory per tests, named with a zero-padded
numeric identifier and a short description of the test.
The identifier does not identify the "difficulty" of the test and is merely an
indicator of creation order.
