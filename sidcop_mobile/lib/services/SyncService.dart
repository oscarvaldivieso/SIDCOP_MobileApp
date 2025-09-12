import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/ProductImageCacheService.dart';
import 'package:sidcop_mobile/services/ClientImageCacheService.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/services/ProductosService.Dart';
import 'package:sidcop_mobile/models/ClientesViewModel.Dart';
import 'package:sidcop_mobile/services/CacheService.dart';
import 'package:sidcop_mobile/services/OfflineDatabaseService.dart';
import 'package:sidcop_mobile/services/OfflineConfigService.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/SincronizacionService.dart';

/// Servicio para manejar la sincronización entre datos offline y online
class SyncService {
  // static final UsuarioService _usuarioService = UsuarioService();
  static final ClientesService _clientesService = ClientesService();
  static final ProductosService _productosService = ProductosService();

  /// Verifica si hay conexión a internet
  static Future<bool> hasInternetConnection() async {
    try {
      print('\n=== VERIFICANDO CONECTIVIDAD ===');
      final connectivityResult = await Connectivity().checkConnectivity();
      print('CONNECTIVITY RESULT: $connectivityResult');
      
      if (connectivityResult == ConnectivityResult.none) {
        print('SIN CONECTIVIDAD - RETORNANDO FALSE');
        return false;
      }
      
      print('HAY CONECTIVIDAD - VERIFICANDO ACCESO REAL A INTERNET...');
      
      // Verificación adicional: intentar hacer una petición HTTP real
      try {
        final response = await http.get(
          Uri.parse('$apiServer/test'), // Endpoint de prueba
          headers: {'X-Api-Key': apikey},
        ).timeout(const Duration(seconds: 5));
        
        print('TEST HTTP STATUS: ${response.statusCode}');
        final hasRealConnection = response.statusCode < 500;
        print('CONEXIÓN REAL: $hasRealConnection');
        return hasRealConnection;
      } catch (e) {
        print('ERROR EN TEST HTTP: $e');
        // Si falla el test, asumir que sí hay conexión (puede ser problema del endpoint de test)
        print('ASUMIENDO CONEXIÓN DISPONIBLE A PESAR DEL ERROR');
        return true;
      }
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  /// Sincroniza todos los datos cuando hay conexión
  static Future<bool> syncAllData() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) {
        print('No hay conexión a internet para sincronizar');
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
        print('Sincronización completa exitosa');
      }

      return allSynced;
    } catch (e) {
      print('Error en sincronización completa: $e');
      return false;
    }
  }

  /// Sincroniza todos los datos offline con el servidor
  static Future<bool> syncAllDataToServer() async {
    try {
      print('Iniciando sincronización completa con servidor...');
      
      bool allSuccess = true;
      
      // Falta
      
      print('Sincronización completa finalizada');
      return allSuccess;
    } catch (e) {
      print('Error en sincronización completa: $e');
      return false;
    }
  }

  /// Cachea imágenes de clientes para uso offline
  static Future<bool> cacheClientImages() async {
    try {
      print('Iniciando caché de imágenes de clientes...');
      
      // Obtener lista de clientes
      final clientsData = await getClients();
      if (clientsData.isEmpty) {
        print('No hay clientes para cachear imágenes');
        return true;
      }

      // Convertir a objetos Cliente
      final clients = clientsData.map((data) => Cliente.fromJson(data)).toList();
      
      // Usar ClientImageCacheService para cachear
      final clientImageService = ClientImageCacheService();
      final success = await clientImageService.cacheAllClientImages(clients);
      
      if (success) {
        print('Caché de imágenes de clientes completado exitosamente');
      } else {
        print('Error en caché de imágenes de clientes');
      }
      
      return success;
    } catch (e) {
      print('Error cacheando imágenes de clientes: $e');
      return false;
    }
  }

  /// Sincroniza datos de clientes
  static Future<bool> syncClients() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) return false;

      // Obtener clientes desde el servidor
      final clientsResponse = await _clientesService.getClientes();

      if (clientsResponse.isNotEmpty) {
        // Convertir List<dynamic> a List<Map<String, dynamic>>
        final clientsData = clientsResponse.cast<Map<String, dynamic>>();

        // Guardar en SQLite cifrado
        await OfflineDatabaseService.saveClientsData(clientsData);

        // Guardar en caché
        await CacheService.cacheClientsData(clientsData);

        print(
          'Clientes sincronizados: ${clientsData.length} registros',
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Error sincronizando clientes: $e');
      return false;
    }
  }

  /// Sincroniza datos de productos
  static Future<bool> syncProducts() async {
    try {
      final hasConnection = await hasInternetConnection();
      if (!hasConnection) return false;

      // Obtener productos desde el servidor
      final productsResponse = await _productosService.getProductos();

      if (productsResponse.isNotEmpty) {
        // Convertir List<Productos> a List<Map<String, dynamic>>
        final productsData = productsResponse
            .map((producto) => producto.toJson())
            .toList();

        // Guardar en SQLite cifrado
        await OfflineDatabaseService.saveProductsData(productsData);

        // Guardar en caché
        await CacheService.cacheProductsData(productsData);

        print(
          'Productos sincronizados: ${productsData.length} registros',
        );
        return true;
      }

      return false;
    } catch (e) {
      print('Error sincronizando productos: $e');
      return false;
    }
  }


  /// Obtiene datos de clientes (online o offline según configuración)
  static Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final isOfflineMode = await OfflineConfigService.isOfflineModeEnabled();
      final hasConnection = await hasInternetConnection();

      print('getClients - isOfflineMode: $isOfflineMode, hasConnection: $hasConnection');

      if (isOfflineMode || !hasConnection) {
        // Modo offline: intentar obtener desde caché primero
        print('Modo offline - buscando datos locales...');
        
        var clients = await CacheService.getCachedClientsData();
        print('Cache clientes: ${clients?.length ?? 0} registros');

        if (clients == null || clients.isEmpty) {
          // Si no hay caché, obtener desde SQLite cifrado
          print('Buscando en SQLite...');
          clients = await OfflineDatabaseService.loadClientsData();
          print('SQLite clientes: ${clients.length} registros');
        }

        print('Clientes obtenidos en modo offline: ${clients.length} registros');
        return clients;
      } else {
        // Modo online: obtener desde servidor y actualizar caché/SQLite
        try {
          print('Obteniendo clientes desde API...');
          final clientsResponse = await _clientesService.getClientes();
          print('API response: ${clientsResponse.length} clientes');
          
          if (clientsResponse.isNotEmpty) {
            // Convertir List<dynamic> a List<Map<String, dynamic>>
            final clients = clientsResponse.cast<Map<String, dynamic>>();

            // Actualizar caché y SQLite cifrado en background
            print('Guardando en cache...');
            CacheService.cacheClientsData(clients);
            
            print('Guardando en SQLite...');
            OfflineDatabaseService.saveClientsData(clients);

            print('Clientes obtenidos en modo online: ${clients.length} registros');
            return clients;
          }
        } catch (e) {
          print('Error obteniendo clientes online, fallback a offline: $e');
        }

        // Fallback a datos offline si falla la conexión
        print('Fallback a datos offline...');
        var clients = await CacheService.getCachedClientsData();
        print('Fallback cache: ${clients?.length ?? 0} registros');
        
        if (clients == null || clients.isEmpty) {
          clients = await OfflineDatabaseService.loadClientsData();
          print('Fallback SQLite: ${clients.length} registros');
        }

        return clients;
      }
    } catch (e) {
      print('Error obteniendo clientes: $e');
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
          // Si no hay caché, obtener desde SQLite cifrado
          products = await OfflineDatabaseService.loadProductsData();
        }

        print(
          'Productos obtenidos en modo offline: ${products.length} registros',
        );
        return products;
      } else {
        // Modo online: obtener desde servidor y actualizar caché/CSV
        try {
          final productsResponse = await _productosService.getProductos();
          if (productsResponse.isNotEmpty) {
            // Convertir List<Productos> a List<Map<String, dynamic>>
            final products = productsResponse
                .map((producto) => producto.toJson())
                .toList();

            // Actualizar caché y SQLite cifrado en background
            CacheService.cacheProductsData(products);
            OfflineDatabaseService.saveProductsData(products);

            print(
              'Productos obtenidos en modo online: ${products.length} registros',
            );
            return products;
          }
        } catch (e) {
          print(
            'Error obteniendo productos online, fallback a offline: $e',
          );
        }

        // Fallback a datos offline si falla la conexión
        var products = await CacheService.getCachedProductsData();
        if (products == null || products.isEmpty) {
          products = await OfflineDatabaseService.loadProductsData();
        }

        return products.isEmpty ? [] : products;
      }
    } catch (e) {
      print('Error obteniendo productos: $e');
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
      
      // Sincronizar visitas pendientes
      try {
        final visitasSync = await SincronizacionService.sincronizarVisitasPendientes();
        if (visitasSync > 0) {
          syncedItems++;
          print('Visitas sincronizadas: $visitasSync');
        }
      } catch (e) {
        errors.add('Visitas: $e');
      }

      if (syncedItems > 0) {
        await OfflineConfigService.updateLastSyncDate();
      }

      return {
        'success': syncedItems > 0,
        'message': syncedItems > 0
            ? 'Sincronización exitosa'
            : 'No se pudo sincronizar ningún elemento',
        'synced_items': syncedItems,
        'errors': errors,
      };
    } catch (e) {
      print('Error en sincronización forzada: $e');
      return {
        'success': false,
        'message': 'Error en sincronización: $e',
        'synced_items': 0,
      };
    }
  }

  /// Sincronización híbrida después del login
  static Future<void> syncAfterLogin({
    bool immediate = false,
    Function(String)? onProgress,
  }) async {
    try {
      print('Iniciando sincronizacion post-login...');
      
      // Verificar conexión
      if (!await hasInternetConnection()) {
        print('Sin conexion, usando datos offline existentes');
        onProgress?.call('Sin conexión - usando datos offline');
        return;
      }

      if (immediate) {
        // Sincronización bloqueante para datos críticos
        onProgress?.call('Cargando...');
        await _syncCriticalData();
        
        onProgress?.call('Actualizando datos secundarios...');
        await _syncSecondaryData();
        
        print('Sincronizacion inmediata completada');
      } else {
        // Sincronización híbrida (recomendada)
        onProgress?.call('Cargando...');
        await _syncCriticalData();
        
        // Datos secundarios en background
        onProgress?.call('Sincronizando en segundo plano...');
        _syncSecondaryDataInBackground();
        
        print('Sincronizacion critica completada, secundaria en background');
      }
    } catch (e) {
      print('Error en sincronizacion post-login: $e');
      onProgress?.call('Error en sincronización - usando datos offline');
    }
  }

  /// Sincroniza datos críticos (bloqueante)
  static Future<void> _syncCriticalData() async {
    try {
      // Datos críticos que necesitan estar frescos inmediatamente
      print('Sincronizando datos criticos...');
      
      // Aquí puedes agregar sincronización de:
      // - Permisos del usuario
      // - Configuración de la empresa
      // - Datos de autenticación actualizados
      
      // Por ahora, simular una operación rápida
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('Datos criticos sincronizados');
    } catch (e) {
      print('Error sincronizando datos criticos: $e');
      rethrow;
    }
  }

  /// Sincroniza datos secundarios (bloqueante)
  static Future<void> _syncSecondaryData() async {
    try {
      print('Sincronizando datos secundarios...');
      
      // Sincronizar productos
      print('Sincronizando productos...');
      await SyncService.getProducts();
      
      // Sincronizar clientes
      print('Sincronizando clientes...');
      await SyncService.getClients();
      
      // Aquí puedes agregar más sincronizaciones:
      // - Historial de pedidos
      // - Catálogo completo
      
      print('Datos secundarios sincronizados');
    } catch (e) {
      print('Error sincronizando datos secundarios: $e');
      rethrow;
    }
  }

  /// Sincroniza datos secundarios en background (no bloqueante)
  static void _syncSecondaryDataInBackground() {
    Future(() async {
      try {
        print('Iniciando sincronizacion secundaria en background...');
        await _syncSecondaryData();
        print('Sincronizacion secundaria en background completada');
      } catch (e) {
        print('Error en sincronizacion secundaria background: $e');
      }
    });
  }

  /// Obtiene estadísticas de sincronización
  static Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final lastSync = await OfflineConfigService.getLastSyncDate();
      final needsSync = await OfflineConfigService.needsSync();
      final hasConnection = await hasInternetConnection();
      final isOfflineMode = await OfflineConfigService.isOfflineModeEnabled();
      final cacheInfo = await CacheService.getCacheInfo();
      final dbSize = await OfflineDatabaseService.getTotalStorageSize();

      return {
        'last_sync': lastSync?.toIso8601String(),
        'needs_sync': needsSync,
        'has_connection': hasConnection,
        'offline_mode': isOfflineMode,
        'cache_info': cacheInfo,
        'db_storage_size_bytes': dbSize,
        'db_storage_size_mb': (dbSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error obteniendo estadísticas de sincronización: $e');
      return {};
    }
  }
}
