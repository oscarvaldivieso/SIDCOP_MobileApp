import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class PerfilUsuarioService {
  static const String _userDataKey = 'user_data';
  
  // Guardar datos del usuario después del login
  Future<void> guardarDatosUsuario(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = jsonEncode(userData);
      await prefs.setString(_userDataKey, userDataJson);
      developer.log('Datos de usuario guardados: $userDataJson');
    } catch (e) {
      developer.log('Error guardando datos de usuario: $e');
    }
  }
  
  // Obtener datos del usuario guardados
  Future<Map<String, dynamic>?> obtenerDatosUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_userDataKey);
      
      if (userDataJson != null) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        developer.log('Datos de usuario obtenidos: $userData');
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      developer.log('Datos de usuario eliminados');
    } catch (e) {
      developer.log('Error eliminando datos de usuario: $e');
    }
  }
  
  // Verificar si hay datos de usuario guardados
  Future<bool> tieneUsuarioLogueado() async {
    try {
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