import 'dart:async';

import 'package:flutter/material.dart';

import '../data/steam_collection_repository.dart';
import '../data/steam_game_metadata_service.dart';
import '../data/steam_store_search_repository.dart';
import '../data/steam_store_search_text.dart';
import '../l10n/app_strings.dart';
import '../models/steam_collection.dart';
import '../models/steam_game_metadata.dart';
import '../models/steam_purchase.dart';
import '../models/steam_store_search_suggestion.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

class PurchaseEditorResult {
  final SteamPurchase purchase;
  final Set<int>? collectionIds;

  const PurchaseEditorResult({
    required this.purchase,
    required this.collectionIds,
  });
}

enum _NameSuggestionSource { local, steam }

class _NameSuggestionOption {
  final String name;
  final _NameSuggestionSource source;
  final int? steamAppId;

  const _NameSuggestionOption.local(this.name)
    : source = _NameSuggestionSource.local,
      steamAppId = null;

  const _NameSuggestionOption.steam({
    required this.name,
    required this.steamAppId,
  }) : source = _NameSuggestionSource.steam;
}

enum _NameSuggestionField { game, dlc }

class AddPurchaseScreen extends StatefulWidget {
  final SteamPurchase? initialPurchase;
  final List<SteamPurchase> existingPurchases;
  final SteamStoreSearchSource? steamSearchSource;
  final SteamCollectionRepository? collectionRepository;
  final SteamGameMetadataService? metadataService;

  const AddPurchaseScreen({
    super.key,
    this.initialPurchase,
    this.existingPurchases = const [],
    this.steamSearchSource,
    this.collectionRepository,
    this.metadataService,
  });

  bool get isEditing => initialPurchase != null;

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _gameNameController = TextEditingController();
  final _editionController = TextEditingController();
  final _dlcNameController = TextEditingController();
  final _steamAppIdController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _playtimeHoursController = TextEditingController();
  final _mainStoryHoursController = TextEditingController();
  final _mainExtraHoursController = TextEditingController();
  final _completionistHoursController = TextEditingController();
  final _noteController = TextEditingController();
  final _gameNameFocusNode = FocusNode();
  final _dlcNameFocusNode = FocusNode();
  final _gameNameLayerLink = LayerLink();
  final _dlcNameLayerLink = LayerLink();

  late final SteamStoreSearchSource _steamSearchSource;
  late final SteamGameMetadataService? _metadataService;
  late final List<String> _gameNameSuggestions;
  late final List<String> _dlcNameSuggestions;

  Timer? _gameNameSteamSearchTimer;
  Timer? _dlcNameSteamSearchTimer;
  Timer? _gameNameFocusLossTimer;
  Timer? _dlcNameFocusLossTimer;
  List<SteamStoreSearchSuggestion> _steamGameNameSuggestions = [];
  List<SteamStoreSearchSuggestion> _steamDlcNameSuggestions = [];
  int _gameNameSteamSearchGeneration = 0;
  int _dlcNameSteamSearchGeneration = 0;
  String? _lastGameNameSteamSearchKey;
  String? _lastDlcNameSteamSearchKey;
  bool _isApplyingAutocompleteSelection = false;
  OverlayEntry? _gameNameSuggestionsOverlay;
  OverlayEntry? _dlcNameSuggestionsOverlay;
  double _gameNameSuggestionsWidth = 0;
  double _dlcNameSuggestionsWidth = 0;
  int? _selectedGameSteamAppId;
  int? _selectedDlcSteamAppId;
  List<SteamCollection> _collections = [];
  Set<int> _selectedCollectionIds = {};
  bool _isLoadingCollections = false;
  SteamGameMetadata? _metadataPreview;
  bool _isMetadataPreviewLoading = false;
  int _metadataPreviewGeneration = 0;

  DateTime _purchaseDate = DateTime.now();
  SteamPurchaseType _purchaseType = SteamPurchaseType.game;
  SteamGameStatus? _gameStatus;

  bool get _canEditCollections {
    return widget.initialPurchase?.id != null &&
        widget.collectionRepository != null;
  }

