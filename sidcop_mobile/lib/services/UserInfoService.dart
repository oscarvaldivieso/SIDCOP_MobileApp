import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/InicioSesion_OfflineService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';

/// Servicio completo para manejo de información de usuario
/// Funciona offline-first con sincronización automática cuando hay internet
class UserInfoService extends ChangeNotifier {
  static final UserInfoService _instance = UserInfoService._internal();
  factory UserInfoService() => _instance;
  UserInfoService._internal();

  // Controladores de stream para notificar cambios
  final StreamController<Map<String, dynamic>> _userDataController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectivityController = 
      StreamController<bool>.broadcast();

  // Estado interno
  Map<String, dynamic>? _cachedUserData;
  bool _isConnected = false;
  bool _isLoading = false;
  Timer? _syncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Getters públicos
  Stream<Map<String, dynamic>> get userDataStream => _userDataController.stream;
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get cachedUserData => _cachedUserData;

  /// Inicializa el servicio y comienza el monitoreo
  Future<void> initialize() async {
    print('=== INICIALIZANDO UserInfoService ===');
    
    // Cargar datos desde caché local
    await _loadFromCache();
    
    // Iniciar monitoreo de conectividad
    await _initConnectivityMonitoring();
    
    // Configurar sincronización automática cada 5 minutos
    _setupAutoSync();
    
    print('UserInfoService inicializado correctamente');
  }

  /// Carga datos desde el caché local (FlutterSecureStorage)
  Future<void> _loadFromCache() async {
    try {
      print('Cargando datos desde caché local...');
      
      // Obtener diccionario completo de usuario desde InicioSesion_OfflineService
      final diccionarioUsuario = await InicioSesionOfflineService.obtenerDiccionarioUsuario();
      
      if (diccionarioUsuario != null) {
        _cachedUserData = diccionarioUsuario;
        
        // Completar datos faltantes desde el sistema offline
        await _completarDatosDesdeOffline();
        
        print('✓ Datos cargados desde caché: ${_cachedUserData!.keys.length} campos');
        
        // Notificar a los listeners
        _userDataController.add(_cachedUserData!);
        notifyListeners();
      } else {
        print('⚠ No hay datos en caché local, generando desde offline...');
        await _generarDatosDesdeOffline();
      }
    } catch (e) {
      print('✗ Error cargando desde caché: $e');
      await _generarDatosDesdeOffline();
    }
  }

  /// Completa datos faltantes desde el sistema offline
  Future<void> _completarDatosDesdeOffline() async {
    try {
      // Obtener datos base del usuario desde InicioSesion_OfflineService
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      
      if (userData != null) {
        // Completar correo y teléfono usando los métodos del InicioSesion_OfflineService
        if (_cachedUserData!['correo'] == null || _cachedUserData!['correo'] == 'Sin información') {
          _cachedUserData!['correo'] = InicioSesionOfflineService.extraerCorreo(userData);
        }
        
        if (_cachedUserData!['telefono'] == null || _cachedUserData!['telefono'] == 'Sin información') {
          _cachedUserData!['telefono'] = InicioSesionOfflineService.extraerTelefono(userData);
        }
      }
      
      // Obtener información operativa actualizada
      final infoOperativa = await InicioSesionOfflineService.obtenerInformacionOperativa();
      _cachedUserData!.addAll(infoOperativa);
      
    } catch (e) {
      print('Error completando datos desde offline: $e');
    }
  }

