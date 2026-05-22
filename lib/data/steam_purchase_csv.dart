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
  static const headers = [
    'purchase_date',
    'game_name',
    'price',
    'original_price',
    'playtime_hours',
    'note',
  ];

  static String encode(List<SteamPurchase> purchases) {
    final rows = [
      headers,
      for (final purchase in purchases)
        [
          _formatDate(purchase.purchaseDate),
          purchase.gameName,
          _formatDouble(purchase.price),
          _formatOptionalDouble(purchase.originalPrice),
          _formatOptionalDouble(purchase.playtimeHours),
          purchase.note ?? '',
        ],
    ];

    return '${rows.map(_encodeRow).join('\n')}\n';
  }

  static List<SteamPurchase> decode(String source) {
    final delimiter = _detectDelimiter(source);
    final rows = _parseRows(source, delimiter)
        .where((row) => row.values.any((value) => value.trim().isNotEmpty))
        .toList();

    if (rows.isEmpty) {
      return [];
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
    final mustQuote =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');

    if (!mustQuote) {
      return value;
    }

    return '"${value.replaceAll('"', '""')}"';
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
    }

    return rows;
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
      case 'game_name':
      case 'game':
      case 'name':
      case 'spiel':
      case 'spielname':
        return 'game_name';
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
    final note = _optionalValue(row, headerIndexes, 'note');

    if (gameName.trim().isEmpty) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Spielname fehlt.',
      );
    }

    if (price < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Preis darf nicht negativ sein.',
      );
    }

    if (originalPrice != null && originalPrice <= 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Originalpreis muss größer als 0 sein.',
      );
    }

    if (playtimeHours != null && playtimeHours < 0) {
      throw SteamPurchaseCsvException(
        'Zeile ${row.lineNumber}: Spielzeit darf nicht negativ sein.',
      );
    }

    return SteamPurchase(
      purchaseDate: purchaseDate,
      gameName: gameName.trim(),
      price: price,
      originalPrice: originalPrice,
      playtimeHours: playtimeHours,
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
}

class _CsvRow {
  final List<String> values;
  final int lineNumber;

  const _CsvRow(this.values, this.lineNumber);
}
