import '../models/steam_purchase.dart';

class SteamPurchaseCsvException implements Exception {
  final String message;

  const SteamPurchaseCsvException(this.message);

  @override
  String toString() {
    return message;
  }
}

class SteamPurchaseCsv {
  static const int maxImportBytes = 5 * 1024 * 1024;
  static const int maxImportRows = 10000;

  static const headers = [
    'purchase_date',
    'purchase_type',
    'game_status',
    'game_name',
    'edition',
    'dlc_name',
    'steam_app_id',
    'price',
    'original_price',
    'playtime_hours',
    'main_story_hours',
    'main_extra_hours',
    'completionist_hours',
    'note',
  ];

  static String encode(List<SteamPurchase> purchases) {
    final buffer = StringBuffer()..writeln(_encodeRow(headers));

    for (final purchase in purchases) {
      buffer.writeln(
        _encodeRow([
          _formatDate(purchase.purchaseDate),
          purchase.purchaseType.storageValue,
          purchase.purchaseType == SteamPurchaseType.game
              ? purchase.gameStatus?.storageValue ?? ''
              : '',
          purchase.gameName,
          purchase.edition ?? '',
          purchase.dlcName ?? '',
          purchase.steamAppId?.toString() ?? '',
          _formatDouble(purchase.price),
          _formatOptionalDouble(purchase.originalPrice),
          _formatOptionalDouble(purchase.playtimeHours),
          _formatOptionalDouble(
            purchase.purchaseType == SteamPurchaseType.game
                ? purchase.mainStoryHours
                : null,
          ),
          _formatOptionalDouble(
            purchase.purchaseType == SteamPurchaseType.game
                ? purchase.mainExtraHours
                : null,
          ),
          _formatOptionalDouble(
            purchase.purchaseType == SteamPurchaseType.game
                ? purchase.completionistHours
                : null,
          ),
          purchase.note ?? '',
        ]),
      );
    }

    return buffer.toString();
  }

  static List<SteamPurchase> decode(String source) {
    final delimiter = _detectDelimiter(source);
    final rows = _parseRows(source, delimiter)
        .where((row) => row.values.any((value) => value.trim().isNotEmpty))
        .toList();

    if (rows.isEmpty) {
      return [];
    }

    if (rows.length > maxImportRows + 1) {
      throw SteamPurchaseCsvException(
        'CSV enthält mehr als $maxImportRows Datenzeilen.',
      );
    }

    final headerIndexes = _buildHeaderIndexes(rows.first.values);
    final purchases = <SteamPurchase>[];

    for (final row in rows.skip(1)) {
      purchases.add(_decodePurchase(row, headerIndexes));
    }

    return purchases;
  }

  static String _encodeRow(List<String> values) {
    return values.map(_encodeValue).join(',');
  }

  static String _encodeValue(String value) {
    final sanitizedValue = _escapeSpreadsheetFormula(value);
    final mustQuote =
        sanitizedValue.contains(',') ||
        sanitizedValue.contains('"') ||
        sanitizedValue.contains('\n') ||
        sanitizedValue.contains('\r');

    if (!mustQuote) {
      return sanitizedValue;
    }

    return '"${sanitizedValue.replaceAll('"', '""')}"';
  }

