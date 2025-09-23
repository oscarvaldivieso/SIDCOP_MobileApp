import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';

class PerfilUsuarioService {
  static const String _userDataKey = 'user_data';
  final String _apiServer = apiServer;
  final String _apiKey = apikey;
  
  // Filtrar propiedades de navegación y campos innecesarios
  Map<String, dynamic> _filtrarDatosUsuario(Map<String, dynamic> userData) {
    final Map<String, dynamic> datosFiltrados = {};
    
    // Lista de campos que queremos mantener
    final camposPermitidos = {
      'code_Status', 'message_Status', 'usua_Id', 'usua_Usuario', 'usua_Clave',
      'role_Descripcion', 'cargo', 'dni', 'correo', 'telefono', 'personaId',
      'imagen', 'nombres', 'apellidos', 'sucursal', 'role_Id', 'usua_IdPersona',
      'usua_EsVendedor', 'usua_EsAdmin', 'usua_Imagen', 'usua_Creacion',
      'usua_FechaCreacion', 'usua_Modificacion', 'usua_FechaModificacion',
      'usua_Estado', 'permisosJson', 'nombreCompleto', 'datosVendedor'
    };
    
    // Filtrar solo los campos permitidos
    userData.forEach((key, value) {
      if (camposPermitidos.contains(key)) {
        datosFiltrados[key] = value;
      }
    });
    
    // Si hay datos del vendedor, también filtrarlos
    if (datosFiltrados['datosVendedor'] != null && datosFiltrados['datosVendedor'] is Map) {
      datosFiltrados['datosVendedor'] = _filtrarDatosVendedor(datosFiltrados['datosVendedor']);
    }
    
    return datosFiltrados;
  }
  
  // Filtrar datos del vendedor
  Map<String, dynamic> _filtrarDatosVendedor(Map<String, dynamic> datosVendedor) {
    final Map<String, dynamic> vendedorFiltrado = {};
    
    // Lista de campos del vendedor que queremos mantener
    final camposVendedorPermitidos = {
      'vend_Id', 'vend_Codigo', 'vend_DNI', 'vend_Nombres', 'vend_Apellidos',
      'vend_Telefono', 'vend_Correo', 'vend_Sexo', 'vend_DireccionExacta',
      'sucu_Id', 'colo_Id', 'vend_Supervisor', 'vend_Ayudante', 'vend_Tipo',
      'vend_EsExterno', 'vend_Estado', 'usua_Creacion', 'vend_FechaCreacion',
      'usua_Modificacion', 'vend_FechaModificacion', 'vend_Imagen',
      'sucu_Descripcion', 'sucu_DireccionExacta', 'colo_Descripcion',
      'muni_Codigo', 'muni_Descripcion', 'depa_Codigo', 'depa_Descripcion',
      'nombreSupervisor', 'apellidoSupervisor', 'nombreAyudante', 'apellidoAyudante',
      'usuarioCreacion', 'usuarioModificacion', 'secuencia'
    };
    
    // Filtrar solo los campos permitidos del vendedor
    datosVendedor.forEach((key, value) {
      if (camposVendedorPermitidos.contains(key)) {
        vendedorFiltrado[key] = value;
      }
    });
    
    return vendedorFiltrado;
  }
  
