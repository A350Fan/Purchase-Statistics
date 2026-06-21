// SPDX-License-Identifier: GPL-3.0-or-later
/// Metadatenfelder, die aus Steam gelesen und fuer automatische Sammlungen
/// verwendet werden.
enum SteamMetadataField {
  genre('genre'),
  tag('tag'),
  developer('developer'),
  publisher('publisher');

  final String storageValue;

  const SteamMetadataField(this.storageValue);

  static SteamMetadataField fromStorage(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    return SteamMetadataField.values.firstWhere(
      (field) => field.storageValue == normalizedValue,
      orElse: () => SteamMetadataField.tag,
    );
  }
}

/// Regel fuer den Vergleich einer Sammlung gegen Steam-Metadaten.
class SteamCollectionMetadataRule {
  final SteamMetadataField field;
  final String value;

  const SteamCollectionMetadataRule({required this.field, required this.value});

  bool matches(SteamGameMetadata metadata) {
    return metadata.matchesRule(this);
  }
}

/// Von Steam geladene Zusatzdaten zu einem Spiel.
///
/// Die Listen sind bewusst einfache Strings, weil sie direkt aus der Steam-API
/// kommen und fuer Anzeige, Suche und automatische Sammlungen verwendet werden.
class SteamGameMetadata {
  final int steamAppId;
  final String name;
  final DateTime? releaseDate;
  final String? releaseDateText;
  final List<String> genres;
  final List<String> tags;
  final List<String> developers;
  final List<String> publishers;

  const SteamGameMetadata({
    required this.steamAppId,
    required this.name,
    this.releaseDate,
    this.releaseDateText,
    this.genres = const [],
    this.tags = const [],
    this.developers = const [],
    this.publishers = const [],
  });

  /// Prueft, ob eines der passenden Metadatenfelder exakt mit der Regel
  /// uebereinstimmt. Der Vergleich normalisiert Gross-/Kleinschreibung und
  /// Whitespace, laesst den sichtbaren Wert aber unveraendert.
  bool matchesRule(SteamCollectionMetadataRule rule) {
    final values = switch (rule.field) {
      SteamMetadataField.genre => genres,
      SteamMetadataField.tag => tags,
      SteamMetadataField.developer => developers,
      SteamMetadataField.publisher => publishers,
    };

    return values.any((value) => _normalize(value) == _normalize(rule.value));
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
