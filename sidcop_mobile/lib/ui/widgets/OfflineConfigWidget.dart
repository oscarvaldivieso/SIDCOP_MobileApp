import 'package:flutter/material.dart';
import '../../services/OfflineConfigService.dart';
import '../../services/SyncService.dart';
import '../../services/CacheService.dart';
import '../../services/EncryptedCsvStorageService.dart';
import '../../services/UsuarioService.dart';

class OfflineConfigWidget extends StatefulWidget {
  const OfflineConfigWidget({super.key});

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
        // Activar modo ONLINE (value = true significa switch ON = Online)
        await OfflineConfigService.setOfflineMode(false); // false = no offline = online
        
        // Sincronización automática al activar online
        if (_syncStats['has_connection'] == true) {
          final syncResult = await SyncService.syncAllData();
          if (syncResult) {
            // Actualizar timestamp de última sincronización
            await OfflineConfigService.updateLastSyncDate();
            
            // Iniciar precarga automática de productos
            final usuarioService = UsuarioService();
            usuarioService.precargarProductos().then((success) {
              if (success && mounted) {
                _showSnackBar(
                  'Datos sincronizados y productos precargados correctamente.',
                  Colors.green,
                );
              }
            });
            
            _showSnackBar(
              'Modo online activado. Sincronizando datos...',
              Colors.green,
            );
          } else {
            _showSnackBar(
              'Modo online activado. Error en sincronización.',
              Colors.orange,
            );
          }
        } else {
          _showSnackBar(
            'Modo online activado sin conexión. Se sincronizará cuando haya conexión.',
            Colors.orange,
          );
        }
      } else {
        // Activar modo OFFLINE (value = false significa switch OFF = Offline)
        await OfflineConfigService.setOfflineMode(true); // true = offline
        _showSnackBar(
          'Modo offline activado. La app usará datos locales.',
          Colors.blue,
        );
      }

      setState(() {
        _isOfflineMode = !value; // Invertir porque ahora value=true es online
      });

      await _loadSyncStats();
    } catch (e) {
      _showSnackBar('Error cambiando modo: $e', Colors.red);
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
        _showSnackBar(
          'Sincronización exitosa: ${result['synced_items']} elementos',
          Colors.green,
        );
      } else {
        _showSnackBar(
          'Error en sincronización: ${result['message']}',
          Colors.red,
        );
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
        ) ??
        false;
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
    return Container(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: _isLoading ? null : () => _toggleOfflineMode(_isOfflineMode), // Cambiar lógica
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              // Ícono de conexión
              Icon(
                _syncStats['has_connection'] == true
                    ? Icons.wifi
                    : Icons.wifi_off,
                color: _syncStats['has_connection'] == true
                    ? Colors.green
                    : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              // Información principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_isOfflineMode ? 'Online' : 'Offline', // Lógica invertida
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Satoshi',
                        color: !_isOfflineMode ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      _syncStats['has_connection'] == true
                          ? 'Conectado'
                          : 'Sin conexión',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    // Mostrar última sincronización
                    if (!_isOfflineMode) // Solo mostrar en modo online
                      Text(
                        'Última sync: ${_formatLastSync()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                  ],
                ),
              ),
              // Switch integrado - lógica invertida
              Switch(
                value: !_isOfflineMode, // Invertir: true = Online, false = Offline
                onChanged: _isLoading ? null : _toggleOfflineMode,
                activeColor: Colors.green, // Verde para online
                inactiveThumbColor: Colors.orange, // Naranja para offline
              ),
            ],
          ),
        ),
      ),
    );
  }
}
