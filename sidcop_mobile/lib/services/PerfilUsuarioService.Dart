import 'dart:convert';
import 'dart:convert' show utf8;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/GlobalService.dart';

class PerfilUsuarioService {
  static const String _userDataKey = 'user_data';
  final String _apiServer = apiServer;
  final String _apiKey = apikey;
  
  /// Filtra los datos del usuario para mantener solo los campos necesarios
  /// y formatear los valores de manera consistente
  Map<String, dynamic> _filtrarDatosUsuario(Map<String, dynamic> userData) {
    try {
      if (userData.isEmpty) return {};
      
      final Map<String, dynamic> datosFiltrados = {};
      
      // Lista de campos que queremos mantener
      final camposPermitidos = {
        'code_Status', 'message_Status', 'usua_Id', 'usua_Usuario', 'usua_Clave',
        'role_Descripcion', 'cargo', 'dni', 'correo', 'telefono', 'personaId',
        'imagen', 'nombres', 'apellidos', 'sucursal', 'role_Id', 'usua_IdPersona',
        'usua_EsVendedor', 'usua_EsAdmin', 'usua_Imagen', 'usua_Creacion',
        'usua_FechaCreacion', 'usua_Modificacion', 'usua_FechaModificacion',
        'usua_Estado', 'permisosJson', 'nombreCompleto', 'datosVendedor',
        'email', 'usua_Correo', 'usua_Telefono', 'usua_Estado', 'usua_EsActivo'
      };
      
      // Filtrar solo los campos permitidos y asegurar tipos de datos consistentes
      userData.forEach((key, value) {
        if (value != null && camposPermitidos.contains(key)) {
          // Convertir a String si es necesario para campos de texto
          if (value is num || value is bool) {
            datosFiltrados[key] = value;
          } else if (value is String) {
            datosFiltrados[key] = value.trim();
          } else if (value is Map || value is List) {
            // Mantener estructuras complejas como están
            datosFiltrados[key] = value;
          } else if (value != null) {
            // Convertir cualquier otro tipo a String
            datosFiltrados[key] = value.toString();
          }
        }
      });
      
      // Asegurar que los campos comunes tengan valores por defecto si no están presentes
      if (!datosFiltrados.containsKey('nombres')) {
        datosFiltrados['nombres'] = '';
      }
      
      if (!datosFiltrados.containsKey('apellidos')) {
        datosFiltrados['apellidos'] = '';
      }
      
      // Generar nombreCompleto si no existe
      if (!datosFiltrados.containsKey('nombreCompleto')) {
        final nombres = datosFiltrados['nombres']?.toString() ?? '';
        final apellidos = datosFiltrados['apellidos']?.toString() ?? '';
        
        if (nombres.isNotEmpty || apellidos.isNotEmpty) {
          datosFiltrados['nombreCompleto'] = '$nombres $apellidos'.trim();
        } else {
          datosFiltrados['nombreCompleto'] = datosFiltrados['usua_Usuario'] ?? 'Usuario';
        }
      }
      
      // Si hay datos del vendedor, también filtrarlos
      if (datosFiltrados['datosVendedor'] != null && 
          datosFiltrados['datosVendedor'] is Map) {
        try {
          datosFiltrados['datosVendedor'] = _filtrarDatosVendedor(
            Map<String, dynamic>.from(datosFiltrados['datosVendedor'])
          );
        } catch (e) {
          developer.log('Error al filtrar datos del vendedor: $e');
          // Eliminar datos de vendedor inválidos
          datosFiltrados.remove('datosVendedor');
        }
      }
      
      return datosFiltrados;
      
    } catch (e, stackTrace) {
      developer.log('Error en _filtrarDatosUsuario', 
                   error: e, 
                   stackTrace: stackTrace);
      // Devolver un mapa vacío en caso de error para evitar problemas con el flujo
      return {};
    }
  }
  
