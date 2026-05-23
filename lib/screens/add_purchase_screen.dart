import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

class AddPurchaseScreen extends StatefulWidget {
  final SteamPurchase? initialPurchase;
  final List<SteamPurchase> existingPurchases;

  const AddPurchaseScreen({
    super.key,
    this.initialPurchase,
    this.existingPurchases = const [],
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
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _playtimeHoursController = TextEditingController();
  final _noteController = TextEditingController();
  final _gameNameFocusNode = FocusNode();
  final _dlcNameFocusNode = FocusNode();

  late final List<String> _gameNameSuggestions;
  late final List<String> _dlcNameSuggestions;

  DateTime _purchaseDate = DateTime.now();
  SteamPurchaseType _purchaseType = SteamPurchaseType.game;

  @override
  void initState() {
    super.initState();

    _gameNameSuggestions = _uniqueNames(
      widget.existingPurchases.map((purchase) => purchase.gameName),
    );
    _dlcNameSuggestions = _uniqueNames(
      widget.existingPurchases.map((purchase) => purchase.dlcName),
    );

    final initialPurchase = widget.initialPurchase;

    if (initialPurchase == null) {
      return;
    }

    _purchaseDate = initialPurchase.purchaseDate;
    _purchaseType = initialPurchase.purchaseType;
    _gameNameController.text = initialPurchase.gameName;
    _editionController.text = initialPurchase.edition ?? '';
    _dlcNameController.text = initialPurchase.dlcName ?? '';
    _priceController.text = initialPurchase.price.toStringAsFixed(2);

    if (initialPurchase.originalPrice != null) {
      _originalPriceController.text = initialPurchase.originalPrice!
          .toStringAsFixed(2);
    }

    if (initialPurchase.playtimeHours != null) {
      _playtimeHoursController.text = initialPurchase.playtimeHours!
          .toStringAsFixed(1);
    }

    if (initialPurchase.note != null) {
      _noteController.text = initialPurchase.note!;
    }
  }

  @override
  void dispose() {
    _gameNameFocusNode.dispose();
    _dlcNameFocusNode.dispose();
    _gameNameController.dispose();
    _editionController.dispose();
    _dlcNameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _playtimeHoursController.dispose();
    _noteController.dispose();
    super.dispose();
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
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Iterable<String> _matchingNameSuggestions(
    TextEditingValue textEditingValue,
    List<String> suggestions,
  ) {
    final query = _normalizeName(textEditingValue.text);

    if (query.isEmpty) {
      return const Iterable<String>.empty();
    }

    final matches = suggestions.where((suggestion) {
      return _normalizeName(suggestion).contains(query);
    }).toList();

    matches.sort((a, b) {
      final normalizedA = _normalizeName(a);
      final normalizedB = _normalizeName(b);
      final aStartsWithQuery = normalizedA.startsWith(query);
      final bStartsWithQuery = normalizedB.startsWith(query);

      if (aStartsWithQuery != bStartsWithQuery) {
        return aStartsWithQuery ? -1 : 1;
      }

      return normalizedA.compareTo(normalizedB);
    });

    return matches.take(8);
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
          ? _dlcNameController.text.trim()
          : null,
      price: _parseRequiredDouble(_priceController.text),
      originalPrice: _parseOptionalDouble(_originalPriceController.text),
      playtimeHours: _parseOptionalDouble(_playtimeHoursController.text),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    Navigator.of(context).pop(purchase);
  }

  Widget _buildNameAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required List<String> suggestions,
    required String? Function(String?) validator,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        return _matchingNameSuggestions(textEditingValue, suggestions);
      },
      onSelected: (suggestion) {
        controller.text = suggestion;
      },
      fieldViewBuilder:
          (context, textEditingController, fieldFocusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: fieldFocusNode,
              decoration: InputDecoration(
                labelText: labelText,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onFieldSubmitted(),
              validator: validator,
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final highlightedIndex = AutocompleteHighlightedOption.of(
                    context,
                  );
                  final isHighlighted = highlightedIndex == index;
                  final colorScheme = Theme.of(context).colorScheme;

                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      color: isHighlighted
                          ? colorScheme.primaryContainer
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        option,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
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

    return DefaultTabController(
      length: 2,
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
                                    setState(() {
                                      _purchaseType = selection.single;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildNameAutocompleteField(
                                  controller: _gameNameController,
                                  focusNode: _gameNameFocusNode,
                                  labelText:
                                      _purchaseType == SteamPurchaseType.dlc
                                      ? strings.associatedGame
                                      : strings.gameName,
                                  suggestions: _gameNameSuggestions,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return strings.enterGameName;
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_purchaseType == SteamPurchaseType.dlc) ...[
                                  _buildNameAutocompleteField(
                                    controller: _dlcNameController,
                                    focusNode: _dlcNameFocusNode,
                                    labelText: strings.dlcName,
                                    suggestions: _dlcNameSuggestions,
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

                                    if (parsedValue <= 0) {
                                      return strings
                                          .originalPriceMustBePositive;
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
                                  textInputAction: TextInputAction.done,
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
                                      return strings.playtimeCannotBeNegative;
                                    }

                                    return null;
                                  },
                                ),
                              ],
                            ),
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
