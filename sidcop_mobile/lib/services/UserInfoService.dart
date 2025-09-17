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
        print('✓ Datos cargados desde caché: ${_cachedUserData!.keys.length} campos');
        
        // Notificar a los listeners
        _userDataController.add(_cachedUserData!);
        notifyListeners();
      } else {
        print('⚠ No hay datos en caché local');
        _cachedUserData = _getDefaultUserData();
        _userDataController.add(_cachedUserData!);
      }
    } catch (e) {
      print('✗ Error cargando desde caché: $e');
      _cachedUserData = _getDefaultUserData();
      _userDataController.add(_cachedUserData!);
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
      final correo = await perfilService.obtenerCorreoElectronico();
      final telefono = await perfilService.obtenerTelefono();
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
      
      // Obtener información operativa actualizada
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

  /// Libera recursos cuando el servicio ya no se necesita
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _userDataController.close();
    _connectivityController.close();
    super.dispose();
  }
}