  /// Filtra los datos del vendedor para mantener solo los campos necesarios
  /// y formatear los valores de manera consistente
  Map<String, dynamic> _filtrarDatosVendedor(Map<String, dynamic> datosVendedor) {
    try {
      if (datosVendedor.isEmpty) return {};
      
      final Map<String, dynamic> vendedorFiltrado = {};
      
      // Lista de campos del vendedor que queremos mantener
      final camposVendedorPermitidos = {
        'vend_Id', 'vend_Codigo', 'vend_DNI', 'vend_Nombres', 'vend_Apellidos',
        'vend_Telefono', 'vend_Correo', 'vend_Sexo', 'vend_DireccionExacta',
        'sucu_Id', 'colo_Id', 'vend_Supervisor', 'vend_Ayudante', 'vend_Tipo',
        'vend_EsExterno', 'vend_Estado', 'usua_Creacion', 'vend_FechaCreacion',
        'usua_Modificacion', 'vend_FechaModificacion', 'vend_EsActivo',
        'sucursal', 'colonia', 'supervisor', 'ayudante', 'tipoVendedor',
        'foto', 'firma', 'coordenadas', 'fechaNacimiento', 'fechaIngreso',
        'fechaSalida', 'estadoCivil', 'nacionalidad', 'tipoSangre', 'licenciaConducir',
        'vencimientoLicencia', 'seguroSocial', 'rfc', 'curp', 'contactoEmergencia',
        'telefonoEmergencia', 'parentescoEmergencia', 'comentarios', 'estatus',
        'fechaInicio', 'fechaFin', 'motivoBaja', 'usuarioBaja', 'fechaBaja',
        'esActivo', 'usuarioCreacion', 'usuarioModificacion', 'fechaModificacion'
      };
      
      // Filtrar solo los campos permitidos y asegurar tipos de datos consistentes
      datosVendedor.forEach((key, value) {
        if (value != null && camposVendedorPermitidos.contains(key)) {
          // Convertir a String si es necesario para campos de texto
          if (value is num || value is bool) {
            vendedorFiltrado[key] = value;
          } else if (value is String) {
            vendedorFiltrado[key] = value.trim();
          } else if (value is Map || value is List) {
            // Mantener estructuras complejas como están
            vendedorFiltrado[key] = value;
          } else if (value != null) {
            // Convertir cualquier otro tipo a String
            vendedorFiltrado[key] = value.toString();
          }
        }
      });
      
      // Asegurar que los campos comunes tengan valores por defecto si no están presentes
      if (!vendedorFiltrado.containsKey('vend_Nombres')) {
        vendedorFiltrado['vend_Nombres'] = '';
      }
      
      if (!vendedorFiltrado.containsKey('vend_Apellidos')) {
        vendedorFiltrado['vend_Apellidos'] = '';
      }
      
      // Generar nombre completo si no existe
      if (!vendedorFiltrado.containsKey('nombreCompleto')) {
        final nombres = vendedorFiltrado['vend_Nombres']?.toString() ?? '';
        final apellidos = vendedorFiltrado['vend_Apellidos']?.toString() ?? '';
        
        if (nombres.isNotEmpty || apellidos.isNotEmpty) {
          vendedorFiltrado['nombreCompleto'] = '$nombres $apellidos'.trim();
        } else {
          vendedorFiltrado['nombreCompleto'] = 'Vendedor';
        }
      }
      
      return vendedorFiltrado;
      
    } catch (e, stackTrace) {
      developer.log('Error en _filtrarDatosVendedor', 
                   error: e, 
                   stackTrace: stackTrace);
      // Devolver un mapa vacío en caso de error para evitar problemas con el flujo
      return {};
    }
  }
  
  /// Obtiene los datos del usuario desde el almacenamiento local
  /// 
  /// Retorna un Map con los datos del usuario o null si no hay datos disponibles
  /// o si ocurre un error al obtenerlos.
  Future<Map<String, dynamic>?> obtenerDatosUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Intentar obtener los datos de ambas fuentes posibles
      String? userDataJson = prefs.getString('offline_user_data') ?? 
                           prefs.getString('user_data');
      
      if (userDataJson == null || userDataJson.isEmpty) {
        developer.log('No se encontraron datos de usuario en el almacenamiento local');
        return null;
      }
      
      // Decodificar los datos JSON
      final dynamic decodedData = jsonDecode(userDataJson);
      
      // Verificar que los datos decodificados son un Map
      if (decodedData is! Map<String, dynamic>) {
        developer.log('Los datos del usuario no tienen el formato esperado');
        return null;
      }
      
