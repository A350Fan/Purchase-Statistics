import 'package:flutter/material.dart';

import '../data/steam_collection_repository.dart';
import '../l10n/app_strings.dart';
import '../models/collection_item.dart';
import '../models/steam_collection.dart';
import '../models/steam_purchase.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_controller.dart';

enum _PurchaseSelectionSortOption { name, newest, oldest }

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
  Map<int, int> _collectionItemCounts = {};
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
    await _openCollectionFormDialog();
  }

  Future<void> refresh() async {
    await _loadCollections(showLoading: false);
  }

  Future<void> _openCollectionFormDialog({
    SteamCollection? initialCollection,
  }) async {
    final strings = AppStrings.of(context);
    final collection = await showDialog<SteamCollection>(
      context: context,
      builder: (context) =>
          _CollectionFormDialog(initialCollection: initialCollection),
    );

    if (collection == null) {
      return;
    }

    if (initialCollection == null) {
      await widget.repository.insertCollection(collection);
    } else {
      await widget.repository.updateCollection(collection);
    }

    await _loadCollections(showLoading: false);
    _showSnackBar(
      initialCollection == null
          ? strings.createdCollection(collection.name)
          : strings.updatedCollection(collection.name),
    );
  }

  Future<void> _loadCollections({bool showLoading = true}) async {
    if (showLoading && mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final collections = await widget.repository.getCollections();
    final itemCounts = await widget.repository.getItemCountsByCollection();

    if (!mounted) {
      return;
    }

    setState(() {
      _collections = collections;
      _collectionItemCounts = itemCounts;
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
    await _loadCollections(showLoading: false);
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
    final itemCount = _collectionItemCounts[collection.id] ?? 0;
    final subtitleParts = [strings.purchaseCount(itemCount), ?description];

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
        subtitle: Text(
          subtitleParts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: strings.edit,
              onPressed: () {
                _openCollectionFormDialog(initialCollection: collection);
              },
              icon: const Icon(Icons.edit),
            ),
            IconButton(
              tooltip: strings.delete,
              onPressed: () => _confirmDeleteCollection(collection),
              icon: const Icon(Icons.delete),
            ),
          ],
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
  late SteamCollection _collection;
  List<CollectionItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _loadItems();
  }

  Future<void> _loadItems({bool showLoading = true}) async {
    if (showLoading && mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final collectionId = _collection.id;

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

  Future<void> _openEditCollectionDialog() async {
    final strings = AppStrings.of(context);
    final collection = await showDialog<SteamCollection>(
      context: context,
      builder: (context) =>
          _CollectionFormDialog(initialCollection: _collection),
    );

    if (collection == null) {
      return;
    }

    await widget.repository.updateCollection(collection);

    if (!mounted) {
      return;
    }

    setState(() {
      _collection = collection;
    });
    _showSnackBar(strings.updatedCollection(collection.name));
  }

  Future<void> _openAddPurchaseDialog() async {
    final collectionId = _collection.id;

    if (collectionId == null) {
      return;
    }

    final strings = AppStrings.of(context);
    final purchase = await showDialog<SteamPurchase>(
      context: context,
      builder: (context) => _AddPurchaseToCollectionDialog(
        purchases: widget.purchases,
        excludedPurchaseIds: _assignedPurchaseIds(),
      ),
    );
    final purchaseId = purchase?.id;

    if (purchase == null || purchaseId == null) {
      return;
    }

    await widget.repository.addPurchaseToCollection(
      collectionId: collectionId,
      purchaseId: purchaseId,
    );
    await _loadItems(showLoading: false);
    _showSnackBar(
      strings.addedPurchaseToCollection(purchase.displayName, _collection.name),
    );
  }

  Future<void> _removeItem(CollectionItem item) async {
    final strings = AppStrings.of(context);
    final purchase = _purchasesById()[item.purchaseId];
    final purchaseName = purchase?.displayName ?? strings.missingPurchase;

    await widget.repository.removePurchaseFromCollection(
      collectionId: item.collectionId,
      purchaseId: item.purchaseId,
    );
    await _loadItems(showLoading: false);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            strings.removedPurchaseFromCollection(
              purchaseName,
              _collection.name,
            ),
          ),
          action: SnackBarAction(
            label: strings.undo,
            onPressed: () {
              _restoreRemovedItem(item);
            },
          ),
        ),
      );
  }

  Future<void> _restoreRemovedItem(CollectionItem item) async {
    await widget.repository.addPurchaseToCollection(
      collectionId: item.collectionId,
      purchaseId: item.purchaseId,
    );
    await _loadItems(showLoading: false);
  }

  Future<void> _moveItem(int index, int direction) async {
    final collectionId = _collection.id;
    final targetIndex = index + direction;

    if (collectionId == null ||
        targetIndex < 0 ||
        targetIndex >= _items.length) {
      return;
    }

    final reorderedItems = [..._items];
    final movedItem = reorderedItems.removeAt(index);
    reorderedItems.insert(targetIndex, movedItem);
    final itemIds = reorderedItems
        .map((item) => item.id)
        .whereType<int>()
        .toList();

    if (itemIds.length != reorderedItems.length) {
      return;
    }

    setState(() {
      _items = reorderedItems;
    });

    await widget.repository.updateCollectionItemOrder(
      collectionId: collectionId,
      itemIds: itemIds,
    );
    await _loadItems(showLoading: false);
  }

  Set<int> _assignedPurchaseIds() {
    return _items.map((item) => item.purchaseId).toSet();
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
    final description = _collection.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_collection.name, style: theme.textTheme.headlineMedium),
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
    int index,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: strings.moveUp,
              onPressed: index == 0 ? null : () => _moveItem(index, -1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: strings.moveDown,
              onPressed: index == _items.length - 1
                  ? null
                  : () => _moveItem(index, 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: strings.removeFromCollection,
              onPressed: () => _removeItem(item),
              icon: const Icon(Icons.link_off),
            ),
          ],
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final purchasesById = _purchasesById();

    return Scaffold(
      appBar: AppBar(
        title: Text(_collection.name),
        actions: [
          IconButton(
            tooltip: strings.edit,
            onPressed: _openEditCollectionDialog,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPurchaseDialog,
        icon: const Icon(Icons.add_link),
        label: Text(strings.addPurchaseToCollection),
      ),
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
                  for (var index = 0; index < _items.length; index++)
                    _buildPurchaseCard(
                      _items[index],
                      index,
                      purchasesById,
                      strings,
                      currency,
                    ),
                const SizedBox(height: 88),
              ],
            ),
    );
  }
}

