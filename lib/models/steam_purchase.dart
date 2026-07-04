// SPDX-License-Identifier: GPL-3.0-or-later
/// Launcher oder Spielplattform, der ein Kauf fachlich zugeordnet wird.
///
/// Presets werden mit stabilen Schluesseln gespeichert. Eigene Launcher bleiben
/// als Custom-Wert erhalten, damit CSV-Importe und Filter keine neuen
/// App-Versionen fuer jede Plattform brauchen.
class PurchaseLauncher implements Comparable<PurchaseLauncher> {
  static const steam = PurchaseLauncher._(
    storageValue: 'steam',
    label: 'Steam',
    isPreset: true,
  );
  static const epicGames = PurchaseLauncher._(
    storageValue: 'epic_games',
    label: 'Epic Games',
    isPreset: true,
  );
  static const gog = PurchaseLauncher._(
    storageValue: 'gog',
    label: 'GOG',
    isPreset: true,
  );
  static const playStation = PurchaseLauncher._(
    storageValue: 'playstation',
    label: 'PlayStation',
    isPreset: true,
  );
  static const xbox = PurchaseLauncher._(
    storageValue: 'xbox',
    label: 'Xbox',
    isPreset: true,
  );
  static const microsoftStore = PurchaseLauncher._(
    storageValue: 'microsoft_store',
    label: 'Microsoft Store',
    isPreset: true,
  );
  static const other = PurchaseLauncher._(
    storageValue: 'other',
    label: 'Other',
    isPreset: true,
  );

  static const presets = [
    steam,
    epicGames,
    gog,
    playStation,
    xbox,
    microsoftStore,
    other,
  ];

  static const _customPrefix = 'custom:';

  final String storageValue;
  final String label;
  final bool isPreset;

  const PurchaseLauncher._({
    required this.storageValue,
    required this.label,
    required this.isPreset,
  });

  factory PurchaseLauncher.custom(String label) {
    final trimmedLabel = label.trim();

    if (trimmedLabel.isEmpty) {
      return other;
    }

    final preset = _presetFromNormalizedValue(_normalize(trimmedLabel));

    if (preset != null) {
      return preset;
    }

    return PurchaseLauncher._(
      storageValue: '$_customPrefix$trimmedLabel',
      label: trimmedLabel,
      isPreset: false,
    );
  }

  static PurchaseLauncher fromStorageValue(Object? value) {
    final rawValue = value?.toString().trim();

    if (rawValue == null || rawValue.isEmpty) {
      return steam;
    }

    final lowerValue = rawValue.toLowerCase();

    if (lowerValue.startsWith(_customPrefix)) {
      return PurchaseLauncher.custom(rawValue.substring(_customPrefix.length));
    }

    final preset = _presetFromNormalizedValue(_normalize(rawValue));

    return preset ?? PurchaseLauncher.custom(rawValue);
  }

  bool get isSteam => this == steam;

  String get _comparisonKey {
    return storageValue.trim().toLowerCase();
  }

  @override
  int compareTo(PurchaseLauncher other) {
    final presetIndex = presets.indexOf(this);
    final otherPresetIndex = presets.indexOf(other);

    if (presetIndex >= 0 && otherPresetIndex >= 0) {
      return presetIndex.compareTo(otherPresetIndex);
    }

    if (presetIndex >= 0) {
      return -1;
    }

    if (otherPresetIndex >= 0) {
      return 1;
    }

    return label.toLowerCase().compareTo(other.label.toLowerCase());
  }

  @override
  bool operator ==(Object other) {
    return other is PurchaseLauncher && _comparisonKey == other._comparisonKey;
  }

  @override
  int get hashCode => _comparisonKey.hashCode;

  @override
  String toString() {
    return label;
  }

  static PurchaseLauncher? _presetFromNormalizedValue(String value) {
    return switch (value) {
      'steam' => steam,
      'epic' || 'epic_games' || 'epic_game_store' || 'egs' => epicGames,
      'gog' || 'gog_galaxy' => gog,
      'playstation' || 'play_station' || 'psn' || 'ps4' || 'ps5' => playStation,
      'xbox' || 'xbox_app' || 'xbox_store' => xbox,
      'microsoft_store' || 'ms_store' || 'windows_store' => microsoftStore,
      'other' || 'sonstiges' || 'andere' || 'custom' => other,
      _ => null,
    };
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }
}

