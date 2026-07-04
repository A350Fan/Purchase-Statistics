// SPDX-License-Identifier: GPL-3.0-or-later
import '../models/steam_purchase.dart';
import '../models/steam_store_search_suggestion.dart';
import 'resource_lifecycle.dart';
import 'steam_store_search_repository.dart';
import 'steam_store_search_text.dart';

/// Vorschlag, welcher Steam-App-Eintrag zu einem Kauf passen koennte.
class SteamAppLinkCandidate {
  static const double highConfidenceThreshold = 0.94;

  final SteamPurchase purchase;
  final SteamStoreSearchSuggestion suggestion;
  final double confidence;

  const SteamAppLinkCandidate({
    required this.purchase,
    required this.suggestion,
    required this.confidence,
  });

  bool get isHighConfidence => confidence >= highConfidenceThreshold;
}

/// Sucht zu lokalen Kaeufen passende Steam-App-IDs.
///
/// Der Service nutzt die Store-Suche, bewertet Namensaehnlichkeit und liefert
/// sortierte Kandidaten, die die UI automatisch uebernehmen oder manuell
/// bestaetigen lassen kann.
class SteamAppLinkingService implements DisposableResource {
  final SteamStoreSearchSource searchSource;
  final bool _ownsSearchSource;

  SteamAppLinkingService({SteamStoreSearchSource? searchSource})
    : searchSource = searchSource ?? SteamStoreSearchRepository(),
      _ownsSearchSource = searchSource == null;

  @override
  void dispose() {
    if (!_ownsSearchSource) {
      return;
    }

    disposeResource(searchSource);
  }

  Future<List<SteamAppLinkCandidate>> findCandidates({
    required List<SteamPurchase> purchases,
    required String language,
    required String countryCode,
  }) async {
    final candidates = <SteamAppLinkCandidate>[];

    for (final purchase in purchases) {
      // Nur persistierte und noch nicht verknuepfte Kaeufe koennen automatisch
      // gelinkt werden. Nicht-Steam-Launcher werden bewusst nicht gegen den
      // Steam Store gesucht.
      if (purchase.id == null ||
          purchase.steamAppId != null ||
          !purchase.launcher.isSteam) {
        continue;
      }

      final query = _queryForPurchase(purchase);

      if (query.length < SteamStoreSearchRepository.minimumQueryLength) {
        continue;
      }

      final suggestions = await searchSource.search(
        query: query,
        purchaseType: purchase.purchaseType,
        language: language,
        countryCode: countryCode,
        associatedGameName: purchase.purchaseType == SteamPurchaseType.dlc
            ? purchase.gameName
            : null,
      );
      final candidate = _bestCandidate(purchase, suggestions);

      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    candidates.sort((a, b) {
      final confidenceCompare = b.confidence.compareTo(a.confidence);

      if (confidenceCompare != 0) {
        return confidenceCompare;
      }

      return a.purchase.displayName.toLowerCase().compareTo(
        b.purchase.displayName.toLowerCase(),
      );
    });

    return candidates;
  }

  SteamAppLinkCandidate? _bestCandidate(
    SteamPurchase purchase,
    List<SteamStoreSearchSuggestion> suggestions,
  ) {
    SteamStoreSearchSuggestion? bestSuggestion;
    var bestScore = 0.0;

    for (final suggestion in suggestions) {
      final score = _scoreSuggestion(purchase, suggestion);

      if (score > bestScore) {
        bestScore = score;
        bestSuggestion = suggestion;
      }
    }

    // Unterhalb dieser Schwelle waere die automatische Zuordnung zu riskant.
    if (bestSuggestion == null || bestScore < 0.72) {
      return null;
    }

    return SteamAppLinkCandidate(
      purchase: purchase,
      suggestion: bestSuggestion,
      confidence: bestScore.clamp(0.0, 1.0).toDouble(),
    );
  }

  double _scoreSuggestion(
    SteamPurchase purchase,
    SteamStoreSearchSuggestion suggestion,
  ) {
    final expectedNames = _expectedNamesForPurchase(purchase);
    final suggestionNames = _suggestionNamesForPurchase(purchase, suggestion);
    var score = 0.0;

    for (final expectedName in expectedNames) {
      for (final suggestionName in suggestionNames) {
        score = _max(score, _nameMatchScore(expectedName, suggestionName));
      }
    }

    // Ein klar falscher Typ (z.B. DLC statt Spiel) reduziert die Zuversicht,
    // schliesst den Treffer aber nicht komplett aus.
    if (suggestion.itemType != SteamStoreItemType.other &&
        suggestion.itemType !=
            SteamStoreItemType.fromPurchaseType(purchase.purchaseType)) {
      score -= 0.2;
    }

    return score.clamp(0.0, 1.0).toDouble();
  }

  List<String> _expectedNamesForPurchase(SteamPurchase purchase) {
    final names = <String>[purchase.gameName, purchase.displayName];

    if (purchase.purchaseType == SteamPurchaseType.dlc) {
      final dlcName = purchase.dlcName?.trim();

      if (dlcName != null && dlcName.isNotEmpty) {
        names.add(dlcName);
        names.add('${purchase.gameName}: $dlcName');
      }
    }

    return names;
  }

  List<String> _suggestionNamesForPurchase(
    SteamPurchase purchase,
    SteamStoreSearchSuggestion suggestion,
  ) {
    final names = <String>[suggestion.name];

    if (purchase.purchaseType == SteamPurchaseType.dlc) {
      names.add(
        SteamPurchase.cleanDlcNameForGame(
          gameName: purchase.gameName,
          dlcName: suggestion.name,
        ),
      );
    }

    return names;
  }

  double _nameMatchScore(String expectedName, String suggestionName) {
    final expected = _normalizeForMatching(expectedName);
    final suggestion = _normalizeForMatching(suggestionName);

    if (expected.isEmpty || suggestion.isEmpty) {
      return 0;
    }

    if (expected == suggestion) {
      return 1;
    }

    if (_compact(expected) == _compact(suggestion)) {
      return 0.97;
    }

    if (suggestion.startsWith(expected) || expected.startsWith(suggestion)) {
      return 0.9;
    }

    if (suggestion.contains(expected) || expected.contains(suggestion)) {
      return 0.82;
    }

    final expectedTokens = expected.split(' ').where((token) {
      return token.length > 1;
    }).toSet();
    final suggestionTokens = suggestion.split(' ').where((token) {
      return token.length > 1;
    }).toSet();

    if (expectedTokens.isEmpty || suggestionTokens.isEmpty) {
      return 0;
    }

    final sharedTokens = expectedTokens.intersection(suggestionTokens).length;
    final coverage = sharedTokens / expectedTokens.length;

    // Token-Coverage ist der letzte Fallback fuer Titel mit Untertiteln oder
    // Edition-Zusaetzen.
    return coverage >= 0.75 ? 0.74 : 0;
  }

  String _queryForPurchase(SteamPurchase purchase) {
    if (purchase.purchaseType == SteamPurchaseType.game) {
      return purchase.gameName.trim();
    }

    final dlcName = purchase.dlcName?.trim();

    if (dlcName != null && dlcName.isNotEmpty) {
      return dlcName;
    }

    return purchase.displayName.trim();
  }

  String _normalizeForMatching(String value) {
    return normalizeSteamStoreSearchText(value)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _compact(String value) {
    return value.replaceAll(' ', '');
  }

  double _max(double a, double b) {
    return a >= b ? a : b;
  }
}
