import 'package:flutter/material.dart';

import '../data/steam_collection_repository.dart';
import '../l10n/app_strings.dart';
import '../models/collection_item.dart';
import '../models/steam_collection.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

class CollectionsTab extends StatefulWidget {
  final SteamCollectionRepository repository;
  final List<SteamPurchase> purchases;

  const CollectionsTab({
    super.key,
    required this.repository,
    required this.purchases,
  });

  @override
  State<CollectionsTab> createState() => CollectionsTabState();
}

class CollectionsTabState extends State<CollectionsTab> {
  List<SteamCollection> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void didUpdateWidget(covariant CollectionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      _loadCollections();
    }
  }

  Future<void> openCreateCollectionDialog() async {
    final strings = AppStrings.of(context);
    final collection = await showDialog<SteamCollection>(
      context: context,
      builder: (context) => const _CollectionFormDialog(),
    );

    if (collection == null) {
      return;
    }

    await widget.repository.insertCollection(collection);
    await _loadCollections(showLoading: false);
    _showSnackBar(strings.createdCollection(collection.name));
  }

  Future<void> _loadCollections({bool showLoading = true}) async {
    if (showLoading && mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final collections = await widget.repository.getCollections();

    if (!mounted) {
      return;
    }

    setState(() {
      _collections = collections;
      _isLoading = false;
    });
  }

  Future<void> _openCollectionDetail(SteamCollection collection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(
          collection: collection,
          repository: widget.repository,
          purchases: widget.purchases,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCollection(SteamCollection collection) async {
    final id = collection.id;

    if (id == null) {
      return;
    }

    final strings = AppStrings.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.deleteCollectionTitle),
          content: Text(strings.deleteCollectionMessage(collection.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await widget.repository.deleteCollection(id);
    await _loadCollections(showLoading: false);
    _showSnackBar(strings.deletedCollection(collection.name));
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeader(AppStrings strings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Text(
          strings.collectionsTab,
          style: Theme.of(context).textTheme.headlineMedium,
        );
        final createButton = FilledButton.icon(
          onPressed: openCreateCollectionDialog,
          icon: const Icon(Icons.create_new_folder),
          label: Text(strings.createCollectionTitle),
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: createButton),
            ],
          );
        }

        return Row(children: [title, const Spacer(), createButton]);
      },
    );
  }

  Widget _buildCollectionCard(SteamCollection collection) {
    final strings = AppStrings.of(context);
    final description = collection.description;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(
          collection.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: description == null
            ? null
            : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: strings.delete,
          onPressed: () => _confirmDeleteCollection(collection),
          icon: const Icon(Icons.delete),
        ),
        onTap: () => _openCollectionDetail(collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: _buildHeader(strings)),
        ),
        if (_collections.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(strings.noCollections)),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: _collections.length,
              itemBuilder: (context, index) {
                return _buildCollectionCard(_collections[index]);
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }
}

class CollectionDetailScreen extends StatefulWidget {
  final SteamCollection collection;
  final SteamCollectionRepository repository;
  final List<SteamPurchase> purchases;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.repository,
    required this.purchases,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<CollectionItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final collectionId = widget.collection.id;

    if (collectionId == null) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }

    final items = await widget.repository.getItemsForCollection(collectionId);

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _removeItem(CollectionItem item) async {
    await widget.repository.removePurchaseFromCollection(
      collectionId: item.collectionId,
      purchaseId: item.purchaseId,
    );
    await _loadItems();
  }

  Map<int, SteamPurchase> _purchasesById() {
    final purchasesById = <int, SteamPurchase>{};

    for (final purchase in widget.purchases) {
      final id = purchase.id;

      if (id != null) {
        purchasesById[id] = purchase;
      }
    }

    return purchasesById;
  }

  Widget _buildHeader(AppStrings strings) {
    final theme = Theme.of(context);
    final description = widget.collection.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.collection.name, style: theme.textTheme.headlineMedium),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(strings.purchases, style: theme.textTheme.headlineSmall),
      ],
    );
  }

  Widget _buildPurchaseCard(
    CollectionItem item,
    Map<int, SteamPurchase> purchasesById,
    AppStrings strings,
    AppCurrency currency,
  ) {
    final purchase = purchasesById[item.purchaseId];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text(
          purchase?.displayName ?? strings.missingPurchase,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: purchase == null
            ? null
            : Text(
                '${_formatDate(purchase.purchaseDate)} · '
                '${_formatCurrency(purchase.price, currency)}',
              ),
        trailing: IconButton(
          tooltip: strings.removeFromCollection,
          onPressed: () => _removeItem(item),
          icon: const Icon(Icons.link_off),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatCurrency(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final purchasesById = _purchasesById();

    return Scaffold(
      appBar: AppBar(title: Text(widget.collection.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(strings),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(child: Text(strings.noCollectionItems)),
                  )
                else
                  for (final item in _items)
                    _buildPurchaseCard(item, purchasesById, strings, currency),
                const SizedBox(height: 88),
              ],
            ),
    );
  }
}

class _CollectionFormDialog extends StatefulWidget {
  const _CollectionFormDialog();

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      SteamCollection.create(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(strings.createCollectionTitle),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: strings.collectionName,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return strings.enterCollectionName;
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: strings.collectionDescriptionOptional,
                  border: const OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: Text(strings.save),
        ),
      ],
    );
  }
}
