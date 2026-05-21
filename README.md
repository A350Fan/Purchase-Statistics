# Steam Purchase Statistics (Early Prototype)

Steam Purchase Statistics is an early-stage Flutter app for tracking and analyzing Steam game purchases.

The project is intended as a lightweight replacement for a personal spreadsheet-based Steam statistics workflow.
It focuses on purchase history, spending statistics, discounts and later playtime-based analysis.

This project is **independent** and **not affiliated with Valve, Steam or any other third-party platform**.

Steam Purchase Statistics currently serves as a **lightweight technical foundation**:

- **Purchase model**: stores basic Steam purchase information such as game name, purchase date, price and optional original price.
- **Statistics logic**: calculates total spending, number of purchases, average discount and spending by year.
- **Responsive Flutter UI**: provides a simple dashboard layout for desktop and later mobile use.
- **Purchase form**: allows adding new purchases during runtime.
- **Repository layer**: separates app state from UI logic to prepare future persistent storage.

> Note: This is **not yet a full Steam library tracker**.  
> It is the stable base on which future features will be built  
> (SQLite storage, CSV/XLSX import, charts, playtime statistics and Android support).

---

## 1) Project Goals

The main goal of this project is to turn a spreadsheet-based Steam purchase tracker into a proper cross-platform app.

Planned target platforms:

- Windows
- Linux
- Android

The app is built with Flutter so that most of the logic can be shared across desktop and mobile versions.

---

## 2) Current Features

Already implemented:

- Basic Flutter app structure
- Responsive dashboard layout
- Steam purchase data model
- Runtime purchase list
- Add-purchase form
- Total spending calculation
- Purchase count calculation
- Average discount calculation
- Spending grouped by year
- Repository layer for purchase handling

Currently, added purchases are only stored during runtime.
Persistent storage is planned for a later version.

---

## 3) Planned Features

Next steps:

- Add SQLite storage
- Add edit/delete support for purchases
- Add CSV import
- Add optional XLSX import
- Add charts for yearly and quarterly spending
- Add cumulative spending view
- Add playtime tracking
- Add price-per-hour statistics
- Improve Android layout
- Add proper release builds for Windows and Linux

Possible future features:

- Steam Web API integration
- Automatic playtime updates
- Game categories/tags
- Backup and restore
- Export to CSV

---

## 4) Setup

### Requirements

- Flutter SDK
- Dart
- Git
- Android Studio or Visual Studio Code
- Windows, Linux or Android build tools depending on the target platform

Check your Flutter setup with:

```powershell
flutter doctor

---



## 5) Run the App

Will be added later...

## License & Usage

Copyright (c) 2026 A350Fan

This project is licensed under the MIT License.

You may use, copy, modify, merge, publish, distribute, sublicense and/or sell
copies of the software under the terms of the MIT License.

This project is independent and not affiliated with Valve or Steam.

See the .\LICENSE file for full details