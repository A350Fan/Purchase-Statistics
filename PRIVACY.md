# Privacy Policy

Last updated: May 26, 2026

This Privacy Policy applies to **Purchase Statistics**. The app is an independent project and is not affiliated with, sponsored by, or endorsed by Valve or Steam.

The app is built as a local desktop/mobile app without a project-operated backend. The project maintainer does not receive a copy of your local app data through the app. Data is stored locally on your device or, when you actively use a Steam feature, sent to Valve/Steam services as described below.

## Summary

- The app does not provide or require an app account.
- The app does not use analytics, tracking, advertising, or telemetry for the project maintainer.
- Purchases, non-secret settings, Steam links, goals, collections, metadata, and caches are stored locally in a SQLite database.
- Steam data is requested only when you use Steam search, Steam app linking, metadata refresh, or Steam playtime sync.
- The Steam Web API key is stored locally in the platform secure store where available and is used only for Steam Web API requests to Valve.

## Locally Entered and Stored Data

The app may store the following data locally:

| Data type | Examples | Purpose |
| --- | --- | --- |
| Purchase data | Purchase date, game name, DLC name, edition, paid price, list price, status, notes | Purchase tracking, statistics, filters, and charts |
| Steam links | Steam App ID per purchase | Linking local purchases to Steam games or DLCs |
| Playtime data | `playtime_hours` per linked Steam App ID | Price-per-hour statistics and playtime analysis |
| Game metadata | Name, release date, genres, tags/categories, developers, publishers, unavailable metadata refresh markers | Collections, filters, previews, metadata display, and avoiding repeated requests for unavailable Steam metadata |
| Steam sync settings | SteamID64, Steam profile name or profile URL, Steam Web API key, include played free games option | Steam playtime sync |
| Steam Store search cache | Normalized search term, language, country, purchase type, result names, App IDs, result type, expiration time | Faster Steam search and fewer repeated requests |
| App settings | Theme, language, currency | App display and localization |
| Collections and goals | Collection names, rules, goal values | Organization and progress displays |

## Steam and Valve Requests

### Steam Store Search and App Linking

The app uses Steam Store search when you search for a game or DLC in the purchase editor, when autocomplete loads Steam results after at least three characters, when you open the dialog for linking a Steam App, or when you run automatic Steam app linking.

The app sends the following data to `store.steampowered.com/api/storesearch/`:

- Search term, for DLCs possibly combined with the associated game name
- Language
- Country/region code, which may influence currency and regional Store results

The app receives Steam search suggestions, especially:

- Steam Store item name
- Steam App ID
- Item type, if available, such as game or DLC

The app stores a local search cache containing the normalized search term, language, country, purchase type, result list, and expiration time. Successful search results are considered valid for 30 days. Empty results are considered valid for 1 day. Expired cache entries are no longer used, but they may remain in the local database until they are overwritten or you delete the app data.

### Steam Game Metadata

The app requests Steam game metadata when you save or edit a purchase with a Steam App ID, when the purchase editor loads a metadata preview, or when you run a refresh for missing or all metadata.

The app sends the following data to `store.steampowered.com/api/appdetails`:

- Steam App ID
- Language
- Country/region code, which may influence currency and regional Store results

The app stores the following data from Steam, when available:

- Name
- Release date and release date text
- Genres
- Categories/tags
- Developers
- Publishers
- Local update timestamp

If Steam does not return metadata for a linked Steam App ID, for example because the Store page is unavailable or delisted, the app may store the App ID and a local last-checked timestamp. This marker is used only to skip repeated metadata refresh attempts for a seven-day retry period; it does not remove the Steam App ID from the purchase and does not affect playtime sync.

### Steam Web API Playtime Sync

Playtime sync does not run automatically. It runs only when you start the **Steam playtime sync** action in the app and have previously saved a Steam account identifier and Steam Web API key in the settings.

If you enter a SteamID64, the app uses it directly. If you enter a Steam profile name or profile URL, the app first calls `api.steampowered.com/ISteamUser/ResolveVanityURL/v1/` to resolve it to a SteamID64.

