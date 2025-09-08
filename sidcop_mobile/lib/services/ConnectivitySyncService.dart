import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';

class ConnectivitySyncService {
  static ConnectivitySyncService? _instance;
  static ConnectivitySyncService get instance => _instance ??= ConnectivitySyncService._();
  
  ConnectivitySyncService._();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isListening = false;
  bool _isSyncing = false;
  
  // Global context for showing notifications
  BuildContext? _context;
  
  void initialize(BuildContext context) {
    _context = context;
    if (!_isListening) {
      _startListening();
    }
  }
  
  void updateContext(BuildContext context) {
    _context = context;
  }
  
  void _startListening() {
    _isListening = true;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none && !_isSyncing) {
        // Connectivity restored, sync offline orders
        _syncOfflineOrders();
      }
    });
  }
  
  Future<void> _syncOfflineOrders() async {
    if (_isSyncing) return; // Prevent multiple simultaneous syncs
    
    _isSyncing = true;
    
    try {
      print('ConnectivitySyncService: Conectividad restaurada, sincronizando pedidos offline...');
      
      // Debug: List all storage keys
      await PedidosScreenOffline.listarTodasLasClaves();
      
      // Check if there are pending orders to sync using simple method
      final pendientesRaw = await PedidosScreenOffline.leerJson('pedidos_pendientes.json');
      
      print('ConnectivitySyncService DEBUG: pendientesRaw = $pendientesRaw');
      print('ConnectivitySyncService DEBUG: pendientesRaw type = ${pendientesRaw?.runtimeType}');
      print('ConnectivitySyncService DEBUG: pendientesRaw isEmpty = ${pendientesRaw?.isEmpty}');
      
      if (pendientesRaw != null && pendientesRaw.isNotEmpty) {
        final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
        print('ConnectivitySyncService: Encontrados ${pendientes.length} pedidos pendientes para sincronizar');
        
        // Show sync notification
        if (_context != null && _context!.mounted) {
          ScaffoldMessenger.of(_context!).showSnackBar(
            SnackBar(
              content: Text('Sincronizando ${pendientes.length} pedidos offline...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Sync the orders using simple method
        final sincronizadas = await PedidosScreenOffline.sincronizarPendientes();
        
        // Show success notification
        if (_context != null && _context!.mounted && sincronizadas > 0) {
          ScaffoldMessenger.of(_context!).showSnackBar(
            SnackBar(
              content: Text('¡$sincronizadas pedidos sincronizados exitosamente!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('ConnectivitySyncService: Sincronización de pedidos completada - $sincronizadas sincronizados');
      } else {
        print('ConnectivitySyncService: No hay pedidos pendientes para sincronizar');
      }
    } catch (e) {
      print('ConnectivitySyncService: Error sincronizando pedidos offline: $e');
      
      if (_context != null && _context!.mounted) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Text('Error sincronizando pedidos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }
  
  // Manual sync method that can be called from anywhere
  Future<void> manualSync() async {
    await _syncOfflineOrders();
  }
  
  // Check if there are pending orders without syncing
  Future<bool> hasPendingOrders() async {
    try {
      // Check using simple method first
      final pendientesRaw = await PedidosScreenOffline.leerJson('pedidos_pendientes.json');
      print('ConnectivitySyncService hasPendingOrders: pendientesRaw = $pendientesRaw');
      
      if (pendientesRaw != null && pendientesRaw.isNotEmpty) {
        final pendientes = List<Map<String, dynamic>>.from(pendientesRaw);
        print('ConnectivitySyncService hasPendingOrders: Found ${pendientes.length} pending orders');
        return pendientes.isNotEmpty;
      }
      
      // Fallback to complex method
      final pedidosPendientes = await PedidosScreenOffline.obtenerPedidosPendientes();
      print('ConnectivitySyncService hasPendingOrders: Complex method found ${pedidosPendientes.length} orders');
      return pedidosPendientes.isNotEmpty;
    } catch (e) {
      print('ConnectivitySyncService: Error checking pending orders: $e');
      return false;
    }
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
    _isListening = false;
    _context = null;
  }
}