/// Unterscheidet normale Spiele von DLCs.
///
/// Der Wert wird bewusst als String gespeichert, damit die Datenbank und CSVs
/// auch ausserhalb von Dart gut lesbar bleiben.
enum SteamPurchaseType {
  game,
  dlc;

  String get storageValue {
    return switch (this) {
      SteamPurchaseType.game => 'game',
      SteamPurchaseType.dlc => 'dlc',
    };
  }
}

/// Status, den ein gekauftes Spiel im persoenlichen Backlog haben kann.
///
/// Die Parser-Methode akzeptiert mehrere deutsche und englische Schreibweisen,
/// damit CSV-Importe und spaetere Datenmigrationen tolerant bleiben.
enum SteamGameStatus {
  open,
  active,
  paused,
  completed,
  endless,
  abandoned,
  archived;

  String get storageValue {
    return switch (this) {
      SteamGameStatus.open => 'open',
      SteamGameStatus.active => 'active',
      SteamGameStatus.paused => 'paused',
      SteamGameStatus.completed => 'completed',
      SteamGameStatus.endless => 'endless',
      SteamGameStatus.abandoned => 'abandoned',
      SteamGameStatus.archived => 'archived',
    };
  }

  static SteamGameStatus? fromStorageValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return switch (normalized) {
      'open' || 'offen' || 'backlog' || 'not_started' => SteamGameStatus.open,
      'active' ||
      'aktiv' ||
      'started' ||
      'angefangen' ||
      'in_progress' => SteamGameStatus.active,
      'paused' ||
      'pause' ||
      'pausiert' ||
      'on_hold' ||
      'on_pause' ||
      'suspended' => SteamGameStatus.paused,
      'completed' ||
      'complete' ||
      'finished' ||
      'durchgespielt' ||
      'beaten' => SteamGameStatus.completed,
      'endless' || 'endlos' || 'endless_game' => SteamGameStatus.endless,
      'abandoned' || 'abgebrochen' || 'dropped' => SteamGameStatus.abandoned,
      'archived' ||
      'archive' ||
      'archiv' ||
      'archiviert' ||
      'old' ||
      'alt' => SteamGameStatus.archived,
      _ => null,
    };
  }
}

/// Zentrales Datenmodell fuer einen Steam-Kauf.
///
/// Ein Objekt dieser Klasse repraesentiert genau eine Zeile in
/// `steam_purchases`. Die Felder enthalten sowohl Kaufdaten als auch optionale
/// Steam-Verknuepfungen, Spielzeit, Laengenschaetzungen und Notizen.
class SteamPurchase {
  final int? id;
  final DateTime purchaseDate;
  final SteamPurchaseType purchaseType;
  final String gameName;
  final String? edition;
  final String? dlcName;
  final SteamGameStatus? gameStatus;
  final PurchaseLauncher launcher;
  final int? steamAppId;
  final double price;
  final double? originalPrice;
  final double? playtimeHours;
  final double? mainStoryHours;
  final double? mainExtraHours;
  final double? completionistHours;
  final DateTime? backlogPrioritySnoozedUntil;
  final String? note;

  const SteamPurchase({
    this.id,
    required this.purchaseDate,
    this.purchaseType = SteamPurchaseType.game,
    required this.gameName,
    this.edition,
    this.dlcName,
    this.gameStatus,
    this.launcher = PurchaseLauncher.steam,
    this.steamAppId,
    required this.price,
    this.originalPrice,
    this.playtimeHours,
    this.mainStoryHours,
    this.mainExtraHours,
    this.completionistHours,
    this.backlogPrioritySnoozedUntil,
    this.note,
  });

  int get year => purchaseDate.year;

  /// Berechnet das Quartal aus dem Kaufmonat.
  int get quarter {
    return ((purchaseDate.month - 1) ~/ 3) + 1;
  }

