# Security policy

Elio holds the SSH key that opens your servers: security reports are taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.** Report it privately through GitHub:
[Security → Report a vulnerability](https://github.com/elio-fleet/elio/security/advisories/new)
(private security advisory). Include what you found, how to reproduce it and the version (`v0.1.0-beta.1`, a commit…).

You will get an answer within a week. Once a fix is released, the advisory is published with credit to you, unless you prefer otherwise.

## Supported versions

Elio is in beta: only the latest release (and `main`) receives security fixes.

## Scope

In scope: the Elio application (authentication, roles, 2FA, the handling of the SSH key and of the secrets, what it runs on the servers — see [`config/ssh_commands.yml`](config/ssh_commands.yml)), the Docker image and the release workflows.

Out of scope: vulnerabilities of the servers Elio monitors (that is what Elio reports to you), and attacks that need an administrator account of Elio or root on the machine running it.
