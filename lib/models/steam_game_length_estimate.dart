/// Wiederverwendbare Laengenschaetzung fuer ein Spiel.
///
/// Diese Daten sind absichtlich von echten Kaeufen getrennt. Ein Eintrag in
/// dieser Tabelle bedeutet nicht, dass das Spiel gekauft wurde; er dient nur als
/// Hintergrundwert fuer den Kauf-Editor und den teilbaren CSV-Export.
class SteamGameLengthEstimate {
  final int? id;
  final String gameName;
  final int? steamAppId;
  final double? mainStoryHours;
  final double? mainExtraHours;
  final double? completionistHours;

  const SteamGameLengthEstimate({
    this.id,
    required this.gameName,
    this.steamAppId,
    this.mainStoryHours,
    this.mainExtraHours,
    this.completionistHours,
  });

  bool get hasAnyEstimate {
    return mainStoryHours != null ||
        mainExtraHours != null ||
        completionistHours != null;
  }

  factory SteamGameLengthEstimate.fromMap(Map<String, Object?> map) {
    return SteamGameLengthEstimate(
      id: map['id'] as int?,
      gameName: map['game_name'] as String,
      steamAppId: map['steam_app_id'] as int?,
      mainStoryHours: _nullableDouble(map['main_story_hours']),
      mainExtraHours: _nullableDouble(map['main_extra_hours']),
      completionistHours: _nullableDouble(map['completionist_hours']),
    );
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) {
      return null;
    }

    return (value as num).toDouble();
  }
}
