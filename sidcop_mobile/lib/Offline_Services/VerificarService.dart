import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/OfflineAuthService.dart';

class VerificarService {
  
  /// Verifica si hay credenciales offline guardadas y muestra información de debug
  static Future<void> verificarCredencialesOffline() async {
    try {
      developer.log('=== VERIFICANDO CREDENCIALES OFFLINE ===');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar credenciales de "Remember me"
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      
      developer.log('Remember Me: $rememberMe');
      developer.log('Saved Email: ${savedEmail.isNotEmpty ? savedEmail : "VACÍO"}');
      developer.log('Saved Password: ${savedPassword.isNotEmpty ? "EXISTE" : "VACÍO"}');
      
      // Verificar credenciales offline
      final credentialsJson = prefs.getString('offline_credentials');
      final userDataJson = prefs.getString('offline_user_data');
      final lastOnlineLogin = prefs.getString('last_online_login');
      
      developer.log('Offline Credentials: ${credentialsJson != null ? "EXISTE" : "NO EXISTE"}');
      developer.log('Offline User Data: ${userDataJson != null ? "EXISTE" : "NO EXISTE"}');
      developer.log('Last Online Login: ${lastOnlineLogin ?? "NUNCA"}');
      
      // Verificar métodos del servicio
      final hasOfflineCredentials = await OfflineAuthService.hasOfflineCredentials();
      final hasValidSession = await OfflineAuthService.hasValidOfflineSession();
      final areExpired = await OfflineAuthService.areCredentialsExpired();
      
      developer.log('Has Offline Credentials: $hasOfflineCredentials');
      developer.log('Has Valid Session: $hasValidSession');
      developer.log('Are Expired: $areExpired');
      
      // Verificar conexión
      final isConnected = await verificarConexion();
      developer.log('Is Online: $isConnected');
      
      developer.log('=== FIN VERIFICACIÓN ===');
      
    } catch (e) {
      developer.log('Error al verificar credenciales offline: $e');
    }
  }
  
  /// Verifica la conexión a internet
  static Future<bool> verificarConexion() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        developer.log('Conexión verificada: ONLINE');
        return true;
      } else {
        developer.log('Conexión verificada: OFFLINE (Status: ${response.statusCode})');
        return false;
      }
    } catch (e) {
      developer.log('Conexión verificada: OFFLINE (Error: $e)');
      return false;
    }
  }
  
  /// Limpia todas las credenciales para testing
  static Future<void> limpiarTodasLasCredenciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar Remember Me
      await prefs.remove('remember_me');
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      
      // Limpiar credenciales offline
      await OfflineAuthService.clearOfflineCredentials();
      
      developer.log('Todas las credenciales han sido limpiadas');
    } catch (e) {
      developer.log('Error al limpiar credenciales: $e');
    }
  }
}