class _AddPurchaseToCollectionDialog extends StatefulWidget {
  final List<SteamPurchase> purchases;
  final Set<int> excludedPurchaseIds;

  const _AddPurchaseToCollectionDialog({
    required this.purchases,
    required this.excludedPurchaseIds,
  });

  @override
  State<_AddPurchaseToCollectionDialog> createState() =>
      _AddPurchaseToCollectionDialogState();
}

class _AddPurchaseToCollectionDialogState
    extends State<_AddPurchaseToCollectionDialog> {
  final _searchController = TextEditingController();
  _PurchaseSelectionSortOption _sortOption = _PurchaseSelectionSortOption.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SteamPurchase> _availablePurchases() {
    final purchases = widget.purchases.where((purchase) {
      final id = purchase.id;

      return id != null && !widget.excludedPurchaseIds.contains(id);
    }).toList();

    purchases.sort(_comparePurchases);

    return purchases;
  }

  int _comparePurchases(SteamPurchase a, SteamPurchase b) {
    return switch (_sortOption) {
      _PurchaseSelectionSortOption.name =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      _PurchaseSelectionSortOption.newest => b.purchaseDate.compareTo(
        a.purchaseDate,
      ),
      _PurchaseSelectionSortOption.oldest => a.purchaseDate.compareTo(
        b.purchaseDate,
      ),
    };
  }

  List<SteamPurchase> _filteredPurchases(List<SteamPurchase> purchases) {
    final query = _normalize(_searchController.text);

    if (query.isEmpty) {
      return purchases;
    }

    return purchases.where((purchase) {
      return _normalize(purchase.displayName).contains(query) ||
          _normalize(purchase.gameName).contains(query);
    }).toList();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatCurrency(double value, AppCurrency currency) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} ${currency.symbol}';
  }

  IconData _purchaseIcon(SteamPurchase purchase) {
    return switch (purchase.purchaseType) {
      SteamPurchaseType.game => Icons.sports_esports,
      SteamPurchaseType.dlc => Icons.extension,
    };
  }

  String _sortOptionLabel(
    _PurchaseSelectionSortOption option,
    AppStrings strings,
  ) {
    return switch (option) {
      _PurchaseSelectionSortOption.name => strings.sortByName,
      _PurchaseSelectionSortOption.newest => strings.sortByNewest,
      _PurchaseSelectionSortOption.oldest => strings.sortByOldest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currency =
        AppSettingsScope.maybeOf(context)?.settings.currency ?? AppCurrency.eur;
    final availablePurchases = _availablePurchases();
    final filteredPurchases = _filteredPurchases(availablePurchases);

    return AlertDialog(
      title: Text(strings.selectPurchaseForCollection),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: strings.purchases,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.sortPurchasesBy,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<_PurchaseSelectionSortOption>(
                  value: _sortOption,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _sortOption = value;
                    });
                  },
                  items: _PurchaseSelectionSortOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(_sortOptionLabel(option, strings)),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: availablePurchases.isEmpty
                  ? Center(
                      child: Text(strings.noAvailablePurchasesForCollection),
                    )
                  : filteredPurchases.isEmpty
                  ? Center(child: Text(strings.noMatchingPurchases))
                  : ListView.builder(
                      itemCount: filteredPurchases.length,
                      itemBuilder: (context, index) {
                        final purchase = filteredPurchases[index];

                        return ListTile(
                          leading: Icon(_purchaseIcon(purchase)),
                          title: Text(
                            purchase.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDate(purchase.purchaseDate)} · '
                            '${_formatCurrency(purchase.price, currency)}',
                          ),
                          onTap: () => Navigator.of(context).pop(purchase),
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

class _CollectionFormDialog extends StatefulWidget {
  final SteamCollection? initialCollection;

  const _CollectionFormDialog({this.initialCollection});

  @override
  State<_CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<_CollectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _isEditing => widget.initialCollection != null;

  @override
  void initState() {
    super.initState();

    final initialCollection = widget.initialCollection;

    if (initialCollection == null) {
      return;
    }

    _nameController.text = initialCollection.name;
    _descriptionController.text = initialCollection.description ?? '';
  }

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

    final initialCollection = widget.initialCollection;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final collection = initialCollection == null
        ? SteamCollection.create(name: name, description: description)
        : initialCollection.copyWith(name: name, description: description);

    Navigator.of(context).pop(collection);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return AlertDialog(
      title: Text(
        _isEditing
            ? strings.editCollectionTitle
            : strings.createCollectionTitle,
      ),
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
          label: Text(_isEditing ? strings.saveChanges : strings.save),
        ),
      ],
    );
  }
}