  @override
  void initState() {
    super.initState();

    _steamSearchSource =
        widget.steamSearchSource ?? SteamStoreSearchRepository();
    _metadataService = widget.metadataService;
    _gameNameSuggestions = _uniqueNames(
      widget.existingPurchases.map((purchase) => purchase.gameName),
    );
    _dlcNameSuggestions = _uniqueNames(
      widget.existingPurchases.map((purchase) => purchase.dlcName),
    );

    final initialPurchase = widget.initialPurchase;

    if (initialPurchase == null) {
      _startListeningForNameChanges();
      return;
    }

    _purchaseDate = initialPurchase.purchaseDate;
    _purchaseType = initialPurchase.purchaseType;
    _gameStatus = initialPurchase.gameStatus;
    _gameNameController.text = initialPurchase.gameName;
    _editionController.text = initialPurchase.edition ?? '';
    _dlcNameController.text =
        initialPurchase.purchaseType == SteamPurchaseType.dlc
        ? SteamPurchase.cleanDlcNameForGame(
            gameName: initialPurchase.gameName,
            dlcName: initialPurchase.dlcName ?? '',
          )
        : initialPurchase.dlcName ?? '';
    if (initialPurchase.purchaseType == SteamPurchaseType.dlc) {
      _selectedDlcSteamAppId = initialPurchase.steamAppId;
    } else {
      _selectedGameSteamAppId = initialPurchase.steamAppId;
    }
    if (initialPurchase.steamAppId != null) {
      _steamAppIdController.text = initialPurchase.steamAppId!.toString();
    }
    _priceController.text = initialPurchase.price.toStringAsFixed(2);

    if (initialPurchase.originalPrice != null) {
      _originalPriceController.text = initialPurchase.originalPrice!
          .toStringAsFixed(2);
    }

    if (initialPurchase.playtimeHours != null) {
      _playtimeHoursController.text = initialPurchase.playtimeHours!
          .toStringAsFixed(1);
    }

    if (initialPurchase.mainStoryHours != null) {
      _mainStoryHoursController.text = initialPurchase.mainStoryHours!
          .toStringAsFixed(1);
    }

    if (initialPurchase.mainExtraHours != null) {
      _mainExtraHoursController.text = initialPurchase.mainExtraHours!
          .toStringAsFixed(1);
    }

    if (initialPurchase.completionistHours != null) {
      _completionistHoursController.text = initialPurchase.completionistHours!
          .toStringAsFixed(1);
    }

    if (initialPurchase.note != null) {
      _noteController.text = initialPurchase.note!;
    }

    _startListeningForNameChanges();
    _loadCollectionSelection();
    _scheduleInitialMetadataPreviewLoad();
  }

  @override
  void dispose() {
    _gameNameSteamSearchTimer?.cancel();
    _dlcNameSteamSearchTimer?.cancel();
    _gameNameFocusLossTimer?.cancel();
    _dlcNameFocusLossTimer?.cancel();
    _gameNameController.removeListener(_handleGameNameChanged);
    _dlcNameController.removeListener(_handleDlcNameChanged);
    _steamAppIdController.removeListener(_handleSteamAppIdChanged);
    _gameNameFocusNode.removeListener(_handleGameNameFocusChanged);
    _dlcNameFocusNode.removeListener(_handleDlcNameFocusChanged);
    _removeNameSuggestionsOverlay(_NameSuggestionField.game);
    _removeNameSuggestionsOverlay(_NameSuggestionField.dlc);
    _gameNameFocusNode.dispose();
    _dlcNameFocusNode.dispose();
    _gameNameController.dispose();
    _editionController.dispose();
    _dlcNameController.dispose();
    _steamAppIdController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _playtimeHoursController.dispose();
    _mainStoryHoursController.dispose();
    _mainExtraHoursController.dispose();
    _completionistHoursController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startListeningForNameChanges() {
    _gameNameController.addListener(_handleGameNameChanged);
    _dlcNameController.addListener(_handleDlcNameChanged);
    _steamAppIdController.addListener(_handleSteamAppIdChanged);
    _gameNameFocusNode.addListener(_handleGameNameFocusChanged);
    _dlcNameFocusNode.addListener(_handleDlcNameFocusChanged);
  }

  void _scheduleInitialMetadataPreviewLoad() {
    if (_metadataService == null ||
        _parseOptionalInt(_steamAppIdController.text) == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMetadataPreview();
    });
  }

