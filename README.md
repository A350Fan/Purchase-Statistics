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

---

## Setup

### Requirements

- Flutter SDK
- Dart
- Git
- Visual Studio Code or Android Studio
- Platform build tools depending on the target platform

Check the local Flutter setup:

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
- Add categories/tags
- Add optional HowLongToBeat length lookup
- Add more chart types
- Add full release packaging for Windows
- Add AppImage packaging for Linux
- Add Steam Web API integration
- Add automatic playtime updates

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

---

## Disclaimer

Purchase Statistics is a private/open-source helper project for manually tracking Steam purchases.

It does **not** connect to Steam automatically yet and does **not** access a Steam account.

Steam, Valve and related names are trademarks of their respective owners.
