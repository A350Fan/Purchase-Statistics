# Purchase Statistics

Purchase Statistics is a Flutter app for tracking and analyzing Steam game purchases.

The project started as a replacement for a personal spreadsheet-based Steam statistics workflow. It focuses on purchase history, spending statistics, discounts, DLCs and playtime-based analysis.

This project is **independent** and **not affiliated with Valve, Steam or any other third-party platform**.

---

## Project Status

The app is currently an **early prototype**, but it already has persistent storage, CSV import/export and a dedicated statistics/dashboard UI.

Current target platforms:

- Windows
- Linux
- Android

Flutter is used so that the same app logic can be shared between desktop and mobile versions.

---

## Current Features

Implemented so far:

- Custom app icon
- Dark Material 3 based UI
- Responsive layout for desktop and smaller screens
- Persistent SQLite storage
- Desktop SQLite support via `sqflite_common_ffi`
- Add, edit and delete Steam purchases
- Delete confirmation dialog
- Game and DLC purchase types
- Optional game status for non-DLC games
- Optional edition field
- Optional DLC name field
- Optional original price/list price
- Optional playtime tracking
- Manual Steam Web API playtime sync for linked Steam App IDs
- Platform secure storage for the Steam Web API key
- Steam Store search suggestions for purchase editing
- Steam App ID linking and automatic linking support
- Local Steam Store search cache
- Steam game metadata lookup, preview and refresh, including seven-day retry throttling for unavailable or delisted Steam App IDs
- Collections for organizing purchases
- Optional game length estimates for main story, main + extras and completionist playthroughs
- Optional notes
- Sorting options for the purchase list
- Advanced purchase filters
- CSV import
- CSV export
- Smart insights for backlog and pile-of-shame analysis, including status review for heavily played games without a status
- Goal tracking for annual spending, backlog size, unplayed backlog value and completion rate
- Dashboard overview cards
- Yearly statistics table
- Quarterly statistics table
- Year selector for quarterly statistics
- Spending charts
- Discount charts
- Cumulative spending charts
- Basic price-per-hour statistics

---

## Data Model

A Steam purchase can currently store:

| Field | Description |
| --- | --- |
| `purchase_date` | Date of the purchase |
| `purchase_type` | `game` or `dlc` |
| `game_status` | Optional status for game purchases |
| `game_name` | Name of the game |
| `edition` | Optional edition/version |
| `dlc_name` | Optional DLC/add-on name |
| `steam_app_id` | Optional linked Steam App ID |
| `price` | Paid price |
| `original_price` | Optional original/list price |
| `playtime_hours` | Optional playtime in hours |
| `main_story_hours` | Optional estimated main story length in hours |
| `main_extra_hours` | Optional estimated main story + extras length in hours |
| `completionist_hours` | Optional estimated completionist length in hours |
| `note` | Optional note |

---

## Statistics

The app currently calculates:

- Total spending
- Total original/list price
- Total purchase count
- Number of games
- Number of DLCs
- Average discount
- Total playtime
- Price per hour
- Spending by year
- Average discount by year
- Playtime by year
- Price per hour by year
- Spending by quarter
- Average discount by quarter
- Playtime by quarter
- Price per hour by quarter
- Cumulative spending by year and quarter
- Projected current-year spending
- Backlog count and backlog value
- Unplayed backlog count and value
- Completion rate
- Expensive unplayed games
- Started but open games
- High cost-per-hour games
- Abandoned spending
- Status review for games with high playtime and no game status
- Estimated completion progress when game length data is available
- Goal progress for annual spending, backlog count, unplayed backlog count, unplayed backlog value and completion rate

For price-per-hour statistics, linked DLC spending is included for the matching base game when possible.

---

## CSV Import and Export

The app supports CSV files with the following columns:

```csv
purchase_date,purchase_type,game_status,game_name,edition,dlc_name,steam_app_id,price,original_price,playtime_hours,main_story_hours,main_extra_hours,completionist_hours,note
```

Required columns:

- `purchase_date`
- `game_name`
- `price`

Optional columns:

- `purchase_type`
- `game_status`
- `edition`
- `dlc_name`
- `steam_app_id`
- `original_price`
- `playtime_hours`
- `main_story_hours`
- `main_extra_hours`
- `completionist_hours`
- `note`

Supported delimiters:

- Comma: `,`
- Semicolon: `;`
- Tab

The importer also accepts some German/alternative column names, for example `datum`, `spiel`, `preis`, `spielzeit`, `status` and `notiz`.
Supported game status values include `open`, `active`, `completed`, `endless`, `abandoned` and `archived`; German values such as `offen`, `aktiv`, `durchgespielt`, `endlos`, `abgebrochen` and `archiviert` are accepted too.

CSV imports are limited to 5 MB and 10,000 data rows to avoid accidentally loading very large files into memory. CSV exports prefix text fields that look like spreadsheet formulas with an apostrophe so that opening an export in spreadsheet software does not execute formulas.

---

## Steam Playtime Sync

The app can update `playtime_hours` from the Steam Web API for purchases that already have a `steam_app_id`.

Requirements:

- A Steam Web API key
- A SteamID64 or custom Steam profile name
- Public game details on the Steam profile
- Linked Steam App IDs on the purchases that should be updated