  Future<void> _pickPurchaseDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2003),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _purchaseDate = pickedDate;
    });
  }

  double? _parseOptionalDouble(String value) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    return double.tryParse(trimmedValue.replaceAll(',', '.'));
  }

  double _parseRequiredDouble(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  String? _validateOptionalHours(String? value) {
    final strings = AppStrings.of(context);

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(value.trim().replaceAll(',', '.'));

    if (parsedValue == null) {
      return strings.enterValidNumber;
    }

    if (parsedValue < 0) {
      return strings.hoursCannotBeNegative;
    }

    return null;
  }

  List<String> _uniqueNames(Iterable<String?> names) {
    final namesByKey = <String, String>{};

    for (final name in names) {
      final trimmedName = name?.trim();

      if (trimmedName == null || trimmedName.isEmpty) {
        continue;
      }

      namesByKey.putIfAbsent(_normalizeName(trimmedName), () => trimmedName);
    }

    return namesByKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  String _normalizeName(String value) {
    return normalizeSteamStoreSearchText(value);
  }

  Iterable<_NameSuggestionOption> _matchingNameSuggestions(
    TextEditingValue textEditingValue,
    List<String> localSuggestions,
    List<SteamStoreSearchSuggestion> steamSuggestions,
  ) {
    final query = _normalizeName(textEditingValue.text);

    if (query.isEmpty) {
      return const Iterable<_NameSuggestionOption>.empty();
    }

    final localMatches = localSuggestions.where((suggestion) {
      return _normalizeName(suggestion).contains(query);
    }).toList();

    localMatches.sort((a, b) {
      final normalizedA = _normalizeName(a);
      final normalizedB = _normalizeName(b);
      final aStartsWithQuery = normalizedA.startsWith(query);
      final bStartsWithQuery = normalizedB.startsWith(query);

      if (aStartsWithQuery != bStartsWithQuery) {
        return aStartsWithQuery ? -1 : 1;
      }

      return normalizedA.compareTo(normalizedB);
    });

    final options = <_NameSuggestionOption>[];
    final seenNames = <String>{};

    for (final suggestion in localMatches) {
      final normalizedSuggestion = _normalizeName(suggestion);
      seenNames.add(normalizedSuggestion);
      options.add(_NameSuggestionOption.local(suggestion));
    }

    for (final suggestion in steamSuggestions) {
      final normalizedSuggestion = _normalizeName(suggestion.name);

      if (!normalizedSuggestion.contains(query) ||
          seenNames.contains(normalizedSuggestion)) {
        continue;
      }

      seenNames.add(normalizedSuggestion);
      options.add(
        _NameSuggestionOption.steam(
          name: suggestion.name,
          steamAppId: suggestion.appId,
        ),
      );
    }

    return options.take(10);
  }

  void _handleGameNameChanged() {
    if (_isApplyingAutocompleteSelection) {
      return;
    }

    _clearSteamAppIdIfAutoAssigned(_selectedGameSteamAppId);
    _selectedGameSteamAppId = null;
    _updateNameSuggestionsOverlay(_NameSuggestionField.game);
    _scheduleSteamNameSearch(_NameSuggestionField.game);

    if (_purchaseType == SteamPurchaseType.dlc) {
      _updateNameSuggestionsOverlay(_NameSuggestionField.dlc);
      _scheduleSteamNameSearch(_NameSuggestionField.dlc);
    }
  }

  void _handleDlcNameChanged() {
    if (_isApplyingAutocompleteSelection) {
      return;
    }

    _clearSteamAppIdIfAutoAssigned(_selectedDlcSteamAppId);
    _selectedDlcSteamAppId = null;
    _updateNameSuggestionsOverlay(_NameSuggestionField.dlc);
    _scheduleSteamNameSearch(_NameSuggestionField.dlc);
  }

  void _handleSteamAppIdChanged() {
    if (_metadataService == null || _isApplyingAutocompleteSelection) {
      return;
    }

    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }

      final steamAppId = _parseOptionalInt(_steamAppIdController.text);

      if (steamAppId == null) {
        _clearMetadataPreview();
        return;
      }

      _loadMetadataPreview();
    });
  }

  void _handleGameNameFocusChanged() {
    _handleNameFocusChanged(_NameSuggestionField.game);
  }

  void _handleDlcNameFocusChanged() {
    _handleNameFocusChanged(_NameSuggestionField.dlc);
  }

  void _handleNameFocusChanged(_NameSuggestionField field) {
    final focusNode = switch (field) {
      _NameSuggestionField.game => _gameNameFocusNode,
      _NameSuggestionField.dlc => _dlcNameFocusNode,
    };
    final currentTimer = switch (field) {
      _NameSuggestionField.game => _gameNameFocusLossTimer,
      _NameSuggestionField.dlc => _dlcNameFocusLossTimer,
    };

    currentTimer?.cancel();

    if (focusNode.hasFocus) {
      _updateNameSuggestionsOverlay(field);
      return;
    }

    final nextTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || focusNode.hasFocus) {
        return;
      }

      _removeNameSuggestionsOverlay(field);
    });

    switch (field) {
      case _NameSuggestionField.game:
        _gameNameFocusLossTimer = nextTimer;
      case _NameSuggestionField.dlc:
        _dlcNameFocusLossTimer = nextTimer;
    }
  }

  void _scheduleSteamNameSearch(_NameSuggestionField field) {
    final controller = switch (field) {
      _NameSuggestionField.game => _gameNameController,
      _NameSuggestionField.dlc => _dlcNameController,
    };
    final localSuggestions = switch (field) {
      _NameSuggestionField.game => _gameNameSuggestions,
      _NameSuggestionField.dlc => _dlcNameSuggestions,
    };
    final timer = switch (field) {
      _NameSuggestionField.game => _gameNameSteamSearchTimer,
      _NameSuggestionField.dlc => _dlcNameSteamSearchTimer,
    };
    final query = controller.text.trim();
    final normalizedQuery = _normalizeName(query);

    timer?.cancel();

    if (normalizedQuery.length <
            SteamStoreSearchRepository.minimumQueryLength ||
        _hasExactLocalSuggestion(normalizedQuery, localSuggestions)) {
      _clearSteamSuggestions(field);
      return;
    }

    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final language = _steamLanguage(strings);
    final countryCode = _steamCountryCode(currency);
    final associatedGameName = field == _NameSuggestionField.dlc
        ? _gameNameController.text.trim()
        : null;
    final searchKey =
        '$field|$normalizedQuery|${_normalizeName(associatedGameName ?? '')}|'
        '$language|$countryCode';
    final lastSearchKey = switch (field) {
      _NameSuggestionField.game => _lastGameNameSteamSearchKey,
      _NameSuggestionField.dlc => _lastDlcNameSteamSearchKey,
    };

    if (lastSearchKey == searchKey) {
      return;
    }

    final nextTimer = Timer(const Duration(milliseconds: 650), () {
      _loadSteamNameSuggestions(
        field: field,
        query: query,
        searchKey: searchKey,
        language: language,
        countryCode: countryCode,
        associatedGameName: associatedGameName,
      );
    });

    switch (field) {
      case _NameSuggestionField.game:
        _gameNameSteamSearchTimer = nextTimer;
      case _NameSuggestionField.dlc:
        _dlcNameSteamSearchTimer = nextTimer;
    }
  }

  bool _hasExactLocalSuggestion(
    String normalizedQuery,
    List<String> localSuggestions,
  ) {
    return localSuggestions.any(
      (suggestion) => _normalizeName(suggestion) == normalizedQuery,
    );
  }

  void _clearSteamSuggestions(_NameSuggestionField field) {
    switch (field) {
      case _NameSuggestionField.game:
        _lastGameNameSteamSearchKey = null;

        if (_steamGameNameSuggestions.isEmpty) {
          return;
        }

        setState(() {
          _steamGameNameSuggestions = [];
        });
        _updateNameSuggestionsOverlay(field);
      case _NameSuggestionField.dlc:
        _lastDlcNameSteamSearchKey = null;

        if (_steamDlcNameSuggestions.isEmpty) {
          return;
        }

        setState(() {
          _steamDlcNameSuggestions = [];
        });
        _updateNameSuggestionsOverlay(field);
    }
  }

  Future<void> _loadSteamNameSuggestions({
    required _NameSuggestionField field,
    required String query,
    required String searchKey,
    required String language,
    required String countryCode,
    required String? associatedGameName,
  }) async {
    final generation = switch (field) {
      _NameSuggestionField.game => ++_gameNameSteamSearchGeneration,
      _NameSuggestionField.dlc => ++_dlcNameSteamSearchGeneration,
    };
    final purchaseType = switch (field) {
      _NameSuggestionField.game => SteamPurchaseType.game,
      _NameSuggestionField.dlc => SteamPurchaseType.dlc,
    };

    switch (field) {
      case _NameSuggestionField.game:
        _lastGameNameSteamSearchKey = searchKey;
      case _NameSuggestionField.dlc:
        _lastDlcNameSteamSearchKey = searchKey;
    }

    final suggestions = await _steamSearchSource.search(
      query: query,
      purchaseType: purchaseType,
      language: language,
      countryCode: countryCode,
      associatedGameName: associatedGameName,
    );

    if (!mounted || !_isCurrentSteamSearch(field, generation, searchKey)) {
      return;
    }

    setState(() {
      switch (field) {
        case _NameSuggestionField.game:
          _steamGameNameSuggestions = suggestions;
        case _NameSuggestionField.dlc:
          _steamDlcNameSuggestions = suggestions;
      }
    });
    _updateNameSuggestionsOverlay(field);
  }

  void _updateNameSuggestionsOverlay(_NameSuggestionField field) {
    if (!mounted) {
      return;
    }

    final focusNode = switch (field) {
      _NameSuggestionField.game => _gameNameFocusNode,
      _NameSuggestionField.dlc => _dlcNameFocusNode,
    };
    final options = _currentNameSuggestionOptions(field);

    if (!focusNode.hasFocus || options.isEmpty) {
      _removeNameSuggestionsOverlay(field);
      return;
    }

    final currentOverlay = switch (field) {
      _NameSuggestionField.game => _gameNameSuggestionsOverlay,
      _NameSuggestionField.dlc => _dlcNameSuggestionsOverlay,
    };

    if (currentOverlay != null) {
      currentOverlay.markNeedsBuild();
      return;
    }

    final overlay = Overlay.maybeOf(context);

    if (overlay == null) {
      return;
    }

    final overlayEntry = OverlayEntry(
      builder: (context) => _buildNameSuggestionsOverlay(field),
    );

    switch (field) {
      case _NameSuggestionField.game:
        _gameNameSuggestionsOverlay = overlayEntry;
      case _NameSuggestionField.dlc:
        _dlcNameSuggestionsOverlay = overlayEntry;
    }

    overlay.insert(overlayEntry);
  }

  void _removeNameSuggestionsOverlay(_NameSuggestionField field) {
    switch (field) {
      case _NameSuggestionField.game:
        _gameNameSuggestionsOverlay?.remove();
        _gameNameSuggestionsOverlay = null;
      case _NameSuggestionField.dlc:
        _dlcNameSuggestionsOverlay?.remove();
        _dlcNameSuggestionsOverlay = null;
    }
  }

  List<_NameSuggestionOption> _currentNameSuggestionOptions(
    _NameSuggestionField field,
  ) {
    return switch (field) {
      _NameSuggestionField.game => _matchingNameSuggestions(
        _gameNameController.value,
        _gameNameSuggestions,
        _steamGameNameSuggestions,
      ).toList(growable: false),
      _NameSuggestionField.dlc => _matchingNameSuggestions(
        _dlcNameController.value,
        _dlcNameSuggestions,
        _steamDlcNameSuggestions,
      ).toList(growable: false),
    };
  }

  Widget _buildNameSuggestionsOverlay(_NameSuggestionField field) {
    final width = switch (field) {
      _NameSuggestionField.game => _gameNameSuggestionsWidth,
      _NameSuggestionField.dlc => _dlcNameSuggestionsWidth,
    };
    final layerLink = switch (field) {
      _NameSuggestionField.game => _gameNameLayerLink,
      _NameSuggestionField.dlc => _dlcNameLayerLink,
    };
    final options = _currentNameSuggestionOptions(field);

    if (width <= 0 || options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 240, maxWidth: width),
              child: SizedBox(
                width: width,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final colorScheme = Theme.of(context).colorScheme;

                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) {
                        _selectNameSuggestion(field, option);
                      },
                      child: InkWell(
                        onTap: () {
                          _selectNameSuggestion(field, option);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (option.source ==
                                  _NameSuggestionSource.steam) ...[
                                const SizedBox(width: 12),
                                Text(
                                  'Steam',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectNameSuggestion(
    _NameSuggestionField field,
    _NameSuggestionOption suggestion,
  ) {
    final controller = switch (field) {
      _NameSuggestionField.game => _gameNameController,
      _NameSuggestionField.dlc => _dlcNameController,
    };
    final selectedName = _nameForSelectedSuggestion(field, suggestion.name);

    _gameNameFocusLossTimer?.cancel();
    _dlcNameFocusLossTimer?.cancel();
    _isApplyingAutocompleteSelection = true;
    controller.value = TextEditingValue(
      text: selectedName,
      selection: TextSelection.collapsed(offset: selectedName.length),
    );
    switch (field) {
      case _NameSuggestionField.game:
        _selectedGameSteamAppId = suggestion.steamAppId;
        if (_purchaseType == SteamPurchaseType.game) {
          _setSteamAppIdFromSuggestion(suggestion.steamAppId);
        }
      case _NameSuggestionField.dlc:
        _selectedDlcSteamAppId = suggestion.steamAppId;
        if (_purchaseType == SteamPurchaseType.dlc) {
          _setSteamAppIdFromSuggestion(suggestion.steamAppId);
        }
    }
    _isApplyingAutocompleteSelection = false;
    _removeNameSuggestionsOverlay(field);
    _loadMetadataPreview(refresh: suggestion.steamAppId != null);
  }

  String _nameForSelectedSuggestion(_NameSuggestionField field, String name) {
    return switch (field) {
      _NameSuggestionField.game => name.trim(),
      _NameSuggestionField.dlc => SteamPurchase.cleanDlcNameForGame(
        gameName: _gameNameController.text,
        dlcName: name,
      ),
    };
  }

  bool _isCurrentSteamSearch(
    _NameSuggestionField field,
    int generation,
    String searchKey,
  ) {
    return switch (field) {
      _NameSuggestionField.game =>
        generation == _gameNameSteamSearchGeneration &&
            searchKey == _lastGameNameSteamSearchKey,
      _NameSuggestionField.dlc =>
        generation == _dlcNameSteamSearchGeneration &&
            searchKey == _lastDlcNameSteamSearchKey,
    };
  }

  String _steamLanguage(AppStrings strings) {
    return strings.isEnglish ? 'english' : 'german';
  }

  String _steamCountryCode(AppCurrency currency) {
    return switch (currency) {
      AppCurrency.eur => 'DE',
      AppCurrency.usd => 'US',
      AppCurrency.gbp => 'GB',
      AppCurrency.chf => 'CH',
      AppCurrency.jpy => 'JP',
    };
  }

  int? _parseOptionalInt(String value) {
    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) {
      return null;
    }

    return int.tryParse(trimmedValue);
  }

  void _setSteamAppIdFromSuggestion(int? steamAppId) {
    _steamAppIdController.text = steamAppId?.toString() ?? '';
  }

  void _clearSteamAppIdIfAutoAssigned(int? steamAppId) {
    if (steamAppId == null) {
      return;
    }

    if (_steamAppIdController.text.trim() == steamAppId.toString()) {
      _steamAppIdController.clear();
    }
  }

  void _clearMetadataPreview() {
    _metadataPreviewGeneration++;

    if (_metadataPreview == null && !_isMetadataPreviewLoading) {
      return;
    }

    setState(() {
      _metadataPreview = null;
      _isMetadataPreviewLoading = false;
    });
  }

  Future<void> _loadMetadataPreview({bool refresh = false}) async {
    final metadataService = _metadataService;
    final steamAppId = _parseOptionalInt(_steamAppIdController.text);

    if (metadataService == null || steamAppId == null) {
      _clearMetadataPreview();
      return;
    }

    final generation = ++_metadataPreviewGeneration;

    setState(() {
      _isMetadataPreviewLoading = true;
    });

    SteamGameMetadata? metadata;

    try {
      metadata = await metadataService.getMetadata(steamAppId);

      if (metadata == null && refresh) {
        if (!mounted || generation != _metadataPreviewGeneration) {
          return;
        }

        final strings = AppStrings.of(context);
        final currency =
            AppSettingsScope.maybeOf(context)?.settings.currency ??
            AppCurrency.eur;

        metadata = await metadataService.refreshMetadata(
          steamAppId: steamAppId,
          language: _steamLanguage(strings),
          countryCode: _steamCountryCode(currency),
        );
      }
    } catch (_) {
      metadata = null;
    }

    if (!mounted || generation != _metadataPreviewGeneration) {
      return;
    }

    setState(() {
      _metadataPreview = metadata;
      _isMetadataPreviewLoading = false;
    });
  }

  Future<void> _openSteamAppLinkDialog() async {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final suggestion = await showDialog<SteamStoreSearchSuggestion>(
      context: context,
      builder: (context) => _SteamAppLinkDialog(
        initialQuery: _initialSteamLinkQuery(),
        purchaseType: _purchaseType,
        associatedGameName: _purchaseType == SteamPurchaseType.dlc
            ? _gameNameController.text.trim()
            : null,
        steamSearchSource: _steamSearchSource,
        language: _steamLanguage(strings),
        countryCode: _steamCountryCode(currency),
      ),
    );

    if (suggestion == null) {
      return;
    }

    _isApplyingAutocompleteSelection = true;
    setState(() {
      switch (_purchaseType) {
        case SteamPurchaseType.game:
          _selectedGameSteamAppId = suggestion.appId;
          _gameNameController.text = suggestion.name;
        case SteamPurchaseType.dlc:
          _selectedDlcSteamAppId = suggestion.appId;
          _dlcNameController.text = SteamPurchase.cleanDlcNameForGame(
            gameName: _gameNameController.text,
            dlcName: suggestion.name,
          );
      }

      _steamAppIdController.text = suggestion.appId.toString();
    });
    _isApplyingAutocompleteSelection = false;
    _loadMetadataPreview(refresh: true);
  }

  String _initialSteamLinkQuery() {
    return switch (_purchaseType) {
      SteamPurchaseType.game => _gameNameController.text.trim(),
      SteamPurchaseType.dlc =>
        _dlcNameController.text.trim().isNotEmpty
            ? _dlcNameController.text.trim()
            : _gameNameController.text.trim(),
    };
  }

  void _savePurchase() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final initialPurchase = widget.initialPurchase;

    final purchase = SteamPurchase(
      id: initialPurchase?.id,
      purchaseDate: _purchaseDate,
      purchaseType: _purchaseType,
      gameName: _gameNameController.text.trim(),
      edition: _editionController.text.trim().isEmpty
          ? null
          : _editionController.text.trim(),
      dlcName: _purchaseType == SteamPurchaseType.dlc
          ? SteamPurchase.cleanDlcNameForGame(
              gameName: _gameNameController.text,
              dlcName: _dlcNameController.text,
            )
          : null,
      gameStatus: _purchaseType == SteamPurchaseType.game ? _gameStatus : null,
      steamAppId: _parseOptionalInt(_steamAppIdController.text),
      price: _parseRequiredDouble(_priceController.text),
      originalPrice: _parseOptionalDouble(_originalPriceController.text),
      playtimeHours: _parseOptionalDouble(_playtimeHoursController.text),
      mainStoryHours: _purchaseType == SteamPurchaseType.game
          ? _parseOptionalDouble(_mainStoryHoursController.text)
          : null,
      mainExtraHours: _purchaseType == SteamPurchaseType.game
          ? _parseOptionalDouble(_mainExtraHoursController.text)
          : null,
      completionistHours: _purchaseType == SteamPurchaseType.game
          ? _parseOptionalDouble(_completionistHoursController.text)
          : null,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    Navigator.of(context).pop(
      PurchaseEditorResult(
        purchase: purchase,
        collectionIds: _canEditCollections ? _selectedCollectionIds : null,
      ),
    );
  }

  Future<void> _loadCollectionSelection() async {
    final repository = widget.collectionRepository;
    final purchaseId = widget.initialPurchase?.id;

    if (repository == null || purchaseId == null) {
      return;
    }

    setState(() {
      _isLoadingCollections = true;
    });

    final collections = (await repository.getCollections())
        .where((collection) => collection.isManual)
        .toList();
    final selectedCollectionIds = await repository.getCollectionIdsForPurchase(
      purchaseId,
    );
    final manualCollectionIds = collections
        .map((collection) => collection.id)
        .whereType<int>()
        .toSet();

    if (!mounted) {
      return;
    }

    setState(() {
      _collections = collections;
      _selectedCollectionIds = selectedCollectionIds.intersection(
        manualCollectionIds,
      );
      _isLoadingCollections = false;
    });
  }

  Widget _buildMetadataPreview(AppStrings strings) {
    final steamAppId = _parseOptionalInt(_steamAppIdController.text);

    if (_metadataService == null || steamAppId == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metadata = _metadataPreview;
    final previewChips = metadata == null
        ? const <Widget>[]
        : [
            if (metadata.releaseDateText != null)
              Chip(
                avatar: const Icon(Icons.event, size: 16),
                label: Text(strings.releaseDate(metadata.releaseDateText!)),
                visualDensity: VisualDensity.compact,
              ),
            for (final genre in metadata.genres.take(3))
              Chip(
                avatar: const Icon(Icons.category, size: 16),
                label: Text(genre),
                visualDensity: VisualDensity.compact,
              ),
            for (final tag in metadata.tags.take(4))
              Chip(
                avatar: const Icon(Icons.sell, size: 16),
                label: Text(tag),
                visualDensity: VisualDensity.compact,
              ),
            for (final developer in metadata.developers.take(2))
              Chip(
                avatar: const Icon(Icons.code, size: 16),
                label: Text(developer),
                visualDensity: VisualDensity.compact,
              ),
          ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primary.withAlpha(14),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.outline.withAlpha(42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.metadataPreview,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isMetadataPreviewLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (metadata == null)
              Text(
                _isMetadataPreviewLoading
                    ? strings.loadingMetadata
                    : strings.noMetadataPreview,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                metadata.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (previewChips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: previewChips),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsTab(AppStrings strings) {
    if (_isLoadingCollections) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_collections.isEmpty) {
      return Center(child: Text(strings.noCollectionsForPurchase));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        final collectionId = collection.id;
        final isSelected =
            collectionId != null &&
            _selectedCollectionIds.contains(collectionId);

        return CheckboxListTile(
          value: isSelected,
          secondary: const Icon(Icons.folder),
          title: Text(
            collection.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: collection.description == null
              ? null
              : Text(
                  collection.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          onChanged: collectionId == null
              ? null
              : (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCollectionIds.add(collectionId);
                    } else {
                      _selectedCollectionIds.remove(collectionId);
                    }
                  });
                },
        );
      },
    );
  }

  Widget _buildNameAutocompleteField({
    required _NameSuggestionField field,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required String? Function(String?) validator,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (field) {
          case _NameSuggestionField.game:
            _gameNameSuggestionsWidth = constraints.maxWidth;
          case _NameSuggestionField.dlc:
            _dlcNameSuggestionsWidth = constraints.maxWidth;
        }

        final layerLink = switch (field) {
          _NameSuggestionField.game => _gameNameLayerLink,
          _NameSuggestionField.dlc => _dlcNameLayerLink,
        };

        return CompositedTransformTarget(
          link: layerLink,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onTap: () => _updateNameSuggestionsOverlay(field),
            onFieldSubmitted: (_) {
              final options = _currentNameSuggestionOptions(field);

              if (options.isNotEmpty) {
                _selectNameSuggestion(field, options.first);
              }
            },
            validator: validator,
          ),
        );
      },
    );
  }

  Widget _buildGameStatusDropdown(AppStrings strings) {
    return DropdownButtonFormField<SteamGameStatus?>(
      initialValue: _gameStatus,
      decoration: InputDecoration(
        labelText: strings.gameStatusOptional,
        border: const OutlineInputBorder(),
      ),
      hint: Text(strings.noGameStatus),
      items: [
        DropdownMenuItem<SteamGameStatus?>(
          value: null,
          child: Text(strings.noGameStatus),
        ),
        for (final status in SteamGameStatus.values)
          DropdownMenuItem<SteamGameStatus?>(
            value: status,
            child: Text(strings.gameStatusLabel(status)),
          ),
      ],
      onChanged: (value) {
        setState(() {
          _gameStatus = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final formattedDate =
        '${_purchaseDate.day.toString().padLeft(2, '0')}.'
        '${_purchaseDate.month.toString().padLeft(2, '0')}.'
        '${_purchaseDate.year}';
    final tabCount = _canEditCollections ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? strings.editPurchaseTitle
                : strings.addPurchaseTitle,
          ),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long),
                text: strings.purchaseDataTab,
              ),
              Tab(icon: const Icon(Icons.timer), text: strings.playtime),
              if (_canEditCollections)
                Tab(
                  icon: const Icon(Icons.folder),
                  text: strings.collectionsTab,
                ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                SegmentedButton<SteamPurchaseType>(
                                  segments: [
                                    ButtonSegment(
                                      value: SteamPurchaseType.game,
                                      icon: const Icon(Icons.sports_esports),
                                      label: Text(strings.game),
                                    ),
                                    ButtonSegment(
                                      value: SteamPurchaseType.dlc,
                                      icon: const Icon(Icons.extension),
                                      label: Text(strings.dlc),
                                    ),
                                  ],
                                  selected: {_purchaseType},
                                  onSelectionChanged: (selection) {
                                    final nextPurchaseType = selection.single;
                                    setState(() {
                                      _purchaseType = nextPurchaseType;
                                      _steamAppIdController.text =
                                          nextPurchaseType ==
                                              SteamPurchaseType.dlc
                                          ? _selectedDlcSteamAppId
                                                    ?.toString() ??
                                                ''
                                          : _selectedGameSteamAppId
                                                    ?.toString() ??
                                                '';
                                    });

                                    _updateNameSuggestionsOverlay(
                                      _NameSuggestionField.game,
                                    );

                                    if (_purchaseType ==
                                        SteamPurchaseType.dlc) {
                                      _updateNameSuggestionsOverlay(
                                        _NameSuggestionField.dlc,
                                      );
                                      _scheduleSteamNameSearch(
                                        _NameSuggestionField.dlc,
                                      );
                                    } else {
                                      _removeNameSuggestionsOverlay(
                                        _NameSuggestionField.dlc,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildNameAutocompleteField(
                                  field: _NameSuggestionField.game,
                                  controller: _gameNameController,
                                  focusNode: _gameNameFocusNode,
                                  labelText:
                                      _purchaseType == SteamPurchaseType.dlc
                                      ? strings.associatedGame
                                      : strings.gameName,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return strings.enterGameName;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_purchaseType ==
                                    SteamPurchaseType.game) ...[
                                  _buildGameStatusDropdown(strings),
                                  const SizedBox(height: 16),
                                ],
                                if (_purchaseType == SteamPurchaseType.dlc) ...[
                                  _buildNameAutocompleteField(
                                    field: _NameSuggestionField.dlc,
                                    controller: _dlcNameController,
                                    focusNode: _dlcNameFocusNode,
                                    labelText: strings.dlcName,
                                    validator: (value) {
                                      if (_purchaseType !=
                                          SteamPurchaseType.dlc) {
                                        return null;
                                      }

                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return strings.enterDlcName;
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _steamAppIdController,
                                  decoration: InputDecoration(
                                    labelText: strings.steamAppIdOptional,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return null;
                                    }

                                    final parsedValue = int.tryParse(
                                      value.trim(),
                                    );

                                    if (parsedValue == null ||
                                        parsedValue <= 0) {
                                      return strings.enterValidSteamAppId;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _openSteamAppLinkDialog,
                                      icon: const Icon(Icons.search),
                                      label: Text(strings.linkSteamApp),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _steamAppIdController.clear();
                                          _metadataPreview = null;
                                          _isMetadataPreviewLoading = false;

                                          if (_purchaseType ==
                                              SteamPurchaseType.dlc) {
                                            _selectedDlcSteamAppId = null;
                                          } else {
                                            _selectedGameSteamAppId = null;
                                          }
                                        });
                                      },
                                      icon: const Icon(Icons.link_off),
                                      label: Text(strings.clearSteamAppLink),
                                    ),
                                  ],
                                ),
                                if (_metadataService != null &&
                                    _parseOptionalInt(
                                          _steamAppIdController.text,
                                        ) !=
                                        null) ...[
                                  const SizedBox(height: 12),
                                  _buildMetadataPreview(strings),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _editionController,
                                  decoration: InputDecoration(
                                    labelText: strings.editionOptional,
                                    border: const OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _pickPurchaseDate,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(
                                    strings.purchaseDate(formattedDate),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _priceController,
                                  decoration: InputDecoration(
                                    labelText: strings.purchasePrice,
                                    suffixText: currency.symbol,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return strings.enterPurchasePrice;
                                    }

                                    final parsedValue = double.tryParse(
                                      value.trim().replaceAll(',', '.'),
                                    );

                                    if (parsedValue == null) {
                                      return strings.enterValidNumber;
                                    }

                                    if (parsedValue < 0) {
                                      return strings.priceCannotBeNegative;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _originalPriceController,
                                  decoration: InputDecoration(
                                    labelText: strings.originalPriceOptional,
                                    suffixText: currency.symbol,
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return null;
                                    }

                                    final parsedValue = double.tryParse(
                                      value.trim().replaceAll(',', '.'),
                                    );

                                    if (parsedValue == null) {
                                      return strings.enterValidNumber;
                                    }

                                    if (parsedValue < 0) {
                                      return strings
                                          .originalPriceCannotBeNegative;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _noteController,
                                  decoration: InputDecoration(
                                    labelText: strings.noteOptional,
                                    border: const OutlineInputBorder(),
                                  ),
                                  minLines: 2,
                                  maxLines: 4,
                                ),
                              ],
                            ),
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                TextFormField(
                                  controller: _playtimeHoursController,
                                  decoration: InputDecoration(
                                    labelText: strings.playtimeOptional,
                                    suffixText: 'h',
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  validator: _validateOptionalHours,
                                ),
                                if (_purchaseType ==
                                    SteamPurchaseType.game) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    strings.gameLengthEstimates,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _mainStoryHoursController,
                                    decoration: InputDecoration(
                                      labelText: strings.mainStoryHoursOptional,
                                      suffixText: 'h',
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    validator: _validateOptionalHours,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _mainExtraHoursController,
                                    decoration: InputDecoration(
                                      labelText: strings.mainExtraHoursOptional,
                                      suffixText: 'h',
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    validator: _validateOptionalHours,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _completionistHoursController,
                                    decoration: InputDecoration(
                                      labelText:
                                          strings.completionistHoursOptional,
                                      suffixText: 'h',
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.done,
                                    validator: _validateOptionalHours,
                                  ),
                                ],
                              ],
                            ),
                            if (_canEditCollections)
                              _buildCollectionsTab(strings),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _savePurchase,
                            icon: const Icon(Icons.save),
                            label: Text(
                              widget.isEditing
                                  ? strings.saveChanges
                                  : strings.save,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SteamAppLinkDialog extends StatefulWidget {
  final String initialQuery;
  final SteamPurchaseType purchaseType;
  final String? associatedGameName;
  final SteamStoreSearchSource steamSearchSource;
  final String language;
  final String countryCode;

  const _SteamAppLinkDialog({
    required this.initialQuery,
    required this.purchaseType,
    required this.associatedGameName,
    required this.steamSearchSource,
    required this.language,
    required this.countryCode,
  });

  @override
  State<_SteamAppLinkDialog> createState() => _SteamAppLinkDialogState();
}

class _SteamAppLinkDialogState extends State<_SteamAppLinkDialog> {
  final _queryController = TextEditingController();

  List<SteamStoreSearchSuggestion> _suggestions = [];
  bool _isSearching = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();

    if (query.length < SteamStoreSearchRepository.minimumQueryLength) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    final generation = ++_searchGeneration;

    setState(() {
      _isSearching = true;
    });

    final suggestions = await widget.steamSearchSource.search(
      query: query,
      purchaseType: widget.purchaseType,
      language: widget.language,
      countryCode: widget.countryCode,
      associatedGameName: widget.associatedGameName,
    );

    if (!mounted || generation != _searchGeneration) {
      return;
    }

    setState(() {
      _suggestions = suggestions;
      _isSearching = false;
    });
  }

  IconData _itemIcon(SteamStoreSearchSuggestion suggestion) {
    return switch (suggestion.itemType) {
      SteamStoreItemType.game => Icons.sports_esports,
      SteamStoreItemType.dlc => Icons.extension,
      SteamStoreItemType.other => Icons.apps,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(strings.searchSteamApp),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.steamSearchQuery,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(strings.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _suggestions.isEmpty
                  ? Center(child: Text(strings.noSteamResults))
                  : ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];

                        return ListTile(
                          leading: Icon(_itemIcon(suggestion)),
                          title: Text(
                            suggestion.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${strings.steamApp}: ${suggestion.appId}',
                          ),
                          onTap: () => Navigator.of(context).pop(suggestion),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
      ],
    );
  }
}
