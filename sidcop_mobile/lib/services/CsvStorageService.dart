import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:developer' as developer;
import 'EncryptionService.dart';

/// Servicio para manejar el almacenamiento de datos en archivos CSV
class CsvStorageService {
  static const String _usersFileName = 'usuarios.csv.enc';
  static const String _clientsFileName = 'clientes.csv.enc';
  static const String _productsFileName = 'productos.csv.enc';
  static const String _ordersFileName = 'pedidos.csv.enc';
  
  /// Obtiene el directorio de documentos de la aplicación
  static Future<Directory> _getAppDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/sidcop_offline');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }
  
  /// Guarda datos de usuarios en CSV
  static Future<bool> saveUsersData(List<Map<String, dynamic>> users) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_usersFileName');
      
      if (users.isEmpty) return true;
      
      // Obtener headers de la primera fila
      final headers = users.first.keys.toList();
      
      // Convertir datos a formato CSV
      List<List<dynamic>> csvData = [headers];
      for (var user in users) {
        csvData.add(headers.map((header) => user[header]?.toString() ?? '').toList());
      }
      
      String csvString = const ListToCsvConverter().convert(csvData);
      
      // Encriptar el contenido CSV
      String encryptedContent = EncryptionService.encriptar(csvString);
      await file.writeAsString(encryptedContent);
      
      developer.log('Usuarios guardados en CSV cifrado: ${users.length} registros');
      return true;
    } catch (e) {
      developer.log('Error guardando usuarios en CSV: $e');
      return false;
    }
  }
  
  /// Carga datos de usuarios desde CSV
  static Future<List<Map<String, dynamic>>> loadUsersData() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_usersFileName');
      
      if (!await file.exists()) {
        return [];
      }
      
      final csvString = await file.readAsString();
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty) return [];
      
      final headers = csvData.first.map((e) => e.toString()).toList();
      List<Map<String, dynamic>> users = [];
      
      for (int i = 1; i < csvData.length; i++) {
        Map<String, dynamic> user = {};
        for (int j = 0; j < headers.length && j < csvData[i].length; j++) {
          user[headers[j]] = csvData[i][j];
        }
        users.add(user);
      }
      
      developer.log('Usuarios cargados desde CSV: ${users.length} registros');
      return users;
    } catch (e) {
      developer.log('Error cargando usuarios desde CSV: $e');
      return [];
    }
  }
  
  /// Guarda datos de clientes en CSV
  static Future<bool> saveClientsData(List<Map<String, dynamic>> clients) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_clientsFileName');
      
      if (clients.isEmpty) return true;
      
      final headers = clients.first.keys.toList();
      List<List<dynamic>> csvData = [headers];
      
      for (var client in clients) {
        csvData.add(headers.map((header) => client[header]?.toString() ?? '').toList());
      }
      
      String csvString = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csvString);
      
      developer.log('Clientes guardados en CSV: ${clients.length} registros');
      return true;
    } catch (e) {
      developer.log('Error guardando clientes en CSV: $e');
      return false;
    }
  }
  
  /// Carga datos de clientes desde CSV
  static Future<List<Map<String, dynamic>>> loadClientsData() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_clientsFileName');
      
      if (!await file.exists()) return [];
      
      final csvString = await file.readAsString();
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty) return [];
      
      final headers = csvData.first.map((e) => e.toString()).toList();
      List<Map<String, dynamic>> clients = [];
      
      for (int i = 1; i < csvData.length; i++) {
        Map<String, dynamic> client = {};
        for (int j = 0; j < headers.length && j < csvData[i].length; j++) {
          client[headers[j]] = csvData[i][j];
        }
        clients.add(client);
      }
      
      developer.log('Clientes cargados desde CSV: ${clients.length} registros');
      return clients;
    } catch (e) {
      developer.log('Error cargando clientes desde CSV: $e');
      return [];
    }
  }
  
  /// Guarda datos de productos en CSV
  static Future<bool> saveProductsData(List<Map<String, dynamic>> products) async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_productsFileName');
      
      if (products.isEmpty) return true;
      
      final headers = products.first.keys.toList();
      List<List<dynamic>> csvData = [headers];
      
      for (var product in products) {
        csvData.add(headers.map((header) => product[header]?.toString() ?? '').toList());
      }
      
      String csvString = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csvString);
      
      developer.log('Productos guardados en CSV: ${products.length} registros');
      return true;
    } catch (e) {
      developer.log('Error guardando productos en CSV: $e');
      return false;
    }
  }
  
  /// Carga datos de productos desde CSV
  static Future<List<Map<String, dynamic>>> loadProductsData() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final file = File('${directory.path}/$_productsFileName');
      
      if (!await file.exists()) return [];
      
      final csvString = await file.readAsString();
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty) return [];
      
      final headers = csvData.first.map((e) => e.toString()).toList();
      List<Map<String, dynamic>> products = [];
      
      for (int i = 1; i < csvData.length; i++) {
        Map<String, dynamic> product = {};
        for (int j = 0; j < headers.length && j < csvData[i].length; j++) {
          product[headers[j]] = csvData[i][j];
        }
        products.add(product);
      }
      
      developer.log('Productos cargados desde CSV: ${products.length} registros');
      return products;
    } catch (e) {
      developer.log('Error cargando productos desde CSV: $e');
      return [];
    }
  }
  
  /// Elimina todos los archivos CSV
  static Future<bool> clearAllData() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final files = [
        File('${directory.path}/$_usersFileName'),
        File('${directory.path}/$_clientsFileName'),
        File('${directory.path}/$_productsFileName'),
        File('${directory.path}/$_ordersFileName'),
      ];
      
      for (var file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      developer.log('Todos los archivos CSV eliminados');
      return true;
    } catch (e) {
      developer.log('Error eliminando archivos CSV: $e');
      return false;
    }
  }
  
  /// Obtiene el tamaño total de los archivos CSV
  static Future<int> getTotalStorageSize() async {
    try {
      final directory = await _getAppDocumentsDirectory();
      final files = await directory.list().toList();
      int totalSize = 0;
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.csv')) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      developer.log('Error calculando tamaño de almacenamiento: $e');
      return 0;
    }
  }
}
