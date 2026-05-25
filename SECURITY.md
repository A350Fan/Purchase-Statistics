# Security Policy

## Supported Versions

Purchase Statistics is currently an early prototype. Security fixes are intended for the actively maintained development branch and the latest published release, if releases are available.

Older forks, local modifications, and outdated builds may not receive security fixes.

## Reporting a Vulnerability

Please report security issues privately whenever possible.

Preferred reporting options:

- Use GitHub Private Vulnerability Reporting or a GitHub Security Advisory for this repository, if available.
- If private reporting is not available, open a minimal public issue asking for a private contact path. Do not include vulnerability details in the public issue.

Please include:

- A short description of the issue
- Steps to reproduce the issue
- The affected target platform, for example Windows, Linux, or Android
- The app version, commit, or branch you tested
- Any relevant logs or screenshots with secrets removed

Do not include:

- Steam Web API keys
- Steam passwords or authentication cookies
- Private Steam account details
- Local SQLite databases
- CSV exports containing real purchase data
- Screenshots that show secrets, personal purchase data, or private profile data

## Security Scope

Security reports are especially useful for issues involving:

- Exposure or unsafe handling of Steam Web API keys
- Local database, CSV import, or CSV export data leaks
- Unsafe file handling during import, export, backup, or restore flows
- Unintended network requests
- Incorrect assumptions around Steam profile data, Steam App IDs, or cached Steam Store data
- Build, packaging, or dependency configuration issues

Issues in Valve or Steam services, Steam APIs, Steam accounts, or third-party infrastructure should be reported to the respective provider.

## Local Data and Secrets

The app stores data locally and does not use a project-operated backend. The local SQLite database is not additionally encrypted by the app. The Steam Web API key is currently stored locally with the app settings and should be treated as a secret.

Users should avoid sharing databases, exported CSV files, logs, or screenshots unless sensitive data has been removed.

## Response Expectations

After a vulnerability report is received, the maintainer will try to:

1. Confirm receipt of the report.
2. Reproduce and assess the issue.
3. Prepare a fix or mitigation when the issue affects this project.
4. Credit the reporter if requested and appropriate.

Response times may vary because this is a personal open-source project.

## Disclosure

Please avoid public disclosure until the issue has been reviewed and, where practical, a fix or mitigation is available.