  /// Genera datos completos desde el sistema offline cuando no hay diccionario
  Future<void> _generarDatosDesdeOffline() async {
    try {
      // Regenerar el diccionario completo
      await InicioSesionOfflineService.generarYGuardarDiccionarioUsuario();
      
      // Intentar cargar nuevamente
      final diccionarioUsuario = await InicioSesionOfflineService.obtenerDiccionarioUsuario();
      
      if (diccionarioUsuario != null) {
        _cachedUserData = diccionarioUsuario;
        await _completarDatosDesdeOffline();
        _userDataController.add(_cachedUserData!);
      } else {
        _cachedUserData = _getDefaultUserData();
        _userDataController.add(_cachedUserData!);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error generando datos desde offline: $e');
      _cachedUserData = _getDefaultUserData();
      _userDataController.add(_cachedUserData!);
      notifyListeners();
    }
  }

  /// Datos por defecto cuando no hay información disponible
  Map<String, dynamic> _getDefaultUserData() {
    return {
      'nombreCompleto': 'Sin información',
      'numeroIdentidad': 'Sin información',
      'numeroEmpleado': 'Sin información',
      'correo': 'Sin información',
      'telefono': 'Sin información',
      'cargo': 'Sin información',
      'rutaAsignada': 'Sin información',
      'supervisorResponsable': 'Sin información',
      'inventarioAsignado': '0',
      'clientesAsignados': '0',
      'ventasDelMes': 'L.0.00',
      'ultimaRecargaSolicitada': 'Sin información',
      'fechaGeneracion': DateTime.now().toIso8601String(),
    };
  }

  /// Inicializa el monitoreo de conectividad
  Future<void> _initConnectivityMonitoring() async {
    try {
      // Verificar estado inicial
      final connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = connectivityResult != ConnectivityResult.none;
      _connectivityController.add(_isConnected);
      
      print('Estado inicial de conectividad: ${_isConnected ? "Conectado" : "Desconectado"}');
      
      // Escuchar cambios de conectividad
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (ConnectivityResult result) async {
          final wasConnected = _isConnected;
          _isConnected = result != ConnectivityResult.none;
          
          print('Cambio de conectividad: ${_isConnected ? "Conectado" : "Desconectado"}');
          
          _connectivityController.add(_isConnected);
          notifyListeners();
          
          // Si acabamos de conectarnos, sincronizar inmediatamente
          if (!wasConnected && _isConnected) {
            print('Conexión restaurada - iniciando sincronización...');
            await syncWithAPI();
          }
        },
      );
    } catch (e) {
      print('Error inicializando monitoreo de conectividad: $e');
      _isConnected = false;
    }
  }

