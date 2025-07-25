import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar la configuración del modo offline
class OfflineConfigService {
  static const String _offlineModeKey = 'offline_mode_enabled';
  static const String _lastSyncKey = 'last_sync_timestamp';
  
  /// Obtiene el estado actual del modo offline
  static Future<bool> isOfflineModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineModeKey) ?? false;
  }
  
  /// Activa o desactiva el modo offline
  static Future<void> setOfflineMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, enabled);
    
    if (enabled) {
      // Marcar el momento cuando se activó el modo offline
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    }
  }
  
  /// Obtiene la última fecha de sincronización
  static Future<DateTime?> getLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  /// Actualiza la fecha de última sincronización
  static Future<void> updateLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Verifica si necesita sincronización (más de X horas sin sincronizar)
  static Future<bool> needsSync({int hoursThreshold = 24}) async {
    final lastSync = await getLastSyncDate();
    if (lastSync == null) return true;
    
    final now = DateTime.now();
    final difference = now.difference(lastSync).inHours;
    return difference >= hoursThreshold;
  }
}
