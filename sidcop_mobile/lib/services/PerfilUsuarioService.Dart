import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  /// Obtiene información completa del usuario usando el endpoint /Usuarios/IniciarSesion
  /// Requiere credenciales válidas (usua_Usuario y usua_Clave)
  Future<Map<String, dynamic>?> obtenerInformacionCompletaUsuario() async {
    try {
      developer.log('=== OBTENIENDO INFORMACIÓN COMPLETA CON /Usuarios/IniciarSesion ===');
      
      // Intentar obtener credenciales desde FlutterSecureStorage
      final credenciales = await _obtenerCredencialesSeguras();
      
      if (credenciales == null) {
        developer.log('No se encontraron credenciales, usando método fallback');
        return await _obtenerInformacionFallback();
      }
      
      developer.log('Credenciales encontradas para usuario: ${credenciales['usua_Usuario']}');
      
      // Construir URL del endpoint
      final url = Uri.parse('$_apiServer/Usuarios/IniciarSesion');
      developer.log('Consultando información completa URL: $url');
      
      // Crear el body con solo los campos requeridos
      final body = {
        'usua_Usuario': credenciales['usua_Usuario'],
        'usua_Clave': credenciales['usua_Clave'],
      };
      
      developer.log('Enviando request con usuario: ${body['usua_Usuario']}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
        body: jsonEncode(body),
      );

      developer.log('Response Status: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Verificar si la respuesta es exitosa
        if (responseData['success'] == true || responseData['code_Status'] == 200) {
          developer.log('✓ Login exitoso, extrayendo información...');
          
          // Extraer información del response
          final informacionCompleta = _extraerInformacionDelResponse(responseData);
          
          developer.log('✓ Información completa obtenida desde endpoint /Usuarios/IniciarSesion');
          developer.log('Campos disponibles: ${informacionCompleta.keys.join(', ')}');
          
          return informacionCompleta;
        } else {
          developer.log('✗ Respuesta no exitosa: ${responseData['message_Status'] ?? responseData['message']}');
          return await _obtenerInformacionFallback();
        }
      } else {
        developer.log('✗ Error HTTP ${response.statusCode}, usando fallback');
        return await _obtenerInformacionFallback();
      }
      
    } catch (e) {
      developer.log('✗ Error en obtenerInformacionCompletaUsuario: $e');
      return await _obtenerInformacionFallback();
    }
  }
  
  /// Obtiene credenciales seguras desde FlutterSecureStorage
  Future<Map<String, String>?> _obtenerCredencialesSeguras() async {
    try {
      // Intentar obtener desde diferentes fuentes
      const storage = FlutterSecureStorage();
      
      // Opción 1: Credenciales guardadas específicamente para consultas
      final usuario = await storage.read(key: 'login_usuario');
      final clave = await storage.read(key: 'login_clave');
      
      if (usuario != null && clave != null) {
        developer.log('Credenciales encontradas en storage seguro');
        return {
          'usua_Usuario': usuario,
          'usua_Clave': clave,
        };
      }
      
      // Opción 2: Obtener desde datos de usuario si están disponibles
      final userData = await obtenerDatosUsuario();
      if (userData != null && userData['usua_Usuario'] != null) {
        final usuarioGuardado = userData['usua_Usuario'].toString();
        
        // Intentar obtener la clave desde storage con el usuario como key
        final claveGuardada = await storage.read(key: 'clave_$usuarioGuardado');
        
        if (claveGuardada != null) {
          developer.log('Credenciales reconstruidas desde storage');
          return {
            'usua_Usuario': usuarioGuardado,
            'usua_Clave': claveGuardada,
          };
        }
      }
      
      developer.log('No se encontraron credenciales válidas');
      return null;
      
    } catch (e) {
      developer.log('Error obteniendo credenciales: $e');
      return null;
    }
  }
  
  /// Extrae información relevante del response del endpoint /Usuarios/IniciarSesion
  Map<String, dynamic> _extraerInformacionDelResponse(Map<String, dynamic> responseData) {
    // El response puede tener diferentes estructuras, adaptarse a ambas
    final data = responseData['data'] ?? responseData;
    
    return {
      // Información básica del usuario
      'telefono': data['telefono'] ?? data['usua_Telefono'] ?? 'Sin información',
      'correo': data['correo'] ?? data['Correo'] ?? 'Sin información',
      'nombres': data['nombres'] ?? 'Sin información',
      'apellidos': data['apellidos'] ?? 'Sin información',
      'dni': data['dni'] ?? 'Sin información',
      'cargo': data['cargo'] ?? data['role_Descripcion'] ?? 'Sin información',
      
      // Información de asignación laboral
      'rutaAsignada': data['sucursal'] ?? 'Sin información',
      'supervisor': data['supervisor'] ?? 'Sin información',
      
      // Información operativa
      'cantidadInventario': data['cantidadInventario']?.toString() ?? '0',
      'rutasDelDiaJson': data['rutasDelDiaJson'],
      'permisosJson': data['permisosJson'],
      
      // Campos adicionales
      'codigo': data['codigo'] ?? data['usua_Id']?.toString() ?? 'Sin información',
      'usuaId': data['usua_Id']?.toString() ?? 'Sin información',
      'fechaConsulta': DateTime.now().toIso8601String(),
      
      // Metadatos del response
      'fuenteDatos': 'endpoint_iniciar_sesion',
      'message_Status': data['message_Status'] ?? 'Información obtenida',
    };
  }
  
  /// Método fallback que usa endpoints existentes cuando no hay credenciales
  Future<Map<String, dynamic>?> _obtenerInformacionFallback() async {
    try {
      developer.log('=== USANDO MÉTODO FALLBACK ===');
      
      // Obtener datos base del usuario guardados
      final userData = await obtenerDatosUsuario();
      if (userData == null) {
        developer.log('No hay datos de usuario guardados');
        return null;
      }

      final usuaId = userData['usua_Id'];
      final personaId = userData['usua_IdPersona'];
      
      if (usuaId == null) {
        developer.log('No se encontró usua_Id en los datos guardados');
        return null;
      }

      developer.log('Obteniendo datos completos para usuaId: $usuaId, personaId: $personaId');
      
      // Obtener datos completos del usuario desde /Usuarios/Listar
      final datosCompletos = await obtenerDatosCompletoUsuario(usuaId);
      
      if (datosCompletos == null) {
        developer.log('No se pudieron obtener datos completos del usuario');
        return null;
      }
      
      developer.log('Datos completos obtenidos: ${datosCompletos.keys.length} campos');
      
      // Obtener datos del vendedor si es vendedor
      Map<String, dynamic>? datosVendedor;
      if (personaId != null && userData['usua_EsVendedor'] == true) {
        developer.log('Usuario es vendedor, obteniendo datos del vendedor...');
        datosVendedor = await buscarDatosVendedor(personaId);
        
        if (datosVendedor != null) {
          developer.log('Datos del vendedor obtenidos: ${datosVendedor.keys.length} campos');
        } else {
          developer.log('No se pudieron obtener datos del vendedor');
        }
      }
      
      // Construir información completa combinando ambas fuentes
      final informacionCompleta = {
        // Información básica del usuario
        'telefono': datosCompletos['telefono'] ?? 
                   datosVendedor?['vend_Telefono'] ?? 
                   userData['telefono'] ?? 'Sin información',
        'correo': datosCompletos['correo'] ?? 
                 datosVendedor?['vend_Correo'] ?? 
                 userData['correo'] ?? 'Sin información',
        'nombres': datosCompletos['nombres'] ?? 
                  datosVendedor?['vend_Nombres'] ?? 
                  userData['nombres'] ?? 'Sin información',
        'apellidos': datosCompletos['apellidos'] ?? 
                    datosVendedor?['vend_Apellidos'] ?? 
                    userData['apellidos'] ?? 'Sin información',
        'dni': datosCompletos['dni'] ?? 
              datosVendedor?['vend_DNI'] ?? 
              userData['dni'] ?? 'Sin información',
        'cargo': datosCompletos['cargo'] ?? 
                userData['cargo'] ?? 
                userData['role_Descripcion'] ?? 'Sin información',
        
        // Información de asignación laboral
        'rutaAsignada': datosCompletos['sucursal'] ?? 
                       datosVendedor?['sucu_Descripcion'] ?? 
                       userData['sucursal'] ?? 'Sin información',
        'supervisor': datosVendedor?['nombreSupervisor'] != null && datosVendedor?['apellidoSupervisor'] != null
                     ? '${datosVendedor!['nombreSupervisor']} ${datosVendedor['apellidoSupervisor']}'
                     : datosVendedor?['vend_Supervisor']?.toString() ?? 'Sin información',
        
        // Información operativa (se calculará desde datos locales)
        'cantidadInventario': '0', // Se calculará desde productos en caché
        'fechaConsulta': DateTime.now().toIso8601String(),
        
        // Campos adicionales útiles
        'codigo': datosVendedor?['vend_Codigo'] ?? userData['usua_Id']?.toString() ?? 'Sin información',
        'direccionExacta': datosVendedor?['vend_DireccionExacta'] ?? 'Sin información',
        'sucursalId': datosVendedor?['sucu_Id']?.toString() ?? 'Sin información',
        'vendedorId': datosVendedor?['vend_Id']?.toString() ?? 'Sin información',
        
        // Metadatos
        'fuenteDatos': 'endpoints_fallback',
      };
      
      developer.log('✓ Información completa construida con fallback');
      developer.log('Campos disponibles: ${informacionCompleta.keys.join(', ')}');
      
      return informacionCompleta;
      
    } catch (e) {
      developer.log('✗ Error en método fallback: $e');
      return null;
    }
  }

  /// Obtiene información específica usando el endpoint completo
  /// Campos: telefono, correo, rutaAsignada, supervisor
  Future<Map<String, String>> obtenerCamposEspecificos() async {
    try {
      final informacionCompleta = await obtenerInformacionCompletaUsuario();
      
      if (informacionCompleta != null) {
        return {
          'telefono': informacionCompleta['telefono']?.toString() ?? 'Sin información',
          'correo': informacionCompleta['correo']?.toString() ?? 'Sin información',
          'rutaAsignada': informacionCompleta['rutaAsignada']?.toString() ?? 'Sin información',
          'supervisor': informacionCompleta['supervisor']?.toString() ?? 'Sin información',
        };
      }
      
      // Fallback a datos locales si no hay conexión
      final userData = await obtenerDatosUsuario();
      if (userData != null) {
        return {
          'telefono': userData['telefono']?.toString() ?? 'Sin información',
          'correo': userData['correo']?.toString() ?? 'Sin información', 
          'rutaAsignada': userData['sucursal']?.toString() ?? 'Sin información',
          'supervisor': 'Sin información', // No disponible en datos locales
        };
      }
      
      return {
        'telefono': 'Sin información',
        'correo': 'Sin información',
        'rutaAsignada': 'Sin información',
        'supervisor': 'Sin información',
      };
    } catch (e) {
      developer.log('Error en obtenerCamposEspecificos: $e');
      return {
        'telefono': 'Error al obtener',
        'correo': 'Error al obtener',
        'rutaAsignada': 'Error al obtener',
        'supervisor': 'Error al obtener',
      };
    }
  }
}