  /// Rabatt als Anteil zwischen 0 und 1, z.B. 0.25 fuer 25 Prozent.
  ///
  /// Ohne gueltigen Originalpreis kann kein Rabatt berechnet werden.
  double? get discount {
    if (originalPrice == null || originalPrice == 0) {
      return null;
    }

    return 1 - (price / originalPrice!);
  }

  /// Anzeigename fuer Listen, Tabellen und Dialoge.
  ///
  /// Bei DLCs wird der DLC-Name hinter den Spielnamen gesetzt; wiederholte
  /// Spielpraefixe im DLC-Namen werden entfernt, damit die Anzeige nicht
  /// doppelt wirkt.
  String get displayName {
    final editionSuffix = edition == null || edition!.trim().isEmpty
        ? ''
        : ' (${edition!.trim()})';

    if (purchaseType != SteamPurchaseType.dlc) {
      return '$gameName$editionSuffix';
    }

    final dlcTitle = dlcName == null || dlcName!.trim().isEmpty
        ? 'DLC'
        : dlcName!.trim();
    final cleanedDlcTitle = cleanDlcNameForGame(
      gameName: gameName,
      dlcName: dlcTitle,
    );

    return '$gameName: $cleanedDlcTitle$editionSuffix';
  }

  /// Entfernt aus DLC-Titeln ein vorangestelltes Basisspiel, falls Steam den
  /// DLC als "Spielname: DLC-Name" liefert.
  static String cleanDlcNameForGame({
    required String gameName,
    required String dlcName,
  }) {
    final trimmedGameName = gameName.trim();
    final trimmedDlcName = dlcName.trim();

    if (trimmedGameName.isEmpty || trimmedDlcName.isEmpty) {
      return trimmedDlcName;
    }

    final gameNamePattern = trimmedGameName
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    final prefixMatch = RegExp(
      '^$gameNamePattern\\s*[:\\-\\u2013\\u2014]\\s*',
      caseSensitive: false,
    ).firstMatch(trimmedDlcName);

    if (prefixMatch == null) {
      return trimmedDlcName;
    }

    final cleanedDlcName = trimmedDlcName.substring(prefixMatch.end).trim();

    return cleanedDlcName.isEmpty ? trimmedDlcName : cleanedDlcName;
  }

  /// Erzeugt eine geaenderte Kopie, ohne das bestehende Objekt zu mutieren.
  ///
  /// Das ist in Flutter praktisch, weil UI-State leichter nachvollziehbar
  /// bleibt, wenn Datenobjekte unveraenderlich behandelt werden.
  SteamPurchase copyWith({
    int? id,
    DateTime? purchaseDate,
    SteamPurchaseType? purchaseType,
    String? gameName,
    String? edition,
    String? dlcName,
    SteamGameStatus? gameStatus,
    PurchaseLauncher? launcher,
    int? steamAppId,
    double? price,
    double? originalPrice,
    double? playtimeHours,
    double? mainStoryHours,
    double? mainExtraHours,
    double? completionistHours,
    Object? backlogPrioritySnoozedUntil = _copyWithUnset,
    String? note,
  }) {
    // Der Sentinel erlaubt es, den Snooze explizit auf null zu setzen. Die
    // vorhandenen optionalen copyWith-Felder behalten aus Kompatibilitaet ihr
    // bisheriges "null bedeutet unveraendert"-Verhalten.
    final nextBacklogPrioritySnoozedUntil =
        identical(backlogPrioritySnoozedUntil, _copyWithUnset)
        ? this.backlogPrioritySnoozedUntil
        : backlogPrioritySnoozedUntil as DateTime?;

    return SteamPurchase(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseType: purchaseType ?? this.purchaseType,
      gameName: gameName ?? this.gameName,
      edition: edition ?? this.edition,
      dlcName: dlcName ?? this.dlcName,
      gameStatus: gameStatus ?? this.gameStatus,
      launcher: launcher ?? this.launcher,
      steamAppId: steamAppId ?? this.steamAppId,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      playtimeHours: playtimeHours ?? this.playtimeHours,
      mainStoryHours: mainStoryHours ?? this.mainStoryHours,
      mainExtraHours: mainExtraHours ?? this.mainExtraHours,
      completionistHours: completionistHours ?? this.completionistHours,
      backlogPrioritySnoozedUntil: nextBacklogPrioritySnoozedUntil,
      note: note ?? this.note,
    );
  }

