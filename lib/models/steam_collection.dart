// SPDX-License-Identifier: GPL-3.0-or-later
import 'steam_game_metadata.dart';

/// Sortiermodus fuer Inhalte innerhalb einer Sammlung.
///
/// `storageValue` ist der stabile Wert fuer SQLite, damit Enum-Namen im Code
/// spaeter geaendert werden koennen, ohne vorhandene Daten zu brechen.
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

/// Gibt an, ob eine Sammlung manuell gepflegt oder ueber eine Regel berechnet
/// wird.
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

/// Felder, auf denen automatische Sammlungsregeln basieren koennen.
///
/// `titleContains` arbeitet direkt auf Kauf-/Metadaten-Titeln, die anderen
/// Felder werden ueber Steam-Metadaten wie Genre, Tags oder Publisher gematcht.
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

/// Datenmodell fuer eine Sammlung.
///
/// Manuelle Sammlungen besitzen konkrete `CollectionItem`-Eintraege.
/// Automatische Sammlungen speichern nur eine Regel; die passenden Kaeufe
/// werden beim Laden aus der Datenbank berechnet.
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
  final bool includeDlcs;
  final DateTime createdAt;

  const SteamCollection({
    this.id,
    required this.name,
    this.description,
    this.sortMode = manualSortMode,
    this.collectionType = manualCollectionType,
    this.ruleField,
    this.ruleValue,
    this.includeDlcs = false,
    required this.createdAt,
  });

  bool get isManual => collectionType == SteamCollectionType.manual;
  bool get isAutomatic => collectionType == SteamCollectionType.automatic;

  /// Uebersetzt eine automatische Sammlungsregel in eine Metadatenregel.
  ///
  /// Fuer reine Titelsuchen gibt es keine Metadatenregel, deshalb kann hier
  /// `null` zurueckkommen.
  SteamCollectionMetadataRule? get metadataRule {
    final value = _emptyToNull(ruleValue);
    final metadataField = ruleField?.metadataField;

    if (!isAutomatic || metadataField == null || value == null) {
      return null;
    }

    return SteamCollectionMetadataRule(field: metadataField, value: value);
  }

  /// Factory fuer neue Sammlungen.
  ///
  /// Leere Texte werden direkt in `null` normalisiert und manuelle Sammlungen
  /// verlieren automatische Regelwerte, damit ungueltige Kombinationen gar
  /// nicht erst im Modell entstehen.
  factory SteamCollection.create({
    required String name,
    String? description,
    SteamCollectionSortMode sortMode = manualSortMode,
    SteamCollectionType collectionType = manualCollectionType,
    SteamCollectionRuleField? ruleField,
    String? ruleValue,
    bool includeDlcs = false,
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
      includeDlcs: collectionType == SteamCollectionType.automatic
          ? includeDlcs
          : false,
      createdAt: (now ?? DateTime.now)(),
    );
  }

  /// Kopiert eine Sammlung mit optional geaenderten Werten.
  ///
  /// Das `_unset`-Sentinel trennt "Wert nicht anfassen" von "Wert bewusst auf
  /// null setzen", was bei optionalen Textfeldern wichtig ist.
  SteamCollection copyWith({
    int? id,
    String? name,
    Object? description = _unset,
    SteamCollectionSortMode? sortMode,
    SteamCollectionType? collectionType,
    Object? ruleField = _unset,
    Object? ruleValue = _unset,
    bool? includeDlcs,
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
      includeDlcs: nextCollectionType == SteamCollectionType.automatic
          ? includeDlcs ?? this.includeDlcs
          : false,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialisiert die Sammlung fuer SQLite.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sort_mode': sortMode.storageValue,
      'collection_type': collectionType.storageValue,
      'rule_field': ruleField?.storageValue,
      'rule_value': ruleValue,
      'include_dlcs': includeDlcs ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Baut eine Sammlung aus einer SQLite-Zeile.
  factory SteamCollection.fromMap(Map<String, Object?> map) {
    final collectionType = SteamCollectionType.fromStorage(
      map['collection_type'],
    );

    return SteamCollection(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: _emptyToNull(map['description'] as String?),
      sortMode: SteamCollectionSortMode.fromStorage(map['sort_mode']),
      collectionType: collectionType,
      ruleField: SteamCollectionRuleField.fromStorage(map['rule_field']),
      ruleValue: _emptyToNull(map['rule_value'] as String?),
      includeDlcs: collectionType == SteamCollectionType.automatic
          ? _parseBool(map['include_dlcs'])
          : false,
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

  static bool _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalizedValue = value?.toString().trim().toLowerCase();

    return normalizedValue == 'true' ||
        normalizedValue == '1' ||
        normalizedValue == 'yes';
  }
}