      // Filtrar los datos para eliminar campos innecesarios
      return _filtrarDatosUsuario(decodedData);
      
    } catch (e, stackTrace) {
      developer.log('Error al obtener datos del usuario', 
                   error: e, 
                   stackTrace: stackTrace);
      return null;
    }
  }

  /// Limpia todos los datos del usuario del almacenamiento local
  Future<void> limpiarDatosUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Eliminar todos los datos relacionados con el usuario
      await prefs.remove('offline_user_data');
      await prefs.remove('user_data');
      
      // Limpiar también las credenciales de sesión
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.remove('remember_me');
      
      developer.log('Datos de usuario y credenciales eliminados del almacenamiento local');
    } catch (e) {
      developer.log('Error al limpiar datos del usuario: $e');
      // No relanzamos la excepción para evitar bloquear el flujo de la aplicación
      // en caso de error al limpiar los datos
    }
  }

  /// Obtiene los datos completos del usuario desde el servidor por su ID
  /// 
  /// [usuaId] El ID del usuario cuyos datos se desean obtener
  /// Retorna un Map con los datos del usuario o null si no se encuentra o hay un error
  Future<Map<String, dynamic>?> obtenerDatosCompletoUsuario(int usuaId) async {
    if (usuaId <= 0) {
      developer.log('ID de usuario inválido: $usuaId');
      return null;
    }
    
    try {
      final url = Uri.parse('$_apiServer/Usuarios/Listar');
      developer.log('Obteniendo datos completos del usuario ID: $usuaId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': _apiKey,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          developer.log('Tiempo de espera agotado al obtener datos del usuario');
          return http.Response(
            'Error: Tiempo de espera agotado',
            408, // Request Timeout
          );
        },
      );
      
      developer.log('Usuarios/Listar Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final dynamic responseData = jsonDecode(utf8.decode(response.bodyBytes));
          List<dynamic> usuarios;
          
          // Verificar si la respuesta es directamente un array o un objeto con 'data'
          if (responseData is List) {
            usuarios = responseData;
          } else if (responseData is Map && responseData['data'] != null) {
            usuarios = responseData['data'] is List ? responseData['data'] : [responseData['data']];
          } else if (responseData is Map && responseData['usua_Id'] != null) {
            // Si es un solo usuario, lo convertimos a lista
            usuarios = [responseData];
          } else {
            developer.log('Estructura de respuesta no reconocida');
            return null;
          }
          
          if (usuarios.isEmpty) {
            developer.log('La lista de usuarios está vacía');
            return null;
          }
          
          // Buscar el usuario con el usua_Id específico
          for (var usuario in usuarios) {
            try {
              final usuarioId = usuario is Map ? 
                (usuario['usua_Id'] is int ? 
                  usuario['usua_Id'] : 
                  int.tryParse(usuario['usua_Id']?.toString() ?? '')) : 
                null;
                
              if (usuarioId == usuaId) {
                developer.log('Usuario con ID $usuaId encontrado');
                // Filtrar los datos del usuario antes de retornarlos
                return _filtrarDatosUsuario(Map<String, dynamic>.from(usuario));
              }
            } catch (e) {
              developer.log('Error procesando usuario en la lista: $e');
              continue;
            }
          }
          
          developer.log('Usuario con ID $usuaId no encontrado en la lista');
          return null;
          
        } catch (e, stackTrace) {
          developer.log('Error al procesar la respuesta del servidor', 
                       error: e, 
                       stackTrace: stackTrace);
          return null;
        }
      } else {
        developer.log('Error obteniendo lista de usuarios. Código: ${response.statusCode}');
        developer.log('Respuesta del servidor: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('Error en obtenerDatosCompletoUsuario', 
                   error: e, 
                   stackTrace: stackTrace);
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
        
        if (datosCompletos != null) {
          // Combinar los datos del usuario con los datos completos
          userData.addAll(datosCompletos);
          
          // Verificar si el usuario es vendedor
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
      
      // Guardar permisosJson original si existe
      final permisosOriginal = userData['permisosJson'];
      
      // Limpiar campos de navegación antes de guardar
      final userDataLimpio = limpiarNavegaciones(Map<String, dynamic>.from(userData));
      
      // Si teníamos permisos originales, asegurarnos de que se guarden correctamente
      if (permisosOriginal != null) {
        userDataLimpio['permisosJson'] = permisosOriginal;
      }
      
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
      
      // Verificar si los datos se guardaron correctamente
      final savedData = prefs.getString(_userDataKey);
      if (savedData == null || savedData.isEmpty) {
        throw Exception('No se pudieron guardar los datos del usuario');
      }
    } catch (e) {
      developer.log('Error al guardar datos del usuario: $e');
      rethrow;
    }
  }
  
  // Obtener campos específicos del usuario mapeados desde la respuesta del API
  Future<String> obtenerNombreCompleto() async {
    try {
      final userData = await obtenerDatosUsuario();
      if (userData == null) return 'No disponible';
      
      // Mapear desde los campos del API response
      return userData['nombreCompleto'] ?? 
             userData['usua_Usuario'] ?? 
             userData['usuario'] ?? 
             'No disponible';
    } catch (e) {
      developer.log('Error en obtenerNombreCompleto: $e');
      return 'No disponible';
    }
  }
  
  // Obtener nombre completo desde campos nombres y apellidos
  Future<String> obtenerNombreDesdeNombresApellidos() async {
    try {
      final userData = await obtenerDatosUsuario();
      if (userData == null) return 'No disponible';
      
      final nombres = userData['nombres']?.toString() ?? '';
      final apellidos = userData['apellidos']?.toString() ?? '';
      
      if (nombres.isNotEmpty && apellidos.isNotEmpty) {
        return '$nombres $apellidos';
      } else if (nombres.isNotEmpty) {
        return nombres;
      } else if (apellidos.isNotEmpty) {
        return apellidos;
      }
      
      // Fallback a otros campos si nombres y apellidos no están disponibles
      return userData['nombreCompleto']?.toString() ?? 
             userData['usua_Usuario']?.toString() ?? 
             'No disponible';
    } catch (e) {
      developer.log('Error en obtenerNombreDesdeNombresApellidos: $e');
      return 'No disponible';
    }
  }

