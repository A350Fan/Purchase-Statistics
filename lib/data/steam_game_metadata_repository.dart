import 'package:sqflite/sqflite.dart';

import '../models/steam_game_metadata.dart';
import 'app_database.dart';

class SteamGameMetadataRepository {
  static const String metadataTable = 'steam_game_metadata';
  static const String metadataValuesTable = 'steam_game_metadata_values';

  final Future<Database> Function() _databaseProvider;
  final DateTime Function() _now;

  SteamGameMetadataRepository({
    Future<Database> Function()? databaseProvider,
    DateTime Function()? now,
  }) : _databaseProvider = databaseProvider ?? (() => AppDatabase.instance),
       _now = now ?? DateTime.now;

  Future<SteamGameMetadata?> getMetadata(int steamAppId) async {
    final db = await _databaseProvider();
    final metadataRows = await db.query(
      metadataTable,
      where: 'steam_app_id = ?',
      whereArgs: [steamAppId],
      limit: 1,
    );

    if (metadataRows.isEmpty) {
      return null;
    }

    final valueRows = await db.query(
      metadataValuesTable,
      columns: ['field', 'value'],
      where: 'steam_app_id = ?',
      whereArgs: [steamAppId],
      orderBy: 'field ASC, value ASC',
    );
    final valuesByField = <SteamMetadataField, List<String>>{
      for (final field in SteamMetadataField.values) field: <String>[],
    };

    for (final row in valueRows) {
      valuesByField[SteamMetadataField.fromStorage(row['field'])]!.add(
        row['value'] as String,
      );
    }

    return SteamGameMetadata(
      steamAppId: steamAppId,
      name: metadataRows.single['name'] as String,
      releaseDate: _parseOptionalDate(metadataRows.single['release_date']),
      releaseDateText: _nullableString(
        metadataRows.single['release_date_text'],
      ),
      genres: valuesByField[SteamMetadataField.genre]!,
      tags: valuesByField[SteamMetadataField.tag]!,
      developers: valuesByField[SteamMetadataField.developer]!,
      publishers: valuesByField[SteamMetadataField.publisher]!,
    );
  }

  Future<void> upsertMetadata(SteamGameMetadata metadata) async {
    final db = await _databaseProvider();

    await db.transaction((transaction) async {
      await transaction.insert(metadataTable, {
        'steam_app_id': metadata.steamAppId,
        'name': metadata.name,
        'release_date': metadata.releaseDate?.toIso8601String(),
        'release_date_text': _emptyToNull(metadata.releaseDateText),
        'updated_at': _now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.delete(
        metadataValuesTable,
        where: 'steam_app_id = ?',
        whereArgs: [metadata.steamAppId],
      );

      final batch = transaction.batch();
      _addValuesToBatch(
        batch,
        steamAppId: metadata.steamAppId,
        field: SteamMetadataField.genre,
        values: metadata.genres,
      );
      _addValuesToBatch(
        batch,
        steamAppId: metadata.steamAppId,
        field: SteamMetadataField.tag,
        values: metadata.tags,
      );
      _addValuesToBatch(
        batch,
        steamAppId: metadata.steamAppId,
        field: SteamMetadataField.developer,
        values: metadata.developers,
      );
      _addValuesToBatch(
        batch,
        steamAppId: metadata.steamAppId,
        field: SteamMetadataField.publisher,
        values: metadata.publishers,
      );
      await batch.commit(noResult: true);
    });
  }

  void _addValuesToBatch(
    Batch batch, {
    required int steamAppId,
    required SteamMetadataField field,
    required List<String> values,
  }) {
    final uniqueValues = <String>{};

    for (final value in values) {
      final trimmedValue = value.trim();

      if (trimmedValue.isEmpty || !uniqueValues.add(trimmedValue)) {
        continue;
      }

      batch.insert(metadataValuesTable, {
        'steam_app_id': steamAppId,
        'field': field.storageValue,
        'value': trimmedValue,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  DateTime? _parseOptionalDate(Object? value) {
    final stringValue = _nullableString(value);

    if (stringValue == null) {
      return null;
    }

    return DateTime.tryParse(stringValue);
  }

  String? _nullableString(Object? value) {
    final stringValue = value?.toString().trim();

    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  String? _emptyToNull(String? value) {
    final trimmedValue = value?.trim();

    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}
