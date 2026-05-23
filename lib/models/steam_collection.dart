class SteamCollection {
  static const String manualSortMode = 'manual';
  static const Object _unset = Object();

  final int? id;
  final String name;
  final String? description;
  final String sortMode;
  final DateTime createdAt;

  const SteamCollection({
    this.id,
    required this.name,
    this.description,
    this.sortMode = manualSortMode,
    required this.createdAt,
  });

  factory SteamCollection.create({
    required String name,
    String? description,
    String sortMode = manualSortMode,
    DateTime Function()? now,
  }) {
    return SteamCollection(
      name: name,
      description: _emptyToNull(description),
      sortMode: sortMode,
      createdAt: (now ?? DateTime.now)(),
    );
  }

  SteamCollection copyWith({
    int? id,
    String? name,
    Object? description = _unset,
    String? sortMode,
    DateTime? createdAt,
  }) {
    return SteamCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _unset)
          ? this.description
          : _emptyToNull(description as String?),
      sortMode: sortMode ?? this.sortMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sort_mode': sortMode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SteamCollection.fromMap(Map<String, Object?> map) {
    return SteamCollection(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: _emptyToNull(map['description'] as String?),
      sortMode: (map['sort_mode'] as String?) ?? manualSortMode,
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
