# Contributing

Thank you for your interest in contributing to Purchase Statistics.

Purchase Statistics is an early-stage Flutter app for tracking and analyzing Steam game purchases. Contributions are welcome when they stay aligned with the project's goal: a local-first, privacy-conscious app for purchase history, spending statistics, collections, goals, Steam metadata, and optional Steam playtime sync.

## Project Scope

This project is independent and not affiliated with Valve, Steam, or any other third-party platform.

Good contribution areas include:

- Bug fixes
- Test coverage
- UI and layout improvements for Windows, Linux, and Android
- CSV import and export improvements
- Backup and restore support
- Statistics, charts, insights, collections, and goals
- Steam Store search, metadata, and app-linking improvements
- Documentation and privacy/security clarifications

Please keep changes focused. Unrelated refactors should be opened separately from feature or bug-fix work.

## Development Setup

Requirements:

- Flutter SDK
- Dart
- Git
- Platform build tools for your target platform
- Linux `libsecret-1-0` and `libsecret-1-dev` when building or running the Linux app

Check your Flutter setup:

```powershell
flutter doctor
```

Install dependencies:

```powershell
flutter pub get
```

Run the app:

```powershell
flutter run
```

Run tests:

```powershell
flutter test
```

Run static analysis:

```powershell
flutter analyze
```

Run the repository security scan:

```powershell
dart tool/security_scan.dart
```

Format Dart files:

```powershell
dart format .
```

## Branch Workflow

Use a focused feature branch:

```powershell
git checkout develop
git pull
git checkout -b feature/short-description
```

Recommended branch prefixes:

- `feature/` for user-facing features
- `fix/` for bug fixes
- `docs/` for documentation-only changes
- `test/` for test-only changes
- `chore/` for maintenance work

Enable the local hooks once per clone if you want staged files scanned before commits and reachable Git history scanned before pushes:

```powershell
git config core.hooksPath .githooks
```

## Commit Messages

Use short, descriptive commit messages. Conventional-style prefixes are preferred:

- `feat: add backup restore flow`
- `fix: handle empty Steam search results`
- `docs: update privacy policy`
- `test: cover CSV delimiter detection`
- `chore: update dependencies`

## Coding Guidelines

- Follow the existing Flutter and Dart style in the repository.
- Keep app logic in the existing `lib/data`, `lib/logic`, `lib/models`, `lib/screens`, `lib/settings`, and `lib/widgets` structure where possible.
- Prefer small, focused changes over broad rewrites.
- Add or update tests for behavior changes.
- Keep UI text centralized in `lib/l10n/app_strings.dart` when it is user-facing.
- Do not introduce network calls that run automatically without clear user action.
- Do not store additional personal data unless the feature clearly needs it and the privacy policy is updated.

## Tests

Before opening a pull request, run:

```powershell
dart format .
dart tool/security_scan.dart
flutter analyze
flutter test
```

When changing data import, statistics, Steam metadata, repositories, or database behavior, add focused tests that cover the new behavior and likely edge cases.

## Privacy and Data Handling

Do not commit or post:

- Steam Web API keys
- Steam passwords, authentication cookies, or private account data
- Local SQLite databases
- Full CSV exports containing real purchase data
- Length-estimate CSV exports if the listed games or Steam App IDs should stay private
- Screenshots that show secrets, private profile data, or personal purchase history

Use fake or minimal sample data in issues, tests, and pull requests.

The repository includes `tool/security_scan.dart`, local hooks under `.githooks`, and a GitHub Actions workflow that reject common secret patterns and private local files. Do not bypass those checks for real data; replace sensitive values with placeholders instead.

If a change affects stored data, Steam requests, app settings, CSV export/import, caching, or retention behavior, update `PRIVACY.md` in the same pull request.

If a change adds or updates runtime dependencies, bundled assets, generated binaries, or third-party code, check the license compatibility and update `THIRD_PARTY_NOTICES.md` in the same pull request.

## Security

Security issues should be reported privately when possible. See `SECURITY.md` for supported versions, reporting guidance, and scope.

Do not disclose vulnerability details in public issues before the issue has been reviewed.

## Pull Requests

Before submitting a pull request, check that:

- The change has a clear purpose and scope.
- New behavior is covered by tests where practical.
- `dart format .` has been run.
- `dart tool/security_scan.dart` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- Documentation is updated when user-facing behavior changes.
- `PRIVACY.md` is updated when data flows or storage behavior change.
- `THIRD_PARTY_NOTICES.md` is updated when dependencies, bundled assets, or third-party code change.

In the pull request description, include:

- What changed
- Why the change is needed
- How it was tested
- Screenshots or short recordings for visible UI changes, with sensitive data removed

## Issues

When opening a bug report, include:

- Platform and version, for example Windows, Linux, Android, macOS, iOS, or web
- App version, branch, or commit
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs or screenshots with secrets removed

For feature requests, describe the workflow or problem first. A proposed solution is useful, but the underlying use case is more important.

## License

By contributing, you agree that your contribution will be licensed under the same license as this repository: GNU General Public License version 3 or later (`GPL-3.0-or-later`).

Do not submit code, assets, or dependencies that cannot be distributed with a GPLv3-or-later app.
