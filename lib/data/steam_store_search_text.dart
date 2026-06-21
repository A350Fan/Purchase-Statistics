// SPDX-License-Identifier: GPL-3.0-or-later
final _ignoredSteamSearchSymbolPattern = RegExp(
  r'[\u00a9\u00ae\u2117\u2120\u2122]',
);
final _whitespacePattern = RegExp(r'\s+');

/// Normalisiert Suchtexte fuer Cache-Keys und fuzzy Vergleiche.
///
/// Trademark-Symbole und mehrfacher Whitespace wuerden sonst dazu fuehren, dass
/// eigentlich gleiche Steam-Titel als unterschiedlich behandelt werden.
String normalizeSteamStoreSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(_ignoredSteamSearchSymbolPattern, ' ')
      .trim()
      .replaceAll(_whitespacePattern, ' ');
}