  static String _escapeSpreadsheetFormula(String value) {
    final trimmedValue = value.trimLeft();

    if (trimmedValue.isEmpty) {
      return value;
    }

    return switch (trimmedValue[0]) {
      '=' || '+' || '-' || '@' => "'$value",
      _ => value,
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDouble(double value) {
    return value.toStringAsFixed(2);
  }

  static String _formatOptionalDouble(double? value) {
    return value == null ? '' : _formatDouble(value);
  }

  static String _detectDelimiter(String source) {
    final firstLine = source
        .split(RegExp(r'\r\n|\n|\r'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final candidates = [',', ';', '\t'];

    return candidates.reduce((best, candidate) {
      return _countDelimiter(firstLine, candidate) >
              _countDelimiter(firstLine, best)
          ? candidate
          : best;
    });
  }

  static int _countDelimiter(String line, String delimiter) {
    var count = 0;
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && char == delimiter) {
        count++;
      }
    }

    return count;
  }

  static List<_CsvRow> _parseRows(String source, String delimiter) {
    final rows = <_CsvRow>[];
    var row = <String>[];
    var value = StringBuffer();
    var inQuotes = false;
    var lineNumber = 1;
    var rowStartLineNumber = 1;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];

      if (char == '"') {
        if (inQuotes && i + 1 < source.length && source[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && char == delimiter) {
        row.add(value.toString());
        value = StringBuffer();
      } else if (!inQuotes && (char == '\n' || char == '\r')) {
        row.add(value.toString());
        rows.add(_CsvRow(row, rowStartLineNumber));
        _throwIfTooManyRows(rows.length);
        row = <String>[];
        value = StringBuffer();

        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i++;
        }

        lineNumber++;
        rowStartLineNumber = lineNumber;
      } else {
        value.write(char);

        if (inQuotes && char == '\n') {
          lineNumber++;
        }
      }
    }

    if (inQuotes) {
      throw const SteamPurchaseCsvException(
        'CSV enthält ein nicht geschlossenes Anführungszeichen.',
      );
    }

    if (value.isNotEmpty || row.isNotEmpty) {
      row.add(value.toString());
      rows.add(_CsvRow(row, rowStartLineNumber));
      _throwIfTooManyRows(rows.length);
    }

    return rows;
  }

  static void _throwIfTooManyRows(int rowCount) {
    if (rowCount <= maxImportRows + 1) {
      return;
    }

    throw SteamPurchaseCsvException(
      'CSV enthält mehr als $maxImportRows Datenzeilen.',
    );
  }

  static Map<String, int> _buildHeaderIndexes(List<String> headerValues) {
    final indexes = <String, int>{};

    for (var i = 0; i < headerValues.length; i++) {
      final key = _canonicalHeader(headerValues[i]);

      if (key != null) {
        indexes[key] = i;
      }
    }

    for (final requiredHeader in ['purchase_date', 'game_name', 'price']) {
      if (!indexes.containsKey(requiredHeader)) {
        throw SteamPurchaseCsvException('CSV-Spalte "$requiredHeader" fehlt.');
      }
    }

    return indexes;
  }

  static String? _canonicalHeader(String value) {
    final normalized = value
        .trim()
        .replaceFirst('\uFEFF', '')
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');

    switch (normalized) {
      case 'purchase_date':
      case 'date':
      case 'datum':
      case 'kaufdatum':
        return 'purchase_date';
      case 'purchase_type':
      case 'type':
      case 'typ':
      case 'art':
      case 'kaufart':
        return 'purchase_type';
      case 'game_status':
      case 'status':
      case 'spielstatus':
      case 'game_state':
      case 'state':
      case 'zustand':
        return 'game_status';
      case 'game_name':
      case 'game':
      case 'name':
      case 'spiel':
      case 'spielname':
        return 'game_name';
      case 'edition':
      case 'edition_name':
      case 'ausgabe':
      case 'version':
        return 'edition';
      case 'dlc_name':
      case 'dlc':
      case 'addon':
      case 'add_on':
      case 'erweiterung':
        return 'dlc_name';
      case 'steam_app_id':
      case 'app_id':
      case 'steamid':
      case 'steam_id':
        return 'steam_app_id';
      case 'price':
      case 'preis':
      case 'kaufpreis':
        return 'price';
      case 'original_price':
      case 'originalpreis':
      case 'listenpreis':
        return 'original_price';
      case 'playtime_hours':
      case 'hours':
      case 'spielzeit':
      case 'spielzeit_stunden':
        return 'playtime_hours';
      case 'main_story_hours':
      case 'main_story':
      case 'hauptstory':
      case 'hauptstory_stunden':
        return 'main_story_hours';
      case 'main_extra_hours':
      case 'main_extra':
      case 'hauptstory_extras':
      case 'hauptstory_extra':
      case 'extras':
        return 'main_extra_hours';
      case 'completionist_hours':
      case 'completionist':
      case 'komplett':
      case 'komplettierung':
      case 'completion':
        return 'completionist_hours';
      case 'note':
      case 'notes':
      case 'notiz':
        return 'note';
    }

    return null;
  }

  static SteamPurchase _decodePurchase(
    _CsvRow row,
    Map<String, int> headerIndexes,
  ) {
    final gameName = _requiredValue(row, headerIndexes, 'game_name');
    final dlcName = _optionalValue(row, headerIndexes, 'dlc_name').trim();
    final purchaseType = _parsePurchaseType(
      _optionalValue(row, headerIndexes, 'purchase_type'),
      row.lineNumber,
      dlcName,
    );
    final gameStatus = purchaseType == SteamPurchaseType.game
        ? _parseGameStatus(
            _optionalValue(row, headerIndexes, 'game_status'),
            row.lineNumber,
          )
        : null;
    final purchaseDate = _parseRequiredDate(
      _requiredValue(row, headerIndexes, 'purchase_date'),
      row.lineNumber,
      'purchase_date',
    );
    final price = _parseRequiredDouble(
      _requiredValue(row, headerIndexes, 'price'),
      row.lineNumber,
      'price',
    );
    final steamAppId = _parseOptionalInt(
      _optionalValue(row, headerIndexes, 'steam_app_id'),
      row.lineNumber,
      'steam_app_id',
    );
    final originalPrice = _parseOptionalDouble(
      _optionalValue(row, headerIndexes, 'original_price'),
      row.lineNumber,
      'original_price',
    );
    final playtimeHours = _parseOptionalDouble(
      _optionalValue(row, headerIndexes, 'playtime_hours'),
      row.lineNumber,
      'playtime_hours',
    );
    final mainStoryHours = _parseOptionalDouble(
      _optionalValue(row, headerIndexes, 'main_story_hours'),
      row.lineNumber,
      'main_story_hours',
    );
    final mainExtraHours = _parseOptionalDouble(
      _optionalValue(row, headerIndexes, 'main_extra_hours'),
      row.lineNumber,
      'main_extra_hours',
    );
    final completionistHours = _parseOptionalDouble(
      _optionalValue(row, headerIndexes, 'completionist_hours'),
      row.lineNumber,
      'completionist_hours',
    );
    final edition = _optionalValue(row, headerIndexes, 'edition').trim();
    final note = _optionalValue(row, headerIndexes, 'note');

    if (gameName.trim().isEmpty) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Spielname fehlt.',
      );
    }

