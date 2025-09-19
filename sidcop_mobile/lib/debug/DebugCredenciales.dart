import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'dart:developer' as developer;

/// Clase para diagnosticar problemas con las credenciales
class DebugCredenciales {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  /// Verifica si las credenciales están guardadas correctamente
  static Future<void> verificarCredenciales() async {
    print('=== VERIFICANDO CREDENCIALES GUARDADAS ===');
    
    try {
      // Método 1: Verificar credenciales principales
      final usuario = await _secureStorage.read(key: 'login_usuario');
      final clave = await _secureStorage.read(key: 'login_clave');
      
      print('Credenciales principales:');
      print('  - login_usuario: ${usuario != null ? 'EXISTE' : 'NO EXISTE'}');
      print('  - login_clave: ${clave != null ? 'EXISTE (${clave?.length} chars)' : 'NO EXISTE'}');
      
      if (usuario != null) {
        print('  - Usuario: $usuario');
        
        // Método 2: Verificar credencial alternativa
        final claveAlternativa = await _secureStorage.read(key: 'clave_$usuario');
        print('  - clave_$usuario: ${claveAlternativa != null ? 'EXISTE (${claveAlternativa?.length} chars)' : 'NO EXISTE'}');
      }
      
      // Verificar datos de usuario guardados
      final perfilService = PerfilUsuarioService();
      final userData = await perfilService.obtenerDatosUsuario();
      
      if (userData != null) {
        print('\nDatos de usuario guardados:');
        print('  - usua_Usuario: ${userData['usua_Usuario']}');
        print('  - usua_Id: ${userData['usua_Id']}');
        print('  - usua_IdPersona: ${userData['usua_IdPersona']}');
        print('  - usua_EsVendedor: ${userData['usua_EsVendedor']}');
      } else {
        print('\n❌ NO HAY DATOS DE USUARIO GUARDADOS');
      }
      
    } catch (e) {
      print('❌ ERROR verificando credenciales: $e');
    }
    
    print('=== VERIFICACIÓN DE CREDENCIALES COMPLETADA ===');
  }
  
  /// Intenta ejecutar el endpoint directamente para debug
  static Future<void> probarEndpointDirecto() async {
    print('\n=== PROBANDO ENDPOINT /Usuarios/IniciarSesion DIRECTAMENTE ===');
    
    try {
      final perfilService = PerfilUsuarioService();
      
      // Verificar si tenemos datos de usuario
      final userData = await perfilService.obtenerDatosUsuario();
      if (userData == null) {
        print('❌ No hay datos de usuario para probar');
        return;
      }
      
      final usuario = userData['usua_Usuario'];
      if (usuario == null) {
        print('❌ No hay nombre de usuario disponible');
        return;
      }
      
      print('Intentando obtener información completa...');
      final informacionCompleta = await perfilService.obtenerInformacionCompletaUsuario();
      
      if (informacionCompleta != null) {
        print('✅ ÉXITO: Información obtenida');
        print('Fuente de datos: ${informacionCompleta['fuenteDatos']}');
        print('Teléfono: ${informacionCompleta['telefono']}');
        print('Correo: ${informacionCompleta['correo']}');
        print('Ruta asignada: ${informacionCompleta['rutaAsignada']}');
        print('Supervisor: ${informacionCompleta['supervisor']}');
      } else {
        print('❌ No se pudo obtener información completa');
      }
      
    } catch (e) {
      print('❌ ERROR en prueba directa: $e');
    }
    
    print('=== PRUEBA DIRECTA COMPLETADA ===');
  }
  
  /// Simula guardar credenciales para testing
  static Future<void> simularGuardadoCredenciales() async {
    print('\n=== SIMULANDO GUARDADO DE CREDENCIALES ===');
    
    try {
      final perfilService = PerfilUsuarioService();
      final userData = await perfilService.obtenerDatosUsuario();
      
      if (userData != null && userData['usua_Usuario'] != null) {
        final usuario = userData['usua_Usuario'].toString();
        
        print('¿Tienes la contraseña del usuario $usuario? (Para testing)');
        print('Si la tienes, puedes agregarla manualmente para probar.');
        
        // Por seguridad, no hardcodeamos contraseñas aquí
        // El usuario tendría que agregarla manualmente o hacer login nuevamente
        
      } else {
        print('❌ No se puede simular sin datos de usuario');
      }
      
    } catch (e) {
      print('❌ ERROR simulando credenciales: $e');
    }
    
    print('=== SIMULACIÓN COMPLETADA ===');
  }
  
  /// Limpia todas las credenciales para testing
  static Future<void> limpiarCredenciales() async {
    print('\n=== LIMPIANDO CREDENCIALES PARA TESTING ===');
    
    try {
      await _secureStorage.delete(key: 'login_usuario');
      await _secureStorage.delete(key: 'login_clave');
      
      // También limpiar credenciales alternativas
      final perfilService = PerfilUsuarioService();
      final userData = await perfilService.obtenerDatosUsuario();
      
      if (userData != null && userData['usua_Usuario'] != null) {
        final usuario = userData['usua_Usuario'].toString();
        await _secureStorage.delete(key: 'clave_$usuario');
        print('Credenciales de $usuario eliminadas');
      }
      
      print('✅ Credenciales limpiadas');
      
    } catch (e) {
      print('❌ ERROR limpiando credenciales: $e');
    }
    
    print('=== LIMPIEZA COMPLETADA ===');
  }
  
  /// Ejecuta todas las verificaciones
  static Future<void> diagnosticoCompleto() async {
    print('\n🔍 INICIANDO DIAGNÓSTICO COMPLETO DE CREDENCIALES');
    
    await verificarCredenciales();
    await probarEndpointDirecto();
    
    print('\n🔍 DIAGNÓSTICO COMPLETO TERMINADO');
    print('Revisa los logs arriba para identificar el problema.');
  }
}