  /// Configura la sincronización automática
  void _setupAutoSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isConnected) {
        print('Sincronización automática programada ejecutándose...');
        syncWithAPI();
      }
    });
  }

  /// Sincroniza datos con la API cuando hay conexión
  Future<bool> syncWithAPI() async {
    if (!_isConnected) {
      print('Sin conexión - omitiendo sincronización con API');
      return false;
    }

    if (_isLoading) {
      print('Sincronización ya en progreso - omitiendo');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();
      
      print('=== INICIANDO SINCRONIZACIÓN CON API ===');
      
      // Obtener datos actualizados desde la API
      final perfilService = PerfilUsuarioService();
      
      // NUEVO: Intentar obtener información completa desde el endpoint /Usuarios/IniciarSesion
      print('Obteniendo información completa desde endpoint /Usuarios/IniciarSesion...');
      final informacionCompleta = await perfilService.obtenerInformacionCompletaUsuario();
      
      Map<String, dynamic> updatedData;
      
      if (informacionCompleta != null) {
        print('✓ Información completa obtenida - Fuente: ${informacionCompleta['fuenteDatos']}');
        
        // Usar datos del endpoint completo (ya sea del endpoint o fallback)
        updatedData = Map<String, dynamic>.from(_cachedUserData ?? {});
        updatedData.addAll({
          'nombreCompleto': '${informacionCompleta['nombres']} ${informacionCompleta['apellidos']}',
          'numeroIdentidad': informacionCompleta['dni'],
          'numeroEmpleado': informacionCompleta['codigo'],
          'correo': informacionCompleta['correo'],
          'telefono': informacionCompleta['telefono'],
          'cargo': informacionCompleta['cargo'],
          'rutaAsignada': informacionCompleta['rutaAsignada'],
          'supervisorResponsable': informacionCompleta['supervisor'],
          'inventarioAsignado': informacionCompleta['cantidadInventario'],
          'fechaUltimaSync': DateTime.now().toIso8601String(),
          'fuenteUltimaSync': informacionCompleta['fuenteDatos'] ?? 'desconocida',
        });
        
        print('✓ Datos actualizados:');
        print('  - rutaAsignada: ${updatedData['rutaAsignada']}');
        print('  - supervisorResponsable: ${updatedData['supervisorResponsable']}');
        print('  - correo: ${updatedData['correo']}');
        print('  - telefono: ${updatedData['telefono']}');
        
      } else {
        print('⚠ Usando método fallback mejorado');
        // Método fallback mejorado que combina múltiples fuentes
        final nombreCompleto = await perfilService.obtenerNombreCompleto();
        final numeroIdentidad = await perfilService.obtenerNumeroIdentidad();
        final numeroEmpleado = await perfilService.obtenerNumeroEmpleado();
        final cargo = await perfilService.obtenerCargo();
        final imagenUsuario = await perfilService.obtenerImagenUsuario();
        
        // Obtener correo y teléfono con métodos mejorados
        final correo = await _obtenerCorreoMejorado();
        final telefono = await _obtenerTelefonoMejorado();
        final rutaAsignada = await _obtenerRutaAsignadaMejorada();
        final supervisor = await _obtenerSupervisorMejorado();
        
        // Crear datos actualizados
        updatedData = Map<String, dynamic>.from(_cachedUserData ?? {});
        updatedData.addAll({
          'nombreCompleto': nombreCompleto,
          'numeroIdentidad': numeroIdentidad,
          'numeroEmpleado': numeroEmpleado,
          'correo': correo,
          'telefono': telefono,
          'cargo': cargo,
          'rutaAsignada': rutaAsignada,
          'supervisorResponsable': supervisor,
          'imagenUsuario': imagenUsuario,
          'fechaUltimaSync': DateTime.now().toIso8601String(),
          'fuenteUltimaSync': 'metodos_fallback_mejorados',
        });
      }
      
      // Obtener información operativa actualizada desde el sistema offline
      final infoOperativa = await InicioSesionOfflineService.obtenerInformacionOperativa();
      updatedData.addAll(infoOperativa);
      
      // Actualizar caché local
      _cachedUserData = updatedData;
      
      // Regenerar diccionario en InicioSesion_OfflineService
      await InicioSesionOfflineService.generarYGuardarDiccionarioUsuario();
      
      // Notificar cambios
      _userDataController.add(_cachedUserData!);
      notifyListeners();
      
      print('✓ Sincronización con API completada exitosamente');
      return true;
      
    } catch (e) {
      print('✗ Error en sincronización con API: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fuerza una recarga completa de datos
  Future<void> forceRefresh() async {
    print('=== FORZANDO RECARGA COMPLETA ===');
    
    if (_isConnected) {
      // Si hay conexión, sincronizar con API
      await syncWithAPI();
    } else {
      // Si no hay conexión, recargar desde caché
      await _loadFromCache();
    }
  }

  /// Obtiene un campo específico de los datos del usuario
  String getUserField(String fieldName, {String defaultValue = 'Sin información'}) {
    if (_cachedUserData == null) return defaultValue;
    
    final value = _cachedUserData![fieldName];
    if (value == null || value.toString().isEmpty) return defaultValue;
    
    return value.toString();
  }

  /// Verifica si los datos están actualizados (menos de 1 hora)
  bool isDataFresh() {
    if (_cachedUserData == null) return false;
    
    try {
      final fechaGeneracion = _cachedUserData!['fechaGeneracion'];
      if (fechaGeneracion == null) return false;
      
      final fecha = DateTime.parse(fechaGeneracion.toString());
      final diferencia = DateTime.now().difference(fecha);
      
      return diferencia.inHours < 1;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el estado completo del servicio
  Map<String, dynamic> getServiceStatus() {
    return {
      'isConnected': _isConnected,
      'isLoading': _isLoading,
      'hasData': _cachedUserData != null,
      'isDataFresh': isDataFresh(),
      'lastUpdate': _cachedUserData?['fechaGeneracion'],
      'dataFields': _cachedUserData?.keys.length ?? 0,
    };
  }

  /// Limpia todos los datos y reinicia el servicio
  Future<void> clearAndReset() async {
    print('Limpiando datos y reiniciando servicio...');
    
    _cachedUserData = null;
    await InicioSesionOfflineService.limpiarCache();
    await initialize();
  }

  /// Obtiene correo desde userData o servicio de perfil
  Future<String> obtenerCorreo() async {
    try {
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        return InicioSesionOfflineService.extraerCorreo(userData);
      }
      
      // NUEVO: Intentar obtener desde endpoint completo si hay conexión
      if (_isConnected) {
        final perfilService = PerfilUsuarioService();
        final camposEspecificos = await perfilService.obtenerCamposEspecificos();
        final correoEndpoint = camposEspecificos['correo'];
        
        if (correoEndpoint != null && correoEndpoint != 'Sin información' && correoEndpoint != 'Error al obtener') {
          return correoEndpoint;
        }
      }
      
      // Fallback al servicio de perfil tradicional
      final perfilService = PerfilUsuarioService();
      final perfil = await perfilService.obtenerDatosUsuario();
      
      if (perfil != null && perfil.isNotEmpty) {
        return perfil['correo']?.toString() ?? 'Sin información';
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error obteniendo correo: $e');
      return 'Sin información';
    }
  }

  /// Obtiene teléfono desde userData o servicio de perfil
  Future<String> obtenerTelefono() async {
    try {
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        return InicioSesionOfflineService.extraerTelefono(userData);
      }
      
      // NUEVO: Intentar obtener desde endpoint completo si hay conexión
      if (_isConnected) {
        final perfilService = PerfilUsuarioService();
        final camposEspecificos = await perfilService.obtenerCamposEspecificos();
        final telefonoEndpoint = camposEspecificos['telefono'];
        
        if (telefonoEndpoint != null && telefonoEndpoint != 'Sin información' && telefonoEndpoint != 'Error al obtener') {
          return telefonoEndpoint;
        }
      }
      
      // Fallback al servicio de perfil tradicional
      final perfilService = PerfilUsuarioService();
      final perfil = await perfilService.obtenerDatosUsuario();
      
      if (perfil != null && perfil.isNotEmpty) {
        return perfil['telefono']?.toString() ?? 'Sin información';
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error obteniendo teléfono: $e');
      return 'Sin información';
    }
  }

  /// Obtiene la ruta asignada usando el nuevo endpoint cuando hay conexión
  Future<String> obtenerRutaAsignada() async {
    try {
      // NUEVO: Intentar obtener desde endpoint completo si hay conexión
      if (_isConnected) {
        final perfilService = PerfilUsuarioService();
        final camposEspecificos = await perfilService.obtenerCamposEspecificos();
        final rutaEndpoint = camposEspecificos['rutaAsignada'];
        
        if (rutaEndpoint != null && rutaEndpoint != 'Sin información' && rutaEndpoint != 'Error al obtener') {
          return rutaEndpoint;
        }
      }
      
      // Fallback a datos locales
      return getUserField('rutaAsignada');
    } catch (e) {
      print('Error obteniendo ruta asignada: $e');
      return 'Sin información';
    }
  }

  /// Obtiene el supervisor responsable usando el nuevo endpoint cuando hay conexión
  Future<String> obtenerSupervisorResponsable() async {
    try {
      // NUEVO: Intentar obtener desde endpoint completo si hay conexión
      if (_isConnected) {
        final perfilService = PerfilUsuarioService();
        final camposEspecificos = await perfilService.obtenerCamposEspecificos();
        final supervisorEndpoint = camposEspecificos['supervisor'];
        
        if (supervisorEndpoint != null && supervisorEndpoint != 'Sin información' && supervisorEndpoint != 'Error al obtener') {
          return supervisorEndpoint;
        }
      }
      
      // Fallback a datos locales
      return getUserField('supervisorResponsable');
    } catch (e) {
      print('Error obteniendo supervisor responsable: $e');
      return 'Sin información';
    }
  }

  /// Método de sincronización silenciosa para uso en segundo plano
  Future<bool> silentSync() async {
    if (!_isConnected || _isLoading) {
      return false;
    }

    try {
      print('Sincronización silenciosa iniciada...');
      
      final perfilService = PerfilUsuarioService();
      final informacionCompleta = await perfilService.obtenerInformacionCompletaUsuario();
      
      if (informacionCompleta != null) {
        final updatedData = Map<String, dynamic>.from(_cachedUserData ?? {});
        updatedData.addAll({
          'correo': informacionCompleta['correo'],
          'telefono': informacionCompleta['telefono'],
          'rutaAsignada': informacionCompleta['rutaAsignada'],
          'supervisorResponsable': informacionCompleta['supervisor'],
          'inventarioAsignado': informacionCompleta['cantidadInventario'],
          'fechaUltimaSync': DateTime.now().toIso8601String(),
        });
        
        _cachedUserData = updatedData;
        _userDataController.add(_cachedUserData!);
        
        print('✓ Sincronización silenciosa completada');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error en sincronización silenciosa: $e');
      return false;
    }
  }

  /// Obtiene correo usando múltiples fuentes mejoradas
  Future<String> _obtenerCorreoMejorado() async {
    try {
      // 1. Intentar desde InicioSesion_OfflineService
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        final correoOffline = InicioSesionOfflineService.extraerCorreo(userData);
        if (correoOffline != 'Sin información' && correoOffline.isNotEmpty) {
          return correoOffline;
        }
      }
      
      // 2. Intentar desde PerfilUsuarioService con datos guardados
      final perfilService = PerfilUsuarioService();
      final perfilData = await perfilService.obtenerDatosUsuario();
      
      if (perfilData != null) {
        // Buscar en múltiples campos posibles
        final posiblesCampos = ['correo', 'Correo', 'correoElectronico', 'email'];
        for (String campo in posiblesCampos) {
          final valor = perfilData[campo];
          if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
            return valor.toString();
          }
        }
        
        // 3. Si es vendedor, buscar en datos del vendedor
        if (perfilData['usua_EsVendedor'] == true && perfilData['usua_IdPersona'] != null) {
          final datosVendedor = await perfilService.buscarDatosVendedor(perfilData['usua_IdPersona']);
          if (datosVendedor != null && datosVendedor['vend_Correo'] != null) {
            return datosVendedor['vend_Correo'].toString();
          }
        }
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error en _obtenerCorreoMejorado: $e');
      return 'Sin información';
    }
  }
  
  /// Obtiene teléfono usando múltiples fuentes mejoradas
  Future<String> _obtenerTelefonoMejorado() async {
    try {
      // 1. Intentar desde InicioSesion_OfflineService
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        final telefonoOffline = InicioSesionOfflineService.extraerTelefono(userData);
        if (telefonoOffline != 'Sin información' && telefonoOffline.isNotEmpty) {
          return telefonoOffline;
        }
      }
      
      // 2. Intentar desde PerfilUsuarioService con datos guardados
      final perfilService = PerfilUsuarioService();
      final perfilData = await perfilService.obtenerDatosUsuario();
      
      if (perfilData != null) {
        // Buscar en múltiples campos posibles
        final posiblesCampos = ['telefono', 'usua_Telefono', 'phone', 'celular', 'numeroTelefono'];
        for (String campo in posiblesCampos) {
          final valor = perfilData[campo];
          if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
            return valor.toString();
          }
        }
        
        // 3. Si es vendedor, buscar en datos del vendedor
        if (perfilData['usua_EsVendedor'] == true && perfilData['usua_IdPersona'] != null) {
          final datosVendedor = await perfilService.buscarDatosVendedor(perfilData['usua_IdPersona']);
          if (datosVendedor != null && datosVendedor['vend_Telefono'] != null) {
            return datosVendedor['vend_Telefono'].toString();
          }
        }
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error en _obtenerTelefonoMejorado: $e');
      return 'Sin información';
    }
  }
  
  /// Obtiene ruta asignada usando múltiples fuentes mejoradas
  Future<String> _obtenerRutaAsignadaMejorada() async {
    try {
      print('🔍 Buscando ruta asignada...');
      final perfilService = PerfilUsuarioService();
      final perfilData = await perfilService.obtenerDatosUsuario();
      
      if (perfilData != null) {
        print('Datos de usuario encontrados');
        
        // 1. Buscar en campos directos del usuario
        final posiblesCamposUsuario = ['sucursal', 'rutaAsignada', 'ruta', 'sucu_Descripcion'];
        for (String campo in posiblesCamposUsuario) {
          final valor = perfilData[campo];
          if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
            print('✓ Ruta encontrada en $campo: $valor');
            return valor.toString();
          }
        }
        
        // 2. Si es vendedor, buscar en datos del vendedor
        if (perfilData['usua_EsVendedor'] == true && perfilData['usua_IdPersona'] != null) {
          print('Usuario es vendedor, buscando en datos del vendedor...');
          final datosVendedor = await perfilService.buscarDatosVendedor(perfilData['usua_IdPersona']);
          
          if (datosVendedor != null) {
            print('Datos del vendedor obtenidos, buscando ruta...');
            
            // Buscar en múltiples campos posibles del vendedor
            final posiblesCamposVendedor = [
              'sucu_Descripcion', 'sucursal', 'ruta', 'rutaAsignada', 
              'sucursalDescripcion', 'sucursalNombre', 'zona', 'area'
            ];
            
            for (String campo in posiblesCamposVendedor) {
              final valor = datosVendedor[campo];
              if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
                print('✓ Ruta encontrada en vendedor.$campo: $valor');
                return valor.toString();
              }
            }
            
            print('⚠ No se encontró ruta en datos del vendedor');
            print('Campos disponibles en vendedor: ${datosVendedor.keys.join(', ')}');
          } else {
            print('❌ No se pudieron obtener datos del vendedor');
          }
        } else {
          print('⚠ Usuario no es vendedor o no tiene personaId');
        }
      }
      
      print('❌ No se encontró ruta asignada');
      return 'No asignada';
    } catch (e) {
      print('Error en _obtenerRutaAsignadaMejorada: $e');
      return 'No asignada';
    }
  }
  
  /// Obtiene supervisor usando múltiples fuentes mejoradas
  Future<String> _obtenerSupervisorMejorado() async {
    try {
      print('🔍 Buscando supervisor responsable...');
      final perfilService = PerfilUsuarioService();
      final perfilData = await perfilService.obtenerDatosUsuario();
      
      if (perfilData != null) {
        print('Datos de usuario encontrados');
        
        // 1. Buscar en campos directos del usuario
        final posiblesCamposUsuario = ['supervisor', 'supervisorResponsable', 'jefe', 'encargado'];
        for (String campo in posiblesCamposUsuario) {
          final valor = perfilData[campo];
          if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
            print('✓ Supervisor encontrado en $campo: $valor');
            return valor.toString();
          }
        }
        
        // 2. Si es vendedor, buscar en datos del vendedor
        if (perfilData['usua_EsVendedor'] == true && perfilData['usua_IdPersona'] != null) {
          print('Usuario es vendedor, buscando en datos del vendedor...');
          final datosVendedor = await perfilService.buscarDatosVendedor(perfilData['usua_IdPersona']);
          
          if (datosVendedor != null) {
            print('Datos del vendedor obtenidos, buscando supervisor...');
            
            // 3. Intentar construir nombre completo del supervisor
            final nombreSupervisor = datosVendedor['nombreSupervisor'];
            final apellidoSupervisor = datosVendedor['apellidoSupervisor'];
            
            if (nombreSupervisor != null && apellidoSupervisor != null && 
                nombreSupervisor.toString().isNotEmpty && apellidoSupervisor.toString().isNotEmpty) {
              final nombreCompleto = '${nombreSupervisor.toString()} ${apellidoSupervisor.toString()}';
              print('✓ Supervisor encontrado (nombre completo): $nombreCompleto');
              return nombreCompleto;
            }
            
            // 4. Buscar en múltiples campos posibles del vendedor
            final posiblesCamposVendedor = [
              'vend_Supervisor', 'supervisor', 'supervisorId', 'supervisorNombre',
              'jefe', 'encargado', 'nombreSupervisor', 'apellidoSupervisor'
            ];
            
            for (String campo in posiblesCamposVendedor) {
              final valor = datosVendedor[campo];
              if (valor != null && valor.toString().isNotEmpty && valor.toString() != 'Sin información') {
                print('✓ Supervisor encontrado en vendedor.$campo: $valor');
                return valor.toString();
              }
            }
            
            print('⚠ No se encontró supervisor en datos del vendedor');
            print('Campos disponibles en vendedor: ${datosVendedor.keys.join(', ')}');
          } else {
            print('❌ No se pudieron obtener datos del vendedor');
          }
        } else {
          print('⚠ Usuario no es vendedor o no tiene personaId');
        }
      }
      
      print('❌ No se encontró supervisor responsable');
      return 'No asignado';
    } catch (e) {
      print('Error en _obtenerSupervisorMejorado: $e');
      return 'No asignado';
    }
  }

  /// Libera recursos cuando el servicio ya no se necesita
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _userDataController.close();
    _connectivityController.close();
    super.dispose();
  }
}
