import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidcop_mobile/services/EncryptionService.dart';
import 'package:sidcop_mobile/services/EncryptedCsvStorageService.dart';

class PerfilUsuarioService {
  static const String _userDataKey = 'user_data';
  static const String _userDataFileName = 'user_profile.csv.enc';
  
  // Guardar datos del usuario después del login (usando almacenamiento cifrado)
  Future<void> guardarDatosUsuario(Map<String, dynamic> userData) async {
    try {
      // Guardar en SharedPreferences para compatibilidad hacia atrás
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = jsonEncode(userData);
      await prefs.setString(_userDataKey, userDataJson);
      
      // Guardar en almacenamiento cifrado
      await EncryptedCsvStorageService.saveData(
        _userDataFileName,
        [userData],
      );
      
      developer.log('Datos de usuario guardados en ambos sistemas');
    } catch (e) {
      developer.log('Error guardando datos de usuario: $e');
    }
  }
  
  // Obtener datos del usuario guardados (con soporte para modo offline)
  Future<Map<String, dynamic>?> obtenerDatosUsuario() async {
    try {
      // Intentar obtener de almacenamiento cifrado primero
      try {
        final dataList = await EncryptedCsvStorageService.loadData(_userDataFileName);
        if (dataList.isNotEmpty) {
          final userData = dataList[0] as Map<String, dynamic>;
          developer.log('Datos de usuario obtenidos de almacenamiento cifrado');
          return userData;
        }
      } catch (e) {
        developer.log('No se pudo cargar desde almacenamiento cifrado: $e');
        // Continuar con SharedPreferences como fallback
      }
      
      // Fallback a SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_userDataKey);
      
      if (userDataJson != null) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        developer.log('Datos de usuario obtenidos de SharedPreferences');
        return userData;
      }
      
      developer.log('No se encontraron datos de usuario guardados');
      return null;
    } catch (e) {
      developer.log('Error obteniendo datos de usuario: $e');
      return null;
    }
  }
  
  // Limpiar datos del usuario (para logout)
  Future<void> limpiarDatosUsuario() async {
    try {
      // Limpiar de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      
      // Limpiar de almacenamiento cifrado
      await EncryptedCsvStorageService.deleteFile(_userDataFileName);
      
      developer.log('Datos de usuario eliminados de ambos sistemas');
    } catch (e) {
      developer.log('Error eliminando datos de usuario: $e');
    }
  }
  
  // Verificar si hay datos de usuario guardados
  Future<bool> tieneUsuarioLogueado() async {
    try {
      // Verificar en almacenamiento cifrado primero
      if (await EncryptedCsvStorageService.fileExists(_userDataFileName)) {
        return true;
      }
      
      // Fallback a SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userDataKey);
    } catch (e) {
      developer.log('Error verificando usuario logueado: $e');
      return false;
    }
  }
  
  // Obtener campos específicos del usuario mapeados desde la respuesta del API
  Future<String> obtenerNombreCompleto() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['nombreCompleto'] ?? 
           userData['usua_Usuario'] ?? 
           userData['usuario'] ?? 
           'No disponible';
  }
  
  // Obtener nombre completo desde campos nombres y apellidos
  Future<String> obtenerNombreDesdeNombresApellidos() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    final nombres = userData['nombres'] ?? '';
    final apellidos = userData['apellidos'] ?? '';
    
    if (nombres.isNotEmpty && apellidos.isNotEmpty) {
      return '$nombres $apellidos';
    } else if (nombres.isNotEmpty) {
      return nombres;
    } else if (apellidos.isNotEmpty) {
      return apellidos;
    }
    
    // Fallback a otros campos si nombres y apellidos no están disponibles
    return userData['nombreCompleto'] ?? 
           userData['usua_Usuario'] ?? 
           userData['usuario'] ?? 
           'No disponible';
  }
  
  Future<String> obtenerNumeroIdentidad() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['dni'] ?? 
           userData['usua_NumeroIdentidad'] ?? 
           userData['numeroDocumento'] ?? 
           userData['documento'] ??
           'No disponible';
  }
  
  Future<String> obtenerNumeroEmpleado() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['numeroEmpleado'] ?? 
           userData['usua_Id']?.toString() ?? 
           userData['empleadoId']?.toString() ?? 
           userData['codigoEmpleado'] ??
           'No disponible';
  }
  
  Future<String> obtenerCorreoElectronico() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['correoElectronico'] ?? 
           userData['correo'] ?? 
           userData['email'] ?? 
           'No disponible';
  }
  
  Future<String> obtenerTelefono() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['telefono'] ?? 
           userData['phone'] ?? 
           userData['celular'] ?? 
           userData['numeroTelefono'] ??
           'No disponible';
  }
  
  Future<String> obtenerCargo() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['cargo'] ?? 
           userData['role_Descripcion'] ?? 
           userData['rol'] ?? 
           userData['puesto'] ??
           'No disponible';
  }
  
  Future<String?> obtenerImagenUsuario() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return null;
    
    // Mapear desde los campos del API response
    final imagen = userData['usua_Imagen'] ?? 
                   userData['imagen'] ?? 
                   userData['profileImage'] ?? 
                   userData['avatar'];
    
    // Verificar que la imagen no sea null, vacía o 'string' (valor por defecto)
    if (imagen == null || imagen.toString().isEmpty || imagen.toString().toLowerCase() == 'string') {
      return null;
    }
    
    return imagen.toString();
  }
  
  // Método para debug - mostrar todos los campos disponibles
  Future<void> mostrarCamposDisponibles() async {
    final userData = await obtenerDatosUsuario();
    if (userData != null) {
      developer.log('Campos disponibles en userData:');
      userData.forEach((key, value) {
        developer.log('  $key: $value');
      });
    } else {
      developer.log('No hay datos de usuario disponibles');
    }
  }
}