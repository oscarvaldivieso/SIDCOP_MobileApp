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
        // Completar correo y teléfono si no están en el diccionario
        if (_cachedUserData!['correo'] == null || _cachedUserData!['correo'] == 'Sin información') {
          _cachedUserData!['correo'] = await _extraerCorreoDesdeUserData(userData);
        }
        
        if (_cachedUserData!['telefono'] == null || _cachedUserData!['telefono'] == 'Sin información') {
          _cachedUserData!['telefono'] = await _extraerTelefonoDesdeUserData(userData);
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
      'metaVentasDiaria': 'L.0.00',
      'ventasDelDia': 'L.0.00',
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
      
      // Obtener datos básicos del usuario
      final nombreCompleto = await perfilService.obtenerNombreCompleto();
      final numeroIdentidad = await perfilService.obtenerNumeroIdentidad();
      final numeroEmpleado = await perfilService.obtenerNumeroEmpleado();
      final correo = await _obtenerCorreoCompleto();
      final telefono = await _obtenerTelefonoCompleto();
      final cargo = await perfilService.obtenerCargo();
      final imagenUsuario = await perfilService.obtenerImagenUsuario();
      
      // Crear datos actualizados
      final updatedData = Map<String, dynamic>.from(_cachedUserData ?? {});
      updatedData.addAll({
        'nombreCompleto': nombreCompleto,
        'numeroIdentidad': numeroIdentidad,
        'numeroEmpleado': numeroEmpleado,
        'correo': correo,
        'telefono': telefono,
        'cargo': cargo,
        'imagenUsuario': imagenUsuario,
        'fechaUltimaSync': DateTime.now().toIso8601String(),
      });
      
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

  /// Obtiene correo completo desde múltiples fuentes
  Future<String> _obtenerCorreoCompleto() async {
    try {
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        return await _extraerCorreoDesdeUserData(userData);
      }
      
      // Fallback al servicio de perfil
      final perfilService = PerfilUsuarioService();
      return await perfilService.obtenerCorreoElectronico();
    } catch (e) {
      print('Error obteniendo correo completo: $e');
      return 'Sin información';
    }
  }

  /// Obtiene teléfono completo desde múltiples fuentes
  Future<String> _obtenerTelefonoCompleto() async {
    try {
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      if (userData != null) {
        return await _extraerTelefonoDesdeUserData(userData);
      }
      
      // Fallback al servicio de perfil
      final perfilService = PerfilUsuarioService();
      return await perfilService.obtenerTelefono();
    } catch (e) {
      print('Error obteniendo teléfono completo: $e');
      return 'Sin información';
    }
  }

  /// Extrae correo desde userData (priorizando datos del login)
  Future<String> _extraerCorreoDesdeUserData(Map<String, dynamic> userData) async {
    try {
      // PRIORIDAD 1: Datos directos del login (campos principales de la respuesta de la API)
      String correo = userData['correo']?.toString() ?? 
                     userData['correoElectronico']?.toString() ?? 
                     userData['email']?.toString() ?? 
                     userData['usua_Correo']?.toString() ?? 
                     userData['usuario_Correo']?.toString() ?? '';
      
      if (correo.isNotEmpty && correo != 'null' && correo.toLowerCase() != 'string') {
        return correo;
      }
      
      // PRIORIDAD 2: Buscar en datosVendedor (solo como fallback)
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        correo = datosVendedor['vend_Correo']?.toString() ?? 
                 datosVendedor['correo']?.toString() ?? '';
        
        if (correo.isNotEmpty && correo != 'null' && correo.toLowerCase() != 'string') {
          return correo;
        }
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error extrayendo correo: $e');
      return 'Sin información';
    }
  }

  /// Extrae teléfono desde userData (priorizando datos del login)
  Future<String> _extraerTelefonoDesdeUserData(Map<String, dynamic> userData) async {
    try {
      // PRIORIDAD 1: Datos directos del login (campos principales de la respuesta de la API)
      String telefono = userData['telefono']?.toString() ?? 
                        userData['phone']?.toString() ?? 
                        userData['celular']?.toString() ?? 
                        userData['usua_Telefono']?.toString() ?? 
                        userData['usuario_Telefono']?.toString() ?? '';
      
      if (telefono.isNotEmpty && telefono != 'null' && telefono.toLowerCase() != 'string') {
        return telefono;
      }
      
      // PRIORIDAD 2: Buscar en datosVendedor (solo como fallback)
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        telefono = datosVendedor['vend_Telefono']?.toString() ?? 
                   datosVendedor['telefono']?.toString() ?? '';
        
        if (telefono.isNotEmpty && telefono != 'null' && telefono.toLowerCase() != 'string') {
          return telefono;
        }
      }
      
      return 'Sin información';
    } catch (e) {
      print('Error extrayendo teléfono: $e');
      return 'Sin información';
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