    if (purchaseType == SteamPurchaseType.dlc && dlcName.isEmpty) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: DLC-Name fehlt.',
      );
    }

    if (price < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Preis darf nicht negativ sein.',
      );
    }

    if (originalPrice != null && originalPrice < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Originalpreis darf nicht negativ sein.',
      );
    }

    if (playtimeHours != null && playtimeHours < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Spielzeit darf nicht negativ sein.',
      );
    }

    if (mainStoryHours != null && mainStoryHours < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Hauptstory-Stunden dürfen nicht negativ sein.',
      );
    }

    if (mainExtraHours != null && mainExtraHours < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Hauptstory+Extras-Stunden dürfen nicht negativ sein.',
      );
    }

    if (completionistHours != null && completionistHours < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Komplettierungsstunden dürfen nicht negativ sein.',
      );
    }

    return SteamPurchase(
      purchaseDate: purchaseDate,
      purchaseType: purchaseType,
      gameName: gameName.trim(),
      edition: edition.isEmpty ? null : edition,
      dlcName: purchaseType == SteamPurchaseType.dlc ? dlcName : null,
      gameStatus: gameStatus,
      steamAppId: steamAppId,
      price: price,
      originalPrice: originalPrice,
      playtimeHours: playtimeHours,
      mainStoryHours: purchaseType == SteamPurchaseType.game
          ? mainStoryHours
          : null,
      mainExtraHours: purchaseType == SteamPurchaseType.game
          ? mainExtraHours
          : null,
      completionistHours: purchaseType == SteamPurchaseType.game
          ? completionistHours
          : null,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }

  static String _requiredValue(
    _CsvRow row,
    Map<String, int> headerIndexes,
    String header,
  ) {
    final value = _optionalValue(row, headerIndexes, header);

    if (value.trim().isEmpty) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Wert für "$header" fehlt.',
      );
    }

    return value;
  }

  static String _optionalValue(
    _CsvRow row,
    Map<String, int> headerIndexes,
    String header,
  ) {
    final index = headerIndexes[header];

    if (index == null || index >= row.values.length) {
      return '';
    }

    return row.values[index];
  }

  static DateTime _parseRequiredDate(
    String value,
    int lineNumber,
    String header,
  ) {
    final trimmedValue = value.trim();
    final isoDate = DateTime.tryParse(trimmedValue);

    if (isoDate != null) {
      return DateTime(isoDate.year, isoDate.month, isoDate.day);
    }

    final germanDateMatch = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(trimmedValue);

    if (germanDateMatch != null) {
      final day = int.parse(germanDateMatch.group(1)!);
      final month = int.parse(germanDateMatch.group(2)!);
      final year = int.parse(germanDateMatch.group(3)!);
      final date = DateTime(year, month, day);

      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    }

    throw SteamPurchaseCsvException(
      'Zeile $lineNumber: "$header" ist kein gültiges Datum.',
    );
  }

  static double _parseRequiredDouble(
    String value,
    int lineNumber,
    String header,
  ) {
    final parsedValue = _parseDouble(value);

    if (parsedValue == null) {
      throw SteamPurchaseCsvException(
        'Zeile $lineNumber: "$header" ist keine gültige Zahl.',
      );
    }

    return parsedValue;
  }

  static double? _parseOptionalDouble(
    String value,
    int lineNumber,
    String header,
  ) {
    if (value.trim().isEmpty) {
      return null;
    }

    return _parseRequiredDouble(value, lineNumber, header);
  }

  static double? _parseDouble(String value) {
    final compactValue = value
        .trim()
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '');

    if (compactValue.isEmpty) {
      return null;
    }

    final lastComma = compactValue.lastIndexOf(',');
    final lastDot = compactValue.lastIndexOf('.');

    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        return double.tryParse(
          compactValue.replaceAll('.', '').replaceAll(',', '.'),
        );
      }

      return double.tryParse(compactValue.replaceAll(',', ''));
    }

    if (lastComma >= 0) {
      return double.tryParse(compactValue.replaceAll(',', '.'));
    }

    return double.tryParse(compactValue);
  }

  static int? _parseOptionalInt(String value, int lineNumber, String header) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    final parsedValue = int.tryParse(trimmedValue);

    if (parsedValue == null || parsedValue <= 0) {
      throw SteamPurchaseCsvException(
        'Zeile $lineNumber: "$header" ist keine gültige positive Ganzzahl.',
      );
    }

    return parsedValue;
  }

  static SteamPurchaseType _parsePurchaseType(
    String value,
    int lineNumber,
    String dlcName,
  ) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );

    if (normalized.isEmpty) {
      return dlcName.isEmpty ? SteamPurchaseType.game : SteamPurchaseType.dlc;
    }

    switch (normalized) {
      case 'game':
      case 'spiel':
      case 'base_game':
      case 'hauptspiel':
        return SteamPurchaseType.game;
      case 'dlc':
      case 'addon':
      case 'add_on':
      case 'downloadable_content':
      case 'erweiterung':
        return SteamPurchaseType.dlc;
    }

    throw SteamPurchaseCsvException(
      'Zeile $lineNumber: "purchase_type" muss "game" oder "dlc" sein.',
    );
  }

  static SteamGameStatus? _parseGameStatus(String value, int lineNumber) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    final gameStatus = SteamGameStatus.fromStorageValue(trimmedValue);

    if (gameStatus != null) {
      return gameStatus;
    }

    throw SteamPurchaseCsvException(
      'Zeile $lineNumber: "game_status" ist kein gültiger Spielstatus.',
    );
  }
}

class _CsvRow {
  final List<String> values;
  final int lineNumber;

  const _CsvRow(this.values, this.lineNumber);
}
