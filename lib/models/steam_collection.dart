import 'steam_game_metadata.dart';

enum SteamCollectionSortMode {
  manual('manual'),
  releaseDateAsc('release_date_asc'),
  releaseDateDesc('release_date_desc');

  final String storageValue;

  const SteamCollectionSortMode(this.storageValue);

  static SteamCollectionSortMode fromStorage(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    return SteamCollectionSortMode.values.firstWhere(
      (sortMode) => sortMode.storageValue == normalizedValue,
      orElse: () => SteamCollectionSortMode.manual,
    );
  }
}

enum SteamCollectionType {
  manual('manual'),
  automatic('automatic');

  final String storageValue;

  const SteamCollectionType(this.storageValue);

  static SteamCollectionType fromStorage(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    return SteamCollectionType.values.firstWhere(
      (collectionType) => collectionType.storageValue == normalizedValue,
      orElse: () => SteamCollectionType.manual,
    );
  }
}

enum SteamCollectionRuleField {
  titleContains('title_contains'),
  genre('genre'),
  tag('tag'),
  developer('developer'),
  publisher('publisher');

  final String storageValue;

  const SteamCollectionRuleField(this.storageValue);

  bool get isMetadataField => metadataField != null;

  SteamMetadataField? get metadataField {
    return switch (this) {
      SteamCollectionRuleField.genre => SteamMetadataField.genre,
      SteamCollectionRuleField.tag => SteamMetadataField.tag,
      SteamCollectionRuleField.developer => SteamMetadataField.developer,
      SteamCollectionRuleField.publisher => SteamMetadataField.publisher,
      SteamCollectionRuleField.titleContains => null,
    };
  }

  static SteamCollectionRuleField? fromStorage(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    for (final field in SteamCollectionRuleField.values) {
      if (field.storageValue == normalizedValue) {
        return field;
      }
    }

    return null;
  }
}

class SteamCollection {
  static const SteamCollectionSortMode manualSortMode =
      SteamCollectionSortMode.manual;
  static const SteamCollectionType manualCollectionType =
      SteamCollectionType.manual;
  static const Object _unset = Object();

  final int? id;
  final String name;
  final String? description;
  final SteamCollectionSortMode sortMode;
  final SteamCollectionType collectionType;
  final SteamCollectionRuleField? ruleField;
  final String? ruleValue;
  final DateTime createdAt;

  const SteamCollection({
    this.id,
    required this.name,
    this.description,
    this.sortMode = manualSortMode,
    this.collectionType = manualCollectionType,
    this.ruleField,
    this.ruleValue,
    required this.createdAt,
  });

  bool get isManual => collectionType == SteamCollectionType.manual;
  bool get isAutomatic => collectionType == SteamCollectionType.automatic;

  SteamCollectionMetadataRule? get metadataRule {
    final value = _emptyToNull(ruleValue);
    final metadataField = ruleField?.metadataField;

    if (!isAutomatic || metadataField == null || value == null) {
      return null;
    }

    return SteamCollectionMetadataRule(field: metadataField, value: value);
  }

  factory SteamCollection.create({
    required String name,
    String? description,
    SteamCollectionSortMode sortMode = manualSortMode,
    SteamCollectionType collectionType = manualCollectionType,
    SteamCollectionRuleField? ruleField,
    String? ruleValue,
    DateTime Function()? now,
  }) {
    return SteamCollection(
      name: name,
      description: _emptyToNull(description),
      sortMode: sortMode,
      collectionType: collectionType,
      ruleField: collectionType == SteamCollectionType.automatic
          ? ruleField
          : null,
      ruleValue: collectionType == SteamCollectionType.automatic
          ? _emptyToNull(ruleValue)
          : null,
      createdAt: (now ?? DateTime.now)(),
    );
  }

  SteamCollection copyWith({
    int? id,
    String? name,
    Object? description = _unset,
    SteamCollectionSortMode? sortMode,
    SteamCollectionType? collectionType,
    Object? ruleField = _unset,
    Object? ruleValue = _unset,
    DateTime? createdAt,
  }) {
    final nextCollectionType = collectionType ?? this.collectionType;

    return SteamCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _unset)
          ? this.description
          : _emptyToNull(description as String?),
      sortMode: sortMode ?? this.sortMode,
      collectionType: nextCollectionType,
      ruleField: nextCollectionType == SteamCollectionType.automatic
          ? identical(ruleField, _unset)
                ? this.ruleField
                : ruleField as SteamCollectionRuleField?
          : null,
      ruleValue: nextCollectionType == SteamCollectionType.automatic
          ? identical(ruleValue, _unset)
                ? this.ruleValue
                : _emptyToNull(ruleValue as String?)
          : null,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sort_mode': sortMode.storageValue,
      'collection_type': collectionType.storageValue,
      'rule_field': ruleField?.storageValue,
      'rule_value': ruleValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SteamCollection.fromMap(Map<String, Object?> map) {
    return SteamCollection(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: _emptyToNull(map['description'] as String?),
      sortMode: SteamCollectionSortMode.fromStorage(map['sort_mode']),
      collectionType: SteamCollectionType.fromStorage(map['collection_type']),
      ruleField: SteamCollectionRuleField.fromStorage(map['rule_field']),
      ruleValue: _emptyToNull(map['rule_value'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static String? _emptyToNull(String? value) {
    final trimmedValue = value?.trim();

    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}
