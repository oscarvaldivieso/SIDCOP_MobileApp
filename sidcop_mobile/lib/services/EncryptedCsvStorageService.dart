import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:developer' as developer;
import 'EncryptionService.dart';

/// Servicio para manejar el almacenamiento de datos en archivos CSV cifrados
class EncryptedCsvStorageService {
  static const String _usersFileName = 'usuarios.csv.enc';
  static const String _clientsFileName = 'clientes.csv.enc';
  static const String _productsFileName = 'productos.csv.enc';
  static const String _ordersFileName = 'pedidos.csv.enc';
  static const String _homeDataFileName = 'home_data.csv.enc';
  static const String _recargasFileName = 'recargas.csv.enc';

  /// Obtiene el directorio de documentos de la aplicación
  static Future<Directory> _getAppDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/sidcop_offline_encrypted');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Guarda datos en CSV cifrado
  static Future<bool> _saveEncryptedCsvData(
    String fileName,
    List<Map<String, dynamic>> data,
    String dataType,
  ) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      if (data.isEmpty) return true;

      // Obtener headers de la primera fila
      final headers = data.first.keys.toList();

      // Convertir datos a formato CSV
      List<List<dynamic>> csvData = [headers];
      for (var item in data) {
        csvData.add(
          headers.map((header) => item[header]?.toString() ?? '').toList(),
        );
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      // Encriptar el contenido CSV
      String encryptedContent = EncryptionService.encriptar(csvString);
      await file.writeAsString(encryptedContent);

      developer.log(
        '$dataType guardados en CSV cifrado: ${data.length} registros',
      );
      return true;
    } catch (e) {
      developer.log('Error guardando $dataType en CSV cifrado: $e');
      return false;
    }
  }

  /// Carga datos desde CSV cifrado
  static Future<List<Map<String, dynamic>>> _loadEncryptedCsvData(
    String fileName,
    String dataType,
  ) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      if (!await file.exists()) {
        return [];
      }

      final encryptedContent = await file.readAsString();

      // Desencriptar el contenido CSV
      final csvString = EncryptionService.desencriptar(encryptedContent);
      List<List<dynamic>> csvData = const CsvToListConverter().convert(
        csvString,
      );

      if (csvData.isEmpty) return [];

      final headers = csvData.first.map((e) => e.toString()).toList();
      List<Map<String, dynamic>> items = [];

      for (int i = 1; i < csvData.length; i++) {
        Map<String, dynamic> item = {};
        for (int j = 0; j < headers.length && j < csvData[i].length; j++) {
          item[headers[j]] = csvData[i][j];
        }
        items.add(item);
      }

      developer.log(
        '$dataType cargados desde CSV cifrado: ${items.length} registros',
      );
      return items;
    } catch (e) {
      developer.log('Error cargando $dataType desde CSV cifrado: $e');
      return [];
    }
  }

  /// Guarda datos de usuarios en CSV cifrado
  static Future<bool> saveUsersData(List<Map<String, dynamic>> users) async {
    return await _saveEncryptedCsvData(_usersFileName, users, 'Usuarios');
  }

  /// Carga datos de usuarios desde CSV cifrado
  static Future<List<Map<String, dynamic>>> loadUsersData() async {
    return await _loadEncryptedCsvData(_usersFileName, 'Usuarios');
  }

  /// Guarda datos de clientes en CSV cifrado
  static Future<bool> saveClientsData(
    List<Map<String, dynamic>> clients,
  ) async {
    return await _saveEncryptedCsvData(_clientsFileName, clients, 'Clientes');
  }

  /// Carga datos de clientes desde CSV cifrado
  static Future<List<Map<String, dynamic>>> loadClientsData() async {
    return await _loadEncryptedCsvData(_clientsFileName, 'Clientes');
  }

  /// Guarda datos de productos en CSV cifrado
  static Future<bool> saveProductsData(
    List<Map<String, dynamic>> products,
  ) async {
    return await _saveEncryptedCsvData(
      _productsFileName,
      products,
      'Productos',
    );
  }

  /// Carga datos de productos desde CSV cifrado
  static Future<List<Map<String, dynamic>>> loadProductsData() async {
    return await _loadEncryptedCsvData(_productsFileName, 'Productos');
  }

  /// Guarda datos del Home (dashboard) en CSV cifrado
  static Future<bool> saveHomeData(Map<String, dynamic> homeData) async {
    // Convertir el objeto único a lista para compatibilidad con CSV
    List<Map<String, dynamic>> homeDataList = [homeData];
    return await _saveEncryptedCsvData(
      _homeDataFileName,
      homeDataList,
      'Datos del Home',
    );
  }

  /// Carga datos del Home desde CSV cifrado
  static Future<Map<String, dynamic>?> loadHomeData() async {
    final homeDataList = await _loadEncryptedCsvData(
      _homeDataFileName,
      'Datos del Home',
    );
    return homeDataList.isNotEmpty ? homeDataList.first : null;
  }

  /// Guarda datos de recargas en CSV cifrado
  static Future<bool> saveRecargasData(
    List<Map<String, dynamic>> recargas,
  ) async {
    return await _saveEncryptedCsvData(_recargasFileName, recargas, 'Recargas');
  }

  /// Carga datos de recargas desde CSV cifrado
  static Future<List<Map<String, dynamic>>> loadRecargasData() async {
    return await _loadEncryptedCsvData(_recargasFileName, 'Recargas');
  }

  /// Guarda datos de pedidos en CSV cifrado
  static Future<bool> saveOrdersData(List<Map<String, dynamic>> orders) async {
    return await _saveEncryptedCsvData(_ordersFileName, orders, 'Pedidos');
  }

  /// Carga datos de pedidos desde CSV cifrado
  static Future<List<Map<String, dynamic>>> loadOrdersData() async {
    return await _loadEncryptedCsvData(_ordersFileName, 'Pedidos');
  }

  /// Elimina todos los archivos CSV cifrados
  static Future<bool> clearAllData() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final files = [
        File('${directory.path}/$_usersFileName'),
        File('${directory.path}/$_clientsFileName'),
        File('${directory.path}/$_productsFileName'),
        File('${directory.path}/$_ordersFileName'),
        File('${directory.path}/$_homeDataFileName'),
        File('${directory.path}/$_recargasFileName'),
      ];

      for (var file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      developer.log('Todos los archivos CSV cifrados eliminados');
      return true;
    } catch (e) {
      developer.log('Error eliminando archivos CSV cifrados: $e');
      return false;
    }
  }

  /// Obtiene el tamaño total de los archivos CSV cifrados
  static Future<int> getTotalStorageSize() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final files = await directory.list().toList();
      int totalSize = 0;

      for (var file in files) {
        if (file is File && file.path.endsWith('.csv.enc')) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      developer.log('Error calculando tamaño de almacenamiento cifrado: $e');
      return 0;
    }
  }

  /// Verifica la integridad de un archivo cifrado
  static Future<bool> verifyFileIntegrity(String fileName) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      if (!await file.exists()) return false;

      final encryptedContent = await file.readAsString();

      // Intentar desencriptar para verificar integridad
      EncryptionService.desencriptar(encryptedContent);

      developer.log(
        'Integridad del archivo $fileName verificada correctamente',
      );
      return true;
    } catch (e) {
      developer.log('Error verificando integridad del archivo $fileName: $e');
      return false;
    }
  }

  /// Obtiene información detallada de los archivos cifrados
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      Map<String, dynamic> info = {
        'total_size_bytes': 0,
        'files': {},
        'directory_path': directory.path,
      };

      final fileNames = [
        _usersFileName,
        _clientsFileName,
        _productsFileName,
        _ordersFileName,
        _homeDataFileName,
        _recargasFileName,
      ];

      for (String fileName in fileNames) {
        final file = File('${directory.path}/$fileName');
        if (await file.exists()) {
          final stat = await file.stat();
          final isValid = await verifyFileIntegrity(fileName);

          info['files'][fileName] = {
            'size_bytes': stat.size,
            'last_modified': stat.modified.toIso8601String(),
            'is_valid': isValid,
          };

          info['total_size_bytes'] += stat.size;
        }
      }

      info['total_size_mb'] = (info['total_size_bytes'] / (1024 * 1024))
          .toStringAsFixed(2);

      return info;
    } catch (e) {
      developer.log('Error obteniendo información de almacenamiento: $e');
      return {};
    }
  }

  /// Migra datos del servicio anterior (no cifrado) al nuevo servicio cifrado
  static Future<bool> migrateFromUnencryptedData() async {
    try {
      // Esta función se puede usar para migrar datos existentes
      // del CsvStorageService anterior al nuevo servicio cifrado
      developer.log('Iniciando migración de datos no cifrados a cifrados');

      // Aquí se implementaría la lógica de migración si es necesario
      // Por ahora, solo registramos que la migración está disponible

      developer.log('Migración completada (placeholder)');
      return true;
    } catch (e) {
      developer.log('Error en migración de datos: $e');
      return false;
    }
  }
}
