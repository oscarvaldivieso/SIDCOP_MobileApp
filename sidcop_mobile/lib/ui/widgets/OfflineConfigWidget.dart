import 'package:flutter/material.dart';
import '../../services/OfflineConfigService.dart';
import '../../services/SyncService.dart';
import '../../services/CacheService.dart';
import '../../services/EncryptedCsvStorageService.dart';

class OfflineConfigWidget extends StatefulWidget {
  const OfflineConfigWidget({Key? key}) : super(key: key);

  @override
  State<OfflineConfigWidget> createState() => _OfflineConfigWidgetState();
}

class _OfflineConfigWidgetState extends State<OfflineConfigWidget> {
  bool _isOfflineMode = false;
  bool _isLoading = false;
  Map<String, dynamic> _syncStats = {};

  @override
  void initState() {
    super.initState();
    _loadOfflineStatus();
    _loadSyncStats();
  }

  Future<void> _loadOfflineStatus() async {
    final isOffline = await OfflineConfigService.isOfflineModeEnabled();
    setState(() {
      _isOfflineMode = isOffline;
    });
  }

  Future<void> _loadSyncStats() async {
    final stats = await SyncService.getSyncStats();
    setState(() {
      _syncStats = stats;
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        // Activar modo offline - sincronizar datos primero
        final hasConnection = await SyncService.hasInternetConnection();
        if (hasConnection) {
          final syncResult = await SyncService.syncAllData();
          if (syncResult) {
            await OfflineConfigService.setOfflineMode(true);
            _showSnackBar('Modo offline activado. Datos sincronizados correctamente.', Colors.green);
          } else {
            _showSnackBar('Error sincronizando datos. Modo offline activado con datos existentes.', Colors.orange);
            await OfflineConfigService.setOfflineMode(true);
          }
        } else {
          await OfflineConfigService.setOfflineMode(true);
          _showSnackBar('Modo offline activado sin conexión. Usando datos locales.', Colors.orange);
        }
      } else {
        // Desactivar modo offline
        await OfflineConfigService.setOfflineMode(false);
        _showSnackBar('Modo offline desactivado. La app usará datos en línea.', Colors.blue);
      }

      setState(() {
        _isOfflineMode = value;
      });
      
      await _loadSyncStats();
    } catch (e) {
      _showSnackBar('Error cambiando modo offline: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceSyncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await SyncService.forceSyncAll();
      
      if (result['success']) {
        _showSnackBar('Sincronización exitosa: ${result['synced_items']} elementos', Colors.green);
      } else {
        _showSnackBar('Error en sincronización: ${result['message']}', Colors.red);
      }
      
      await _loadSyncStats();
    } catch (e) {
      _showSnackBar('Error sincronizando: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearOfflineData() async {
    final confirm = await _showConfirmDialog(
      'Limpiar Datos Offline',
      '¿Estás seguro de que quieres eliminar todos los datos offline? Esta acción no se puede deshacer.',
    );

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        await CacheService.clearAllCache();
        await EncryptedCsvStorageService.clearAllData();
        
        _showSnackBar('Datos offline eliminados correctamente', Colors.green);
        await _loadSyncStats();
      } catch (e) {
        _showSnackBar('Error eliminando datos offline: $e', Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  String _formatLastSync() {
    final lastSyncStr = _syncStats['last_sync'] as String?;
    if (lastSyncStr == null) return 'Nunca';
    
    try {
      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();
      final difference = now.difference(lastSync);
      
      if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minutos';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} horas';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return 'Error en fecha';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón único para estado y configuración
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading ? null : () => _toggleOfflineMode(!_isOfflineMode),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Ícono de estado de conexión
                      Icon(
                        _syncStats['has_connection'] == true ? Icons.wifi : Icons.wifi_off,
                        color: _syncStats['has_connection'] == true ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      // Información principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOfflineMode ? 'Offline' : 'Online',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isOfflineMode ? Colors.orange : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _syncStats['has_connection'] == true ? 'Conectado' : 'Sin conexión',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Switch
                      Switch(
                        value: _isOfflineMode,
                        onChanged: _isLoading ? null : _toggleOfflineMode,
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const Divider(),
            
            // Información de sincronización
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Última Sincronización'),
              subtitle: Text(_formatLastSync()),
              trailing: _syncStats['needs_sync'] == true
                ? const Icon(Icons.warning, color: Colors.orange)
                : const Icon(Icons.check_circle, color: Colors.green),
            ),
            
            const SizedBox(height: 16),
            
            // Botón de sincronización
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _forceSyncData,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
                label: const Text('Sincronizar'),
              ),
            ),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