How to get a Steam Web API key:

1. Sign in to Steam in your browser.
2. Open <https://steamcommunity.com/dev/apikey>.
3. Enter a domain name for the key. For local private use, `localhost` is usually sufficient.
4. Accept the Steam Web API terms and create/register the key.
5. Copy the generated key into the app settings under `Steam sync`.

Keep the API key private. Do not commit it, publish it or share screenshots that show it.

The Steam account identifier is stored locally in the app settings. The Steam Web API key is stored in the platform secure store where available, for example Windows credential storage, Android encrypted storage, or the Linux Secret Service/libsecret stack. Legacy plaintext keys from older local databases are migrated to secure storage when settings are loaded successfully. Use the automation menu to run the playtime sync. Steam returns playtime in minutes; the app converts it to hours before saving.

The sync does not import purchase dates, paid prices or order history. Those values still need to come from manual entry or CSV import.

---

## Privacy Policy

The privacy policy is available in [PRIVACY.md](PRIVACY.md). It documents which local and Steam-related data the app reads, when Steam requests are made, where data is stored and how long local data is kept.

---

## Setup

### Requirements

- Flutter SDK
- Dart
- Git
- Visual Studio Code or Android Studio
- Platform build tools depending on the target platform
- Android 6.0/API 23 or newer for Android builds
- Linux `libsecret` development/runtime packages for secure key storage

Check the local Flutter setup:

```powershell
flutter doctor
```

Install dependencies:

```powershell
flutter pub get
```

On Ubuntu/Debian-based Linux systems, install the secure storage dependency before building or running the Linux app:

```bash
sudo apt install libsecret-1-0 libsecret-1-dev
```

Run the app:

```powershell
flutter run
```

---

## Build

### Windows

```powershell
flutter build windows --release
```

The release output is created under:

```text
build/windows/x64/runner/Release
```

### Android APK

```powershell
flutter build apk --release
```

The APK is created under:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Linux

```bash
flutter build linux --release
```

The release output is created under:

```text
build/linux/x64/release/bundle
```

Packaging this Linux bundle as an AppImage is a separate packaging step.

---

## Database

The app stores purchases in a local SQLite database named:

```text
steam_stats.db
```

On desktop platforms, SQLite is initialized through `sqflite_common_ffi`.

The database schema is versioned and currently includes migrations for:

- Adding playtime tracking
- Adding game/DLC purchase types
- Adding edition and DLC name fields
- Adding game status
- Adding game length estimates
- Adding goal tracking
- Adding Steam Store search caching
- Adding Steam game metadata
- Adding unavailable Steam metadata refresh markers
- Adding collections

The Steam Web API key is not newly written to the SQLite database. Older plaintext values in the `app_settings.steam_web_api_key` column are migrated to platform secure storage and cleared from SQLite when secure storage is available.

---

## Project Structure

```text
lib/
├─ data/
│  ├─ app_database.dart
│  ├─ steam_purchase_csv.dart
│  └─ steam_purchase_repository.dart
├─ logic/
│  ├─ steam_insights.dart
│  └─ steam_statistics.dart
├─ models/
│  └─ steam_purchase.dart
├─ screens/
│  ├─ add_purchase_screen.dart
│  ├─ charts_tab.dart
│  ├─ collections_tab.dart
│  ├─ goals_tab.dart
│  ├─ home_screen.dart
│  ├─ purchase_filters.dart
│  ├─ smart_insights_tab.dart
│  └─ statistics_tab.dart
├─ widgets/
│  └─ stat_card.dart
└─ main.dart
```

---

## Planned Features

Possible next steps:

- Improve Android layout
- Add XLSX import
- Add backup and restore
- Add user-defined categories/tags
- Add optional HowLongToBeat length lookup
- Add more chart types
- Add full release packaging for Windows
- Add AppImage packaging for Linux

---

## Development Workflow

Recommended workflow:

```powershell
git checkout develop
git pull
git checkout -b feature/update-readme
```

After updating the README:

```powershell
git add README.md
git commit -m "docs: update readme"
git checkout develop
git merge feature/update-readme
git push
```

Before committing, run the repository security scan:

```powershell
dart tool/security_scan.dart
```

To enable the local pre-commit hook for this clone:

```powershell
git config core.hooksPath .githooks
```

The hooks scan staged files before commits and reachable Git history before pushes. They block common API keys, private keys, local databases, CSV/XLSX exports, mobile signing keys, Firebase config files, and local environment files. The same history-aware scan also runs in GitHub Actions for pushes and pull requests.

---

## Disclaimer

Purchase Statistics is a personal open-source helper project for tracking Steam purchases.

It can optionally connect to the Steam Web API to update playtime for a configured public Steam profile.

Steam, Valve and related names are trademarks of their respective owners.

---

## License

This project is licensed under the GNU General Public License version 3 or later (`GPL-3.0-or-later`). See [LICENSE](LICENSE) for details.

Third-party Flutter and Dart dependencies remain under their own licenses. The reviewed runtime dependency notices are summarized in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and the app exposes generated license notices under **Settings > Legal > Open source licenses**.

When distributing binary builds, provide the corresponding source code for the GPL-covered app and include the third-party license notices with the release package.