  // Obtener datos completos del usuario por usua_Id
  Future<Map<String, dynamic>?> obtenerDatosCompletoUsuario(int usuaId) async {
    try {
      final url = Uri.parse('$_apiServer/Usuarios/Listar');
      developer.log('Obteniendo datos completos del usuario URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      
      developer.log('Usuarios/Listar Response Status: ${response.statusCode}');
      developer.log('Usuarios/Listar Response Body: ${response.body}');
      print('response.body usuarios: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        List<dynamic> usuarios;
        
        // Verificar si la respuesta es directamente un array o un objeto con 'data'
        if (responseData is List) {
          usuarios = responseData;
        } else if (responseData is Map && responseData['data'] != null) {
          usuarios = responseData['data'];
        } else {
          developer.log('Estructura de respuesta no reconocida');
          return null;
        }
        
        // Buscar el usuario con el usua_Id específico
        for (var usuario in usuarios) {
          if (usuario['usua_Id'] == usuaId) {
            developer.log('Usuario encontrado: $usuario');
            return usuario;
          }
        }
        
        developer.log('Usuario con ID $usuaId no encontrado en la lista');
        return null;
      } else {
        developer.log('Error obteniendo lista de usuarios: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      developer.log('Error en obtenerDatosCompletoUsuario: $e');
      return null;
    }
  }
  
  // Buscar datos del vendedor por personaId
  Future<Map<String, dynamic>?> buscarDatosVendedor(int personaId) async {
    try {
      final url = Uri.parse('$_apiServer/Vendedores/Buscar/$personaId');
      developer.log('Buscando datos del vendedor URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      );
      
      developer.log('Buscar Vendedor Response Status: ${response.statusCode}');
      developer.log('Buscar Vendedor Response Body: ${response.body}');
      print('response.body: $response.body');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['data'] ?? responseData;
      } else {
        developer.log('Error buscando datos del vendedor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      developer.log('Error en buscarDatosVendedor: $e');
      return null;
    }
  }
  
  // Elimina campos de navegación y colecciones innecesarias
  Map<String, dynamic> limpiarNavegaciones(Map<String, dynamic> data) {
    final keysToRemove = data.keys.where((k) =>
        (k.startsWith('tb') && k.endsWith('Navigation')) ||
        (k.startsWith('inverse') && k.endsWith('Navigation')) ||
        k == 'role' ||
        k.endsWith('Navigation')
    ).toList();

    for (final key in keysToRemove) {
      data.remove(key);
    }

    // Limpiar recursivamente en objetos anidados
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        limpiarNavegaciones(value);
      }
    });
    return data;
  }

  // Guardar datos del usuario después del login
  Future<void> guardarDatosUsuario(Map<String, dynamic> userData) async {
    try {
      print('userData inicial: $userData');
      
      // Obtener el usua_Id de los datos de sesión
      final usuaId = userData['usua_Id'];
      
      if (usuaId != null) {
        developer.log('Obteniendo datos completos del usuario con ID: $usuaId');
        
        // Obtener datos completos del usuario desde /Usuarios/Listar
        final datosCompletos = await obtenerDatosCompletoUsuario(usuaId);
        
        // Guardar permisosJson original
        final permisosOriginal = userData['permisosJson'];

        if (datosCompletos != null) {
          // Combinar los datos de sesión con los datos completos
          userData.addAll(datosCompletos);
          // Restaurar permisosJson si existía originalmente
          if (permisosOriginal != null) {
            userData['permisosJson'] = permisosOriginal;
          }
          developer.log('Datos completos del usuario obtenidos y combinados');
          
          // Ahora verificar si el usuario es vendedor
          final esVendedor = userData['usua_EsVendedor'] == true;
          final personaId = userData['usua_IdPersona'];
          
          if (esVendedor && personaId != null) {
            developer.log('Usuario es vendedor, buscando datos adicionales para personaId: $personaId');
            
            // Hacer llamada a la API para obtener datos del vendedor
            final datosVendedor = await buscarDatosVendedor(personaId);
            
            if (datosVendedor != null) {
              // Agregar los datos del vendedor a los datos del usuario
              userData['datosVendedor'] = datosVendedor;
              developer.log('Datos del vendedor obtenidos y agregados: $datosVendedor');
            } else {
              developer.log('No se pudieron obtener los datos del vendedor');
            }
          } else {
            developer.log('El usuario no es vendedor o no tiene personaId');
          }
        } else {
          developer.log('No se pudieron obtener los datos completos del usuario');
        }
      } else {
        developer.log('No se encontró usua_Id en los datos de sesión');
      }
      
      // Limpiar campos de navegación antes de guardar
      final userDataLimpio = limpiarNavegaciones(Map<String, dynamic>.from(userData));
      // Serializar permisosJson si es necesario
      if (userDataLimpio.containsKey('permisosJson') &&
          (userDataLimpio['permisosJson'] is Map || userDataLimpio['permisosJson'] is List)) {
        userDataLimpio['permisosJson'] = jsonEncode(userDataLimpio['permisosJson']);
      }
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = jsonEncode(userDataLimpio);
      print('userDataJson final (limpio): $userDataJson');
      await prefs.setString(_userDataKey, userDataJson);
      developer.log('Datos de usuario guardados (limpios)');
      developer.log('Tamaño guardado: ${userDataJson.length} caracteres');
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
    return userData['correo'] ?? 
           userData['vend_Correo'] ?? 
           userData['email'] ?? 
           'No disponible';
  }
  
  Future<String> obtenerTelefono() async {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['telefono'] ?? 
           userData['vend_Telefono  '] ?? 
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
    final imagen = userData['imagen'] ?? 
                   userData['usua_Imagen'] ?? 
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