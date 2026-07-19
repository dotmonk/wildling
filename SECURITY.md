# Security policy

## Supported versions

This project is maintained on the `main` branch. There are no long-term
versioned release trains yet; treat the latest `main` as current.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security reports.

Email the maintainer at the address on the GitHub profile for
[dotmonk](https://github.com/dotmonk), or use GitHub’s private vulnerability
reporting for this repository if it is enabled.

Include:

- A short description of the issue
- Steps to reproduce
- Affected language port(s), if known
- Impact assessment if you have one

You should receive an acknowledgment when the report is seen. Fixes will be
coordinated before any public disclosure when practical.

## Scope notes

- Language ports intentionally shell out to Docker for builds; report issues in
  build scripts that would execute untrusted input unsafely.
- The browser sandbox runs only the bundled JavaScript library client-side; it
  should not contact the network.
- Demo dictionaries (e.g. `dictionaries/passwords.txt`) are sample wordlists,
  not credentials.
