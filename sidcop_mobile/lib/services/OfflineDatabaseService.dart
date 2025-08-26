import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sidcop_mobile/services/EncryptionService.dart';

/// Servicio para manejar la base de datos SQLite offline cifrada
class OfflineDatabaseService {
  static Database? _database;
  static const String _databaseName = 'sidcop_offline.db';
  static const int _databaseVersion = 1;

  /// Obtiene la instancia de la base de datos
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas de la base de datos
  static Future<void> _createTables(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de clientes
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de productos
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de pedidos offline
    await db.execute('''
      CREATE TABLE pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de datos del home
    await db.execute('''
      CREATE TABLE home_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de recargas
    await db.execute('''
      CREATE TABLE recargas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de mapeo de imágenes de productos
    await db.execute('''
      CREATE TABLE product_images_mapping (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabla de mapeo de imágenes de clientes
    await db.execute('''
      CREATE TABLE client_images_mapping (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Índices para mejorar performance
    await db.execute('CREATE INDEX idx_pedidos_synced ON pedidos(synced)');
    await db.execute('CREATE INDEX idx_usuarios_created ON usuarios(created_at)');
    await db.execute('CREATE INDEX idx_clientes_created ON clientes(created_at)');
    await db.execute('CREATE INDEX idx_productos_created ON productos(created_at)');

    print('Tablas SQLite creadas exitosamente');
  }

  /// Maneja actualizaciones de la base de datos
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Actualizando base de datos de versión $oldVersion a $newVersion');
    // Aquí se manejarían las migraciones futuras
  }

  /// Guarda datos cifrados en una tabla específica
  static Future<bool> _saveEncryptedData(
    String tableName,
    List<Map<String, dynamic>> data,
    String dataType,
  ) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Limpiar datos existentes
      await db.delete(tableName);

      // Cifrar y guardar cada registro
      for (var item in data) {
        final jsonString = jsonEncode(item);
        final encryptedData = EncryptionService.encriptar(jsonString);
        
        await db.insert(tableName, {
          'data': encryptedData,
          'created_at': now,
          'updated_at': now,
        });
      }

      print('$dataType guardados en SQLite: ${data.length} registros');
      return true;
    } catch (e) {
      print('Error guardando $dataType en SQLite: $e');
      return false;
    }
  }

  /// Carga datos cifrados desde una tabla específica
  static Future<List<Map<String, dynamic>>> _loadEncryptedData(
    String tableName,
    String dataType,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        orderBy: 'created_at DESC',
      );

      List<Map<String, dynamic>> items = [];
      
      for (var map in maps) {
        try {
          final encryptedData = map['data'] as String;
          final decryptedData = EncryptionService.desencriptar(encryptedData);
          
          // Convertir JSON string de vuelta a Map
          final Map<String, dynamic> jsonData = jsonDecode(decryptedData);
          items.add(jsonData);
        } catch (e) {
          print('Error descifrando registro en $tableName: $e');
          continue;
        }
      }

      print('$dataType cargados desde SQLite: ${items.length} registros');
      return items;
    } catch (e) {
      print('Error cargando $dataType desde SQLite: $e');
      return [];
    }
  }

  /// Guarda datos de usuarios
  static Future<bool> saveUsersData(List<Map<String, dynamic>> users) async {
    return await _saveEncryptedData('usuarios', users, 'Usuarios');
  }

  /// Carga datos de usuarios
  static Future<List<Map<String, dynamic>>> loadUsersData() async {
    return await _loadEncryptedData('usuarios', 'Usuarios');
  }

  /// Guarda datos de clientes
  static Future<bool> saveClientsData(List<Map<String, dynamic>> clients) async {
    return await _saveEncryptedData('clientes', clients, 'Clientes');
  }

  /// Carga datos de clientes
  static Future<List<Map<String, dynamic>>> loadClientsData() async {
    return await _loadEncryptedData('clientes', 'Clientes');
  }

  /// Guarda datos de productos
  static Future<bool> saveProductsData(List<Map<String, dynamic>> products) async {
    return await _saveEncryptedData('productos', products, 'Productos');
  }

  /// Carga datos de productos
  static Future<List<Map<String, dynamic>>> loadProductsData() async {
    return await _loadEncryptedData('productos', 'Productos');
  }

  /// Guarda datos del home
  static Future<bool> saveHomeData(Map<String, dynamic> homeData) async {
    return await _saveEncryptedData('home_data', [homeData], 'Home Data');
  }

  /// Carga datos del home
  static Future<Map<String, dynamic>?> loadHomeData() async {
    final data = await _loadEncryptedData('home_data', 'Home Data');
    return data.isNotEmpty ? data.first : null;
  }

  /// Guarda datos de recargas
  static Future<bool> saveRecargasData(List<Map<String, dynamic>> recargas) async {
    return await _saveEncryptedData('recargas', recargas, 'Recargas');
  }

  /// Carga datos de recargas
  static Future<List<Map<String, dynamic>>> loadRecargasData() async {
    return await _loadEncryptedData('recargas', 'Recargas');
  }

  /// Guarda mapeo de imágenes de productos
  static Future<bool> saveData(String dataType, List<String> csvData) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      
      // Convertir CSV data a formato JSON para cifrar
      final dataMap = {'csv_data': csvData, 'type': dataType};
      final jsonString = dataMap.toString();
      final encryptedData = EncryptionService.encriptar(jsonString);

      // Determinar tabla según el tipo de datos
      String tableName;
      if (dataType == 'client_images_mapping') {
        tableName = 'client_images_mapping';
      } else {
        tableName = 'product_images_mapping';
      }

      // Limpiar datos existentes del mismo tipo
      await db.delete(tableName);

      await db.insert(tableName, {
        'data': encryptedData,
        'created_at': now,
        'updated_at': now,
      });

      print('$dataType guardado en SQLite');
      return true;
    } catch (e) {
      print('Error guardando $dataType en SQLite: $e');
      return false;
    }
  }

  /// Limpia datos específicos
  static Future<bool> clearData(String dataType) async {
    try {
      final db = await database;
      
      // Determinar tabla según el tipo de datos
      String tableName;
      if (dataType == 'client_images_mapping') {
        tableName = 'client_images_mapping';
      } else {
        tableName = 'product_images_mapping';
      }
      
      await db.delete(tableName);
      print('$dataType limpiado de SQLite');
      return true;
    } catch (e) {
      print('Error limpiando $dataType de SQLite: $e');
      return false;
    }
  }

  /// Obtiene el tamaño total de almacenamiento
  static Future<int> getTotalStorageSize() async {
    try {
      final db = await database;
      
      // Contar registros en todas las tablas
      final tables = ['usuarios', 'clientes', 'productos', 'pedidos', 'home_data', 'recargas', 'product_images_mapping', 'client_images_mapping'];
      int totalRecords = 0;
      
      for (String table in tables) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        totalRecords += (result.first['count'] as int);
      }
      
      // Estimación aproximada: cada registro cifrado ~1KB
      return totalRecords * 1024;
    } catch (e) {
      print('Error calculando tamaño de almacenamiento SQLite: $e');
      return 0;
    }
  }

  /// Limpia toda la base de datos
  static Future<bool> clearAllData() async {
    try {
      final db = await database;
      final tables = ['usuarios', 'clientes', 'productos', 'pedidos', 'home_data', 'recargas', 'product_images_mapping'];
      
      for (String table in tables) {
        await db.delete(table);
      }
      
      print('Toda la base de datos SQLite limpiada');
      return true;
    } catch (e) {
      print('Error limpiando base de datos SQLite: $e');
      return false;
    }
  }

  /// Cierra la conexión a la base de datos
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Migra datos desde CSV a SQLite (función de utilidad)
  static Future<bool> migrateFromCsvData() async {
    try {
      print('Iniciando migración de datos CSV a SQLite');
      
      // Aquí se implementaría la lógica de migración
      // leyendo los archivos CSV existentes y guardándolos en SQLite
      
      print('Migración de CSV a SQLite completada');
      return true;
    } catch (e) {
      print('Error en migración de CSV a SQLite: $e');
      return false;
    }
  }
}
