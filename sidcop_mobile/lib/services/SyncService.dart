import 'dart:convert';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'EncryptedCsvStorageService.dart';
import 'CacheService.dart';
import 'OfflineConfigService.dart';
import 'UsuarioService.dart';
import 'ClientesService.Dart';
import 'ProductosService.Dart';

/// Servicio para manejar la sincronización entre datos offline y online
class SyncService {
  static final UsuarioService _usuarioService = UsuarioService();
  static final ClientesService _clientesService = ClientesService();
  static final ProductosService _productosService = ProductosService();
  
  /// Verifica si hay conexión a internet
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      developer.log('Error verificando conexión: $e');
      return false;
    }
  }
  
  /// Sincroniza todos los datos cuando hay conexión
  static Future<bool> syncAllData() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) {
        developer.log('No hay conexión a internet para sincronizar');
        return false;
      }
      
      bool allSynced = true;
      
      // Sincronizar clientes
      final clientsSync = await syncClients();
      if (!clientsSync) allSynced = false;
      
      // Sincronizar productos
      final productsSync = await syncProducts();
      if (!productsSync) allSynced = false;
      
      if (allSynced) {
        await OfflineConfigService.updateLastSyncDate();
        developer.log('Sincronización completa exitosa');
      }
      
      return allSynced;
    } catch (e) {
      developer.log('Error en sincronización completa: $e');
      return false;
    }
  }
  
  /// Sincroniza datos de clientes
  static Future<bool> syncClients() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) return false;
      
      // Obtener clientes desde el servidor
      final clientsData = await _clientesService.obtenerClientes();
      
      if (clientsData != null && clientsData.isNotEmpty) {
        // Guardar en CSV cifrado
        await EncryptedCsvStorageService.saveClientsData(clientsData);
        
        // Guardar en caché
        await CacheService.cacheClientsData(clientsData);
        
        developer.log('Clientes sincronizados: ${clientsData.length} registros');
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error sincronizando clientes: $e');
      return false;
    }
  }
  
  /// Sincroniza datos de productos
  static Future<bool> syncProducts() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) return false;
      
      // Obtener productos desde el servidor
      final productsData = await _productosService.obtenerProductos();
      
      if (productsData != null && productsData.isNotEmpty) {
        // Guardar en CSV cifrado
        await EncryptedCsvStorageService.saveProductsData(productsData);
        
        // Guardar en caché
        await CacheService.cacheProductsData(productsData);
        
        developer.log('Productos sincronizados: ${productsData.length} registros');
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error sincronizando productos: $e');
      return false;
    }
  }
  
  /// Obtiene datos de clientes (online o offline según configuración)
  static Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final isOfflineMode = await OfflineConfigService.isOfflineModeEnabled();
      
      if (isOfflineMode || !await hasInternetConnection()) {
        // Modo offline: intentar obtener desde caché primero
        var clients = await CacheService.getCachedClientsData();
        
        if (clients == null || clients.isEmpty) {
          // Si no hay caché, obtener desde CSV cifrado
          clients = await EncryptedCsvStorageService.loadClientsData();
        }
        
        developer.log('Clientes obtenidos en modo offline: ${clients?.length ?? 0} registros');
        return clients ?? [];
      } else {
        // Modo online: obtener desde servidor y actualizar caché/CSV
        try {
          final clients = await _clientesService.obtenerClientes();
          if (clients != null && clients.isNotEmpty) {
            // Actualizar caché y CSV cifrado en background
            CacheService.cacheClientsData(clients);
            EncryptedCsvStorageService.saveClientsData(clients);
            
            developer.log('Clientes obtenidos en modo online: ${clients.length} registros');
            return clients;
          }
        } catch (e) {
          developer.log('Error obteniendo clientes online, fallback a offline: $e');
        }
        
        // Fallback a datos offline si falla la conexión
        var clients = await CacheService.getCachedClientsData();
        clients ??= await EncryptedCsvStorageService.loadClientsData();
        
        return clients ?? [];
      }
    } catch (e) {
      developer.log('Error obteniendo clientes: $e');
      return [];
    }
  }
  
  /// Obtiene datos de productos (online o offline según configuración)
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final isOfflineMode = await OfflineConfigService.isOfflineModeEnabled();
      
      if (isOfflineMode || !await hasInternetConnection()) {
        // Modo offline: intentar obtener desde caché primero
        var products = await CacheService.getCachedProductsData();
        
        if (products == null || products.isEmpty) {
          // Si no hay caché, obtener desde CSV cifrado
          products = await EncryptedCsvStorageService.loadProductsData();
        }
        
        developer.log('Productos obtenidos en modo offline: ${products?.length ?? 0} registros');
        return products ?? [];
      } else {
        // Modo online: obtener desde servidor y actualizar caché/CSV
        try {
          final products = await _productosService.obtenerProductos();
          if (products != null && products.isNotEmpty) {
            // Actualizar caché y CSV cifrado en background
            CacheService.cacheProductsData(products);
            EncryptedCsvStorageService.saveProductsData(products);
            
            developer.log('Productos obtenidos en modo online: ${products.length} registros');
            return products;
          }
        } catch (e) {
          developer.log('Error obteniendo productos online, fallback a offline: $e');
        }
        
        // Fallback a datos offline si falla la conexión
        var products = await CacheService.getCachedProductsData();
        products ??= await EncryptedCsvStorageService.loadProductsData();
        
        return products ?? [];
      }
    } catch (e) {
      developer.log('Error obteniendo productos: $e');
      return [];
    }
  }
  
  /// Fuerza una sincronización completa
  static Future<Map<String, dynamic>> forceSyncAll() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) {
        return {
          'success': false,
          'message': 'No hay conexión a internet',
          'synced_items': 0,
        };
      }
      
      int syncedItems = 0;
      List<String> errors = [];
      
      // Sincronizar clientes
      try {
        if (await syncClients()) {
          syncedItems++;
        }
      } catch (e) {
        errors.add('Clientes: $e');
      }
      
      // Sincronizar productos
      try {
        if (await syncProducts()) {
          syncedItems++;
        }
      } catch (e) {
        errors.add('Productos: $e');
      }
      
      if (syncedItems > 0) {
        await OfflineConfigService.updateLastSyncDate();
      }
      
      return {
        'success': syncedItems > 0,
        'message': syncedItems > 0 ? 'Sincronización exitosa' : 'No se pudo sincronizar ningún elemento',
        'synced_items': syncedItems,
        'errors': errors,
      };
    } catch (e) {
      developer.log('Error en sincronización forzada: $e');
      return {
        'success': false,
        'message': 'Error en sincronización: $e',
        'synced_items': 0,
      };
    }
  }
  
  /// Obtiene estadísticas de sincronización
  static Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final lastSync = await OfflineConfigService.getLastSyncDate();
      final needsSync = await OfflineConfigService.needsSync();
      final hasConnection = await hasInternetConnection();
      final isOfflineMode = await OfflineConfigService.isOfflineModeEnabled();
      final cacheInfo = await CacheService.getCacheInfo();
      final csvSize = await EncryptedCsvStorageService.getTotalStorageSize();
      
      return {
        'last_sync': lastSync?.toIso8601String(),
        'needs_sync': needsSync,
        'has_connection': hasConnection,
        'offline_mode': isOfflineMode,
        'cache_info': cacheInfo,
        'csv_storage_size_bytes': csvSize,
        'csv_storage_size_mb': (csvSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      developer.log('Error obteniendo estadísticas de sincronización: $e');
      return {};
    }
  }
}