The app sends the following data to Valve for vanity URL resolution:

- Steam Web API key
- Steam profile name or vanity URL, if no SteamID64 was entered

For the actual playtime sync, the app calls `api.steampowered.com/IPlayerService/GetOwnedGames/v1/`.

The app sends the following data to Valve:

- Steam Web API key
- SteamID64
- Whether played free games should be included
- A request to include app information

The app receives the following data from Steam:

- The list of games for the configured Steam profile, if the profile and game details are publicly available
- Steam App IDs
- Game names
- Total playtime in minutes

The app processes this response locally in memory, matches it against purchases that already have a Steam App ID, and stores only the calculated `playtime_hours` for matching local purchases. Games from the Steam response that are not linked to a local purchase are not stored permanently. Purchase history, order history, payment data, and Steam passwords are not requested.

## Storage Location and Storage Countries

The app stores most data locally in the SQLite database `steam_stats.db`. SQLite may also create files with the suffixes `-wal` and `-shm` next to the database. The Steam Web API key is stored separately in the platform secure store where available. Older plaintext API keys from previous local databases are migrated to secure storage and cleared from SQLite after the migration attempt. If secure storage is unavailable during migration, the plaintext key is still removed from SQLite and must be entered again.

Default storage locations for currently targeted platforms:

| Platform | Storage location |
| --- | --- |
| Windows | `%APPDATA%\PurchaseStatistics\steam_stats.db` |
| Linux | `$XDG_DATA_HOME/purchase_statistics/steam_stats.db` or `~/.local/share/purchase_statistics/steam_stats.db` |
| Android | App-specific database directory managed by Android |

The project does not store app data on project-operated servers. Locally stored data is stored in the country where the device is located. For the maintainer's own use of the app, the intended storage country is Germany. If you use or distribute the app in another country, the local database is stored in the country of the respective device. Operating system or cloud backups such as OneDrive, iCloud, Google Drive, or similar services are not controlled by the app.

## Sharing With Third Parties

The app transmits data only to Valve/Steam when you use one of the Steam features described above. Valve processes those requests under Valve's applicable terms and privacy rules. Through those requests, Valve may receive data such as your IP address, request timestamps, API parameters, and the requested Steam data.

The app does not send local purchase prices, notes, collections, goals, or CSV contents to the project maintainer.

When you create the separate length-estimate CSV export, the app writes only game name, optional Steam App ID, main story hours, main + extras hours, and completionist hours. It does not include purchase dates, prices, status, playtime, notes, collections, or goals.

## Retention and Deletion

- Purchase data, collections, goals, settings, Steam App IDs, stored playtime, metadata, and unavailable metadata refresh markers remain stored locally until you change or delete them in the app or remove the app data.
- You can remove Steam sync credentials by saving the Steam settings fields as empty values.
- You can fully remove the local search cache by deleting the local app database or app data.
- Full and length-estimate CSV exports are created only at the location you choose during export.

## Security

The app relies on the security protections of your operating system and user account. The local SQLite database is currently not additionally encrypted by the app. The Steam Web API key is stored in platform secure storage where available, for example Windows credential storage, Android encrypted storage, or the Linux Secret Service/libsecret stack. Steam sync error messages shown by the app are sanitized and do not include raw request URLs. The key should still be treated as a secret. Do not publish it, share it, or post screenshots that show it.

## Steam Data and Availability

Steam data is provided by Valve/Steam and may be incomplete, outdated, or temporarily unavailable. The app displays and stores this data without any warranty of accuracy, completeness, or continued availability. Valve may change, restrict, or discontinue the Steam APIs.

## Changes to This Policy

This Privacy Policy may be updated when the app's data flows, storage locations, or Steam features change. The date above shows the version date of this policy.

## Contact

This project does not operate its own app backend. Questions about app data processing can be raised through a repository issue. Please do not include Steam Web API keys, personal purchase data, or other sensitive information in public issues.

## Relevant External Terms

- Steam Web API Terms of Use: <https://steamcommunity.com/dev/apiterms>
- Steam Subscriber Agreement: <https://store.steampowered.com/subscriber_agreement/>
