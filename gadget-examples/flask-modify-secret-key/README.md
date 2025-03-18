# Flask Modify Secret Key

This example shows how to pollute the app secret for a Flask application,
which allows a remote user to forge session cookies, therefore potentially
gaining unauthorized access to the application.

- **Path:** `__init__.__globals__["app"].secret_key`
- **Bracket Notation Needed?** Yes

## Instructions

Run `main.py`, followed by `exploit.py`.
