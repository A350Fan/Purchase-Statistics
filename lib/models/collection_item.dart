/// Verknuepfung zwischen einer manuellen Sammlung und einem Kauf.
///
/// Automatische Sammlungen verwenden keine gespeicherten Items; sie berechnen
/// ihre Inhalte ueber Regeln. Dieses Modell ist also nur fuer manuelle
/// Zuordnungen gedacht.
class CollectionItem {
  static const Object _unset = Object();

  final int? id;
  final int collectionId;
  final int purchaseId;
  final int customOrder;
  final String? note;
  final DateTime createdAt;

  const CollectionItem({
    this.id,
    required this.collectionId,
    required this.purchaseId,
    this.customOrder = 0,
    this.note,
    required this.createdAt,
  });

  /// Erstellt ein neues Item mit normalisierter Notiz und aktuellem Zeitstempel.
  factory CollectionItem.create({
    required int collectionId,
    required int purchaseId,
    int customOrder = 0,
    String? note,
    DateTime Function()? now,
  }) {
    return CollectionItem(
      collectionId: collectionId,
      purchaseId: purchaseId,
      customOrder: customOrder,
      note: _emptyToNull(note),
      createdAt: (now ?? DateTime.now)(),
    );
  }

  /// Kopiert ein Item. Das `_unset`-Sentinel erlaubt, `note` gezielt auf `null`
  /// zu setzen, ohne es mit "nicht uebergeben" zu verwechseln.
  CollectionItem copyWith({
    int? id,
    int? collectionId,
    int? purchaseId,
    int? customOrder,
    Object? note = _unset,
    DateTime? createdAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      purchaseId: purchaseId ?? this.purchaseId,
      customOrder: customOrder ?? this.customOrder,
      note: identical(note, _unset) ? this.note : _emptyToNull(note as String?),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialisiert das Item in die Spaltennamen von `collection_items`.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'purchase_id': purchaseId,
      'custom_order': customOrder,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Baut ein Item aus einer Datenbankzeile.
  factory CollectionItem.fromMap(Map<String, Object?> map) {
    return CollectionItem(
      id: map['id'] as int?,
      collectionId: map['collection_id'] as int,
      purchaseId: map['purchase_id'] as int,
      customOrder: (map['custom_order'] as int?) ?? 0,
      note: _emptyToNull(map['note'] as String?),
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
