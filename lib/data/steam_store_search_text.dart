final _ignoredSteamSearchSymbolPattern = RegExp(
  r'[\u00a9\u00ae\u2117\u2120\u2122]',
);
final _whitespacePattern = RegExp(r'\s+');

String normalizeSteamStoreSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(_ignoredSteamSearchSymbolPattern, ' ')
      .trim()
      .replaceAll(_whitespacePattern, ' ');
}
