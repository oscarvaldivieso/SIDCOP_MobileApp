import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class InventoryLocalService {
  static final InventoryLocalService _instance = InventoryLocalService._internal();
  static Database? _database;

  factory InventoryLocalService() => _instance;

  InventoryLocalService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'inventory_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inventory(
        id INTEGER PRIMARY KEY,
        productId INTEGER,
        productName TEXT,
        quantity INTEGER,
        vendedorId INTEGER,
        lastUpdated TEXT,
        UNIQUE(productId, vendedorId) ON CONFLICT REPLACE
      )
    ''');
  }

  Future<void> saveInventory(List<Map<String, dynamic>> inventoryItems, int vendedorId) async {
    final db = await database;
    final batch = db.batch();
    
    for (var item in inventoryItems) {
      batch.insert('inventory', {
        'productId': item['productId'] ?? item['id'],
        'productName': item['name'] ?? item['productName'],
        'quantity': item['quantity'] ?? 0,
        'vendedorId': vendedorId,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getInventory(int vendedorId) async {
    final db = await database;
    return await db.query(
      'inventory',
      where: 'vendedorId = ?',
      whereArgs: [vendedorId],
    );
  }

  Future<void> clearInventory(int vendedorId) async {
    final db = await database;
    await db.delete(
      'inventory',
      where: 'vendedorId = ?',
      whereArgs: [vendedorId],
    );
  }
}
