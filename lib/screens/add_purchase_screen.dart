import 'package:flutter/material.dart';

import '../models/steam_purchase.dart';

class AddPurchaseScreen extends StatefulWidget {
  final SteamPurchase? initialPurchase;

  const AddPurchaseScreen({super.key, this.initialPurchase});

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

  DateTime _purchaseDate = DateTime.now();
  SteamPurchaseType _purchaseType = SteamPurchaseType.game;

  @override
  void initState() {
    super.initState();

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

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${_purchaseDate.day.toString().padLeft(2, '0')}.'
        '${_purchaseDate.month.toString().padLeft(2, '0')}.'
        '${_purchaseDate.year}';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Kauf bearbeiten' : 'Kauf hinzufügen'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Kaufdaten'),
              Tab(icon: Icon(Icons.timer), text: 'Spielzeit'),
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
                                  segments: const [
                                    ButtonSegment(
                                      value: SteamPurchaseType.game,
                                      icon: Icon(Icons.sports_esports),
                                      label: Text('Spiel'),
                                    ),
                                    ButtonSegment(
                                      value: SteamPurchaseType.dlc,
                                      icon: Icon(Icons.extension),
                                      label: Text('DLC'),
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
                                TextFormField(
                                  controller: _gameNameController,
                                  decoration: InputDecoration(
                                    labelText:
                                        _purchaseType == SteamPurchaseType.dlc
                                        ? 'Zugehöriges Spiel'
                                        : 'Spielname',
                                    border: const OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Bitte Spielname eingeben';
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_purchaseType == SteamPurchaseType.dlc) ...[
                                  TextFormField(
                                    controller: _dlcNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'DLC-Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (_purchaseType !=
                                          SteamPurchaseType.dlc) {
                                        return null;
                                      }

                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Bitte DLC-Name eingeben';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _editionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Edition optional',
                                    border: OutlineInputBorder(),
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _pickPurchaseDate,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text('Kaufdatum: $formattedDate'),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Kaufpreis',
                                    suffixText: '€',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Bitte Kaufpreis eingeben';
                                    }

                                    final parsedValue = double.tryParse(
                                      value.trim().replaceAll(',', '.'),
                                    );

                                    if (parsedValue == null) {
                                      return 'Bitte gültige Zahl eingeben';
                                    }

                                    if (parsedValue < 0) {
                                      return 'Preis darf nicht negativ sein';
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _originalPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Originalpreis optional',
                                    suffixText: '€',
                                    border: OutlineInputBorder(),
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
                                      return 'Bitte gültige Zahl eingeben';
                                    }

                                    if (parsedValue <= 0) {
                                      return 'Originalpreis muss größer als 0 sein';
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _noteController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notiz optional',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Spielzeit optional',
                                    suffixText: 'h',
                                    border: OutlineInputBorder(),
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
                                      return 'Bitte gültige Zahl eingeben';
                                    }

                                    if (parsedValue < 0) {
                                      return 'Spielzeit darf nicht negativ sein';
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
                                  ? 'Änderungen speichern'
                                  : 'Speichern',
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
