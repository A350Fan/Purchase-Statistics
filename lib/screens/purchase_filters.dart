// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';

enum PurchaseTypeFilterOption { all, games, dlcs }

enum PurchasePlaytimeFilterOption { all, withPlaytime, withoutPlaytime }

enum PurchaseDiscountFilterOption { all, withDiscount, withoutDiscount }

/// Alle aktiven Filter fuer die Kaufuebersicht.
///
/// Das Modell ist unveraenderlich und enthaelt die komplette Filterlogik ueber
/// `matches`, damit HomeScreen und Dialog dieselbe Bedeutung verwenden.
class PurchaseFilters {
  final PurchaseTypeFilterOption purchaseType;
  final Set<SteamGameStatus> statuses;
  final int? year;
  final double? minPrice;
  final double? maxPrice;
  final PurchasePlaytimeFilterOption playtime;
  final PurchaseDiscountFilterOption discount;

  const PurchaseFilters({
    this.purchaseType = PurchaseTypeFilterOption.all,
    this.statuses = const {},
    this.year,
    this.minPrice,
    this.maxPrice,
    this.playtime = PurchasePlaytimeFilterOption.all,
    this.discount = PurchaseDiscountFilterOption.all,
  });

  bool get hasFilters => activeCount > 0;

  /// Zaehlt Filtergruppen, nicht einzelne Statuswerte.
  int get activeCount {
    var count = 0;

    if (purchaseType != PurchaseTypeFilterOption.all) {
      count++;
    }

    if (statuses.isNotEmpty) {
      count++;
    }

    if (year != null) {
      count++;
    }

    if (minPrice != null || maxPrice != null) {
      count++;
    }

    if (playtime != PurchasePlaytimeFilterOption.all) {
      count++;
    }

    if (discount != PurchaseDiscountFilterOption.all) {
      count++;
    }

    return count;
  }

  /// Prueft, ob ein Kauf alle aktiven Filterbedingungen erfuellt.
  bool matches(SteamPurchase purchase) {
    switch (purchaseType) {
      case PurchaseTypeFilterOption.all:
        break;
      case PurchaseTypeFilterOption.games:
        if (purchase.purchaseType != SteamPurchaseType.game) {
          return false;
        }
        break;
      case PurchaseTypeFilterOption.dlcs:
        if (purchase.purchaseType != SteamPurchaseType.dlc) {
          return false;
        }
        break;
    }

    if (statuses.isNotEmpty) {
      if (purchase.purchaseType != SteamPurchaseType.game ||
          purchase.gameStatus == null ||
          !statuses.contains(purchase.gameStatus)) {
        return false;
      }
    }

    if (year != null && purchase.year != year) {
      return false;
    }

    if (minPrice != null && purchase.price < minPrice!) {
      return false;
    }

    if (maxPrice != null && purchase.price > maxPrice!) {
      return false;
    }

    final hasPlaytime = (purchase.playtimeHours ?? 0) > 0;

    switch (playtime) {
      case PurchasePlaytimeFilterOption.all:
        break;
      case PurchasePlaytimeFilterOption.withPlaytime:
        if (!hasPlaytime) {
          return false;
        }
        break;
      case PurchasePlaytimeFilterOption.withoutPlaytime:
        if (hasPlaytime) {
          return false;
        }
        break;
    }

    final hasDiscount = (purchase.discount ?? 0) > 0;

    switch (discount) {
      case PurchaseDiscountFilterOption.all:
        break;
      case PurchaseDiscountFilterOption.withDiscount:
        if (!hasDiscount) {
          return false;
        }
        break;
      case PurchaseDiscountFilterOption.withoutDiscount:
        if (hasDiscount) {
          return false;
        }
        break;
    }

    return true;
  }
}

/// Dialog zum Bearbeiten der Kauf-Filter.
class PurchaseFiltersDialog extends StatefulWidget {
  final PurchaseFilters initialFilters;
  final List<int> availableYears;
  final AppCurrency currency;

  const PurchaseFiltersDialog({
    super.key,
    required this.initialFilters,
    required this.availableYears,
    required this.currency,
  });

  @override
  State<PurchaseFiltersDialog> createState() => _PurchaseFiltersDialogState();
}

