import 'package:flutter/material.dart';

import '../models/steam_purchase.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _gameNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _purchaseDate = DateTime.now();

  @override
  void dispose() {
    _gameNameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
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

    final purchase = SteamPurchase(
      purchaseDate: _purchaseDate,
      gameName: _gameNameController.text.trim(),
      price: _parseRequiredDouble(_priceController.text),
      originalPrice: _parseOptionalDouble(_originalPriceController.text),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kauf hinzufügen'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _gameNameController,
                        decoration: const InputDecoration(
                          labelText: 'Spielname',
                          border: OutlineInputBorder(),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte Kaufpreis eingeben';
                          }

                          final parsedValue =
                              double.tryParse(value.trim().replaceAll(',', '.'));

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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }

                          final parsedValue =
                              double.tryParse(value.trim().replaceAll(',', '.'));

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
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _savePurchase,
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
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