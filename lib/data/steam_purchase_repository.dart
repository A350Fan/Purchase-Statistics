import 'package:sqflite/sqflite.dart';

import '../models/steam_purchase.dart';
import 'app_database.dart';

class SteamPurchaseRepository {
  static const String _tableName = 'steam_purchases';

  Future<List<SteamPurchase>> getAllPurchases() async {
    final db = await AppDatabase.instance;

    final maps = await db.query(_tableName, orderBy: 'purchase_date DESC');

    return maps.map(SteamPurchase.fromMap).toList();
  }

  Future<SteamPurchase> addPurchase(SteamPurchase purchase) async {
    final db = await AppDatabase.instance;

    final id = await db.insert(
      _tableName,
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return purchase.copyWith(id: id);
  }

  Future<int> addPurchases(List<SteamPurchase> purchases) async {
    if (purchases.isEmpty) {
      return 0;
    }

    final db = await AppDatabase.instance;

    return db.transaction((transaction) async {
      for (final purchase in purchases) {
        final map = purchase.toMap();
        map['id'] = null;

        await transaction.insert(
          _tableName,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return purchases.length;
    });
  }

  Future<void> updatePurchase(SteamPurchase purchase) async {
    if (purchase.id == null) {
      throw ArgumentError('Cannot update purchase without id.');
    }

    final db = await AppDatabase.instance;

    await db.update(
      _tableName,
      purchase.toMap(),
      where: 'id = ?',
      whereArgs: [purchase.id],
    );
  }

  Future<void> deletePurchase(int id) async {
    final db = await AppDatabase.instance;

    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await AppDatabase.instance;

    await db.delete(_tableName);
  }
}