  /// Serialisiert das Modell in die Spaltennamen der SQLite-Tabelle.
  ///
  /// DLCs speichern keine spielbezogenen Status- oder Laengenschätzungen, weil
  /// diese Werte nur fuer Basisspiele sinnvoll sind.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'purchase_date': purchaseDate.toIso8601String(),
      'purchase_type': purchaseType.storageValue,
      'game_name': gameName,
      'edition': edition,
      'dlc_name': dlcName,
      'launcher': launcher.storageValue,
      'game_status': purchaseType == SteamPurchaseType.game
          ? gameStatus?.storageValue
          : null,
      'steam_app_id': launcher.isSteam ? steamAppId : null,
      'price': price,
      'original_price': originalPrice,
      'playtime_hours': playtimeHours,
      'main_story_hours': purchaseType == SteamPurchaseType.game
          ? mainStoryHours
          : null,
      'main_extra_hours': purchaseType == SteamPurchaseType.game
          ? mainExtraHours
          : null,
      'completionist_hours': purchaseType == SteamPurchaseType.game
          ? completionistHours
          : null,
      'backlog_priority_snoozed_until': purchaseType == SteamPurchaseType.game
          ? backlogPrioritySnoozedUntil?.toIso8601String()
          : null,
      'note': note,
    };
  }

  /// Baut ein Modell aus einer SQLite-Zeile.
  factory SteamPurchase.fromMap(Map<String, Object?> map) {
    final purchaseType = _parsePurchaseType(map['purchase_type']);
    final launcher = PurchaseLauncher.fromStorageValue(map['launcher']);

    return SteamPurchase(
      id: map['id'] as int?,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      purchaseType: purchaseType,
      gameName: map['game_name'] as String,
      edition: _nullableString(map['edition']),
      dlcName: _nullableString(map['dlc_name']),
      gameStatus: purchaseType == SteamPurchaseType.game
          ? SteamGameStatus.fromStorageValue(map['game_status'])
          : null,
      launcher: launcher,
      steamAppId: launcher.isSteam ? map['steam_app_id'] as int? : null,
      price: (map['price'] as num).toDouble(),
      originalPrice: map['original_price'] == null
          ? null
          : (map['original_price'] as num).toDouble(),
      playtimeHours: map['playtime_hours'] == null
          ? null
          : (map['playtime_hours'] as num).toDouble(),
      mainStoryHours: map['main_story_hours'] == null
          ? null
          : (map['main_story_hours'] as num).toDouble(),
      mainExtraHours: map['main_extra_hours'] == null
          ? null
          : (map['main_extra_hours'] as num).toDouble(),
      completionistHours: map['completionist_hours'] == null
          ? null
          : (map['completionist_hours'] as num).toDouble(),
      backlogPrioritySnoozedUntil: purchaseType == SteamPurchaseType.game
          ? _nullableDateTime(map['backlog_priority_snoozed_until'])
          : null,
      note: map['note'] as String?,
    );
  }

  static SteamPurchaseType _parsePurchaseType(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();

    return switch (normalized) {
      'dlc' ||
      'downloadable_content' ||
      'addon' ||
      'add_on' => SteamPurchaseType.dlc,
      _ => SteamPurchaseType.game,
    };
  }

  static String? _nullableString(Object? value) {
    final stringValue = value as String?;

    if (stringValue == null || stringValue.trim().isEmpty) {
      return null;
    }

    return stringValue;
  }

  static DateTime? _nullableDateTime(Object? value) {
    final stringValue = _nullableString(value);

    if (stringValue == null) {
      return null;
    }

    return DateTime.tryParse(stringValue);
  }
}

/// Internes Marker-Objekt fuer copyWith-Parameter, bei denen null ein echter
/// Zielwert sein kann.
enum _SteamPurchaseCopyWithSentinel { unset }

const _copyWithUnset = _SteamPurchaseCopyWithSentinel.unset;