class _PurchaseFiltersDialogState extends State<PurchaseFiltersDialog> {
  final _formKey = GlobalKey<FormState>();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  late PurchaseTypeFilterOption _purchaseType;
  late Set<SteamGameStatus> _statuses;
  late int? _year;
  late PurchasePlaytimeFilterOption _playtime;
  late PurchaseDiscountFilterOption _discount;

  @override
  void initState() {
    super.initState();

    final filters = widget.initialFilters;
    _purchaseType = filters.purchaseType;
    _statuses = {...filters.statuses};
    _year = filters.year;
    _playtime = filters.playtime;
    _discount = filters.discount;
    _minPriceController.text = _formatFilterNumber(filters.minPrice);
    _maxPriceController.text = _formatFilterNumber(filters.maxPrice);
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _apply() {
    // Nur wenn Preisfelder gueltig sind, wird ein neues Filterobjekt
    // zurueckgegeben.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      PurchaseFilters(
        purchaseType: _purchaseType,
        statuses: _purchaseType == PurchaseTypeFilterOption.dlcs
            ? const {}
            : _statuses,
        year: _year,
        minPrice: _parseFilterNumber(_minPriceController.text),
        maxPrice: _parseFilterNumber(_maxPriceController.text),
        playtime: _playtime,
        discount: _discount,
      ),
    );
  }

  void _reset() {
    // Ein leeres Filterobjekt signalisiert dem HomeScreen, alle Filter zu
    // entfernen.
    Navigator.of(context).pop(const PurchaseFilters());
  }

  String _formatFilterNumber(double? value) {
    if (value == null) {
      return '';
    }

    final hasFraction = value != value.roundToDouble();

    return value.toStringAsFixed(hasFraction ? 2 : 0).replaceAll('.', ',');
  }

  double? _parseFilterNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  String? _validateMinPrice(String? value) {
    // Min/Max validieren sich gegenseitig, damit der Preisbereich logisch bleibt.
    final strings = AppStrings.of(context);
    final parsedValue = _parseFilterNumber(value ?? '');

    if ((value ?? '').trim().isNotEmpty && parsedValue == null) {
      return strings.enterValidNumber;
    }

    if (parsedValue != null && parsedValue < 0) {
      return strings.priceCannotBeNegative;
    }

    final maxPrice = _parseFilterNumber(_maxPriceController.text);

    if (parsedValue != null && maxPrice != null && parsedValue > maxPrice) {
      return strings.priceRangeInvalid;
    }

    return null;
  }

  String? _validateMaxPrice(String? value) {
    final strings = AppStrings.of(context);
    final parsedValue = _parseFilterNumber(value ?? '');

    if ((value ?? '').trim().isNotEmpty && parsedValue == null) {
      return strings.enterValidNumber;
    }

    if (parsedValue != null && parsedValue < 0) {
      return strings.priceCannotBeNegative;
    }

    final minPrice = _parseFilterNumber(_minPriceController.text);

    if (parsedValue != null && minPrice != null && minPrice > parsedValue) {
      return strings.priceRangeInvalid;
    }

    return null;
  }

  String _purchaseTypeLabel(
    PurchaseTypeFilterOption option,
    AppStrings strings,
  ) {
    return switch (option) {
      PurchaseTypeFilterOption.all => strings.allPurchaseTypes,
      PurchaseTypeFilterOption.games => strings.games,
      PurchaseTypeFilterOption.dlcs => strings.dlcs,
    };
  }

  IconData _purchaseTypeIcon(PurchaseTypeFilterOption option) {
    return switch (option) {
      PurchaseTypeFilterOption.all => Icons.all_inclusive,
      PurchaseTypeFilterOption.games => Icons.sports_esports,
      PurchaseTypeFilterOption.dlcs => Icons.extension,
    };
  }

  String _playtimeLabel(
    PurchasePlaytimeFilterOption option,
    AppStrings strings,
  ) {
    return switch (option) {
      PurchasePlaytimeFilterOption.all => strings.allPlaytime,
      PurchasePlaytimeFilterOption.withPlaytime => strings.withFilter,
      PurchasePlaytimeFilterOption.withoutPlaytime => strings.withoutFilter,
    };
  }

  IconData _playtimeIcon(PurchasePlaytimeFilterOption option) {
    return switch (option) {
      PurchasePlaytimeFilterOption.all => Icons.all_inclusive,
      PurchasePlaytimeFilterOption.withPlaytime => Icons.timer,
      PurchasePlaytimeFilterOption.withoutPlaytime => Icons.timer_off,
    };
  }

  String _discountLabel(
    PurchaseDiscountFilterOption option,
    AppStrings strings,
  ) {
    return switch (option) {
      PurchaseDiscountFilterOption.all => strings.allDiscounts,
      PurchaseDiscountFilterOption.withDiscount => strings.withFilter,
      PurchaseDiscountFilterOption.withoutDiscount => strings.withoutFilter,
    };
  }

  IconData _discountIcon(PurchaseDiscountFilterOption option) {
    return switch (option) {
      PurchaseDiscountFilterOption.all => Icons.all_inclusive,
      PurchaseDiscountFilterOption.withDiscount => Icons.percent,
      PurchaseDiscountFilterOption.withoutDiscount => Icons.money_off,
    };
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _buildChoiceChips<T>({
    required List<T> values,
    required T selectedValue,
    required String Function(T value) labelBuilder,
    required IconData Function(T value) iconBuilder,
    required ValueChanged<T> onSelected,
  }) {
    // Wiederverwendete Chip-Auswahl fuer Enum-basierte Filtergruppen.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          avatar: Icon(iconBuilder(value), size: 18),
          label: Text(labelBuilder(value)),
          selected: value == selectedValue,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final canFilterStatuses = _purchaseType != PurchaseTypeFilterOption.dlcs;

    return AlertDialog(
      title: Text(strings.purchaseFiltersTitle),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionLabel(strings.purchaseTypeFilter),
                const SizedBox(height: 8),
                _buildChoiceChips<PurchaseTypeFilterOption>(
                  values: PurchaseTypeFilterOption.values,
                  selectedValue: _purchaseType,
                  labelBuilder: (option) => _purchaseTypeLabel(option, strings),
                  iconBuilder: _purchaseTypeIcon,
                  onSelected: (option) {
                    setState(() {
                      _purchaseType = option;
                      if (_purchaseType == PurchaseTypeFilterOption.dlcs) {
                        _statuses = {};
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionLabel(strings.status),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SteamGameStatus.values.map((status) {
                    return FilterChip(
                      label: Text(strings.gameStatusLabel(status)),
                      selected: _statuses.contains(status),
                      onSelected: canFilterStatuses
                          ? (selected) {
                              setState(() {
                                if (selected) {
                                  _statuses.add(status);
                                } else {
                                  _statuses.remove(status);
                                }
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: _year,
                  decoration: InputDecoration(
                    labelText: strings.purchaseYearFilter,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(strings.allYears),
                    ),
                    for (final year in widget.availableYears)
                      DropdownMenuItem<int?>(
                        value: year,
                        child: Text(year.toString()),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _year = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionLabel(
                  '${strings.priceRange} (${widget.currency.symbol})',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minPriceController,
                        decoration: InputDecoration(
                          labelText: strings.minPrice,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateMinPrice,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxPriceController,
                        decoration: InputDecoration(
                          labelText: strings.maxPrice,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateMaxPrice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionLabel(strings.playtimeFilter),
                const SizedBox(height: 8),
                _buildChoiceChips<PurchasePlaytimeFilterOption>(
                  values: PurchasePlaytimeFilterOption.values,
                  selectedValue: _playtime,
                  labelBuilder: (option) => _playtimeLabel(option, strings),
                  iconBuilder: _playtimeIcon,
                  onSelected: (option) {
                    setState(() {
                      _playtime = option;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildSectionLabel(strings.discountFilter),
                const SizedBox(height: 8),
                _buildChoiceChips<PurchaseDiscountFilterOption>(
                  values: PurchaseDiscountFilterOption.values,
                  selectedValue: _discount,
                  labelBuilder: (option) => _discountLabel(option, strings),
                  iconBuilder: _discountIcon,
                  onSelected: (option) {
                    setState(() {
                      _discount = option;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: Text(strings.resetFilters)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.check),
          label: Text(strings.applyFilters),
        ),
      ],
    );
  }
}