Future<String> obtenerNumeroIdentidad() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['dni']?.toString() ?? 
           userData['usua_DNI']?.toString() ?? 
           userData['identificacion']?.toString() ?? 
           userData['documento']?.toString() ?? 
           'No disponible';
  } catch (e) {
    developer.log('Error en obtenerNumeroIdentidad: $e');
    return 'No disponible';
  }
}

Future<String> obtenerNumeroEmpleado() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['numeroEmpleado']?.toString() ?? 
           userData['usua_CodigoEmpleado']?.toString() ?? 
           userData['codigoEmpleado']?.toString() ?? 
           userData['empleadoId']?.toString() ?? 
           'No disponible';
  } catch (e) {
    developer.log('Error en obtenerNumeroEmpleado: $e');
    return 'No disponible';
  }
}

Future<String> obtenerCorreoElectronico() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['correoElectronico']?.toString() ?? 
           userData['usua_Correo']?.toString() ?? 
           userData['correo']?.toString() ?? 
           userData['email']?.toString() ?? 
           'No disponible';
  } catch (e) {
    developer.log('Error en obtenerCorreoElectronico: $e');
    return 'No disponible';
  }
}

Future<String> obtenerTelefono() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['telefono']?.toString() ?? 
           userData['usua_Telefono']?.toString() ?? 
           userData['celular']?.toString() ?? 
           userData['numeroTelefono']?.toString() ?? 
           'No disponible';
  } catch (e) {
    developer.log('Error en obtenerTelefono: $e');
    return 'No disponible';
  }
}

Future<String> obtenerCargo() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return 'No disponible';
    
    // Mapear desde los campos del API response
    return userData['cargo']?.toString() ?? 
           userData['usua_Cargo']?.toString() ?? 
           userData['puesto']?.toString() ?? 
           userData['role_Descripcion']?.toString() ?? 
           'No disponible';
  } catch (e) {
    developer.log('Error en obtenerCargo: $e');
    return 'No disponible';
  }
}

Future<String?> obtenerImagenUsuario() async {
  try {
    final userData = await obtenerDatosUsuario();
    if (userData == null) return null;
    
    // Mapear desde los campos del API response
    final dynamic imagen = userData['usua_Imagen'] ?? 
                          userData['imagen'] ?? 
                          userData['foto'];
    
    // Verificar que la imagen no sea null, vacía o 'string' (valor por defecto)
    if (imagen == null || imagen.toString().isEmpty || imagen.toString().toLowerCase() == 'string') {
      return null;
    }
    
    return imagen.toString();
  } catch (e) {
    developer.log('Error en obtenerImagenUsuario: $e');
    return null;
  }

  // Método para debug - mostrar todos los campos disponibles
  Future<void> mostrarCamposDisponibles() async {
    try {
      final userData = await obtenerDatosUsuario();
      if (userData == null) {
        print('No hay datos de usuario disponibles');
        return;
      }
      
      print('=== CAMPOS DISPONIBLES ===');
      userData.forEach((key, value) {
        print('$key: $value (${value?.runtimeType})');
      });
    } catch (e) {
      developer.log('Error en mostrarCamposDisponibles: $e');
      print('Error al mostrar campos disponibles: $e');
    }
  }
}