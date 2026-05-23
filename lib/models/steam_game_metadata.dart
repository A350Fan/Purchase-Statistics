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

class SteamCollectionMetadataRule {
  final SteamMetadataField field;
  final String value;

  const SteamCollectionMetadataRule({required this.field, required this.value});

  bool matches(SteamGameMetadata metadata) {
    return metadata.matchesRule(this);
  }
}

class SteamGameMetadata {
  final int steamAppId;
  final String name;
  final List<String> genres;
  final List<String> tags;
  final List<String> developers;
  final List<String> publishers;

  const SteamGameMetadata({
    required this.steamAppId,
    required this.name,
    this.genres = const [],
    this.tags = const [],
    this.developers = const [],
    this.publishers = const [],
  });

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
