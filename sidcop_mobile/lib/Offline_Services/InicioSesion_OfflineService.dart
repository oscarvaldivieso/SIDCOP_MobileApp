import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/Offline_Services/Productos_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';

class InicioSesionOfflineService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _cacheExpirationKey = 'login_cache_expiration';
  static const String _userDataKey = 'cached_user_data';
  static const String _clientesRutaKey = 'cached_clientes_ruta';
  static const String _clientesDireccionesKey = 'cached_clientes_direcciones';
  static const String _productosBasicosKey = 'cached_productos_basicos';
  static const String _pedidosKey = 'cached_pedidos_login';
  static const String _pedidosDetalleKey = 'cached_pedidos_detalle';
  static const Duration _cacheExpiration = Duration(days: 7); // Extender a 7 días

  /// Cachea todos los datos necesarios durante el inicio de sesión
  static Future<void> cachearDatosInicioSesion(Map<String, dynamic> userData) async {
    try {
      print('=== INICIANDO CACHÉ DE DATOS DE LOGIN ===');
      
      // Verificar conectividad
      final hasConnection = await _hasInternetConnection();
      if (!hasConnection) {
        print('Sin conexión a internet, no se puede cachear datos');
        return;
      }
      
      print('Conexión verificada, procediendo con el caché...');
      
      // Establecer tiempo de expiración
      await _establecerExpiracionCache();
      print('Expiración del caché establecida');
      
      // Cachear datos del usuario (sin contraseña)
      print('Iniciando caché de datos de usuario...');
      await _cachearDatosUsuario(userData);
      print('Datos de usuario cacheados');
      
      // Cachear clientes por ruta
      print('Iniciando caché de clientes por ruta...');
      await _cachearClientesPorRuta(userData);
      print('Clientes por ruta cacheados');
      
      // Cachear productos básicos - CRÍTICO PARA PEDIDOS OFFLINE
      print('=== INICIANDO CACHÉ DE PRODUCTOS BÁSICOS ===');
      await _cachearProductosBasicos();
      print('=== CACHÉ DE PRODUCTOS BÁSICOS COMPLETADO ===');
      
      // Cachear pedidos con detalles
      print('Iniciando caché de pedidos...');
      await _cachearPedidosConDetalles(userData);
      print('Pedidos cacheados');
      
      // Generar diccionario completo de información del usuario
      print('Generando diccionario completo de usuario...');
      await generarYGuardarDiccionarioUsuario();
      print('Diccionario de usuario generado');
      
      print('=== CACHÉ DE DATOS DE LOGIN COMPLETADO EXITOSAMENTE ===');
    } catch (e) {
      print('ERROR CRÍTICO en caché de datos de login: $e');
      print('Stack trace: ${e.toString()}');
    }
  }

  /// Cachea los datos del usuario (filtrados, sin contraseña)
  static Future<void> _cachearDatosUsuario(Map<String, dynamic> userData) async {
    try {
      print('Cacheando datos del usuario...');
      
      // NUEVO: Guardar credenciales de forma segura ANTES de filtrar
      await _guardarCredencialesSeguras(userData);
      
      // Filtrar datos sensibles
      final datosLimpios = Map<String, dynamic>.from(userData);
      datosLimpios.remove('usua_Clave');
      datosLimpios.remove('password');
      
      await _secureStorage.write(
        key: _userDataKey,
        value: jsonEncode(datosLimpios),
      );
      
      print('Datos del usuario cacheados correctamente');
    } catch (e) {
      print('Error cacheando datos del usuario: $e');
    }
  }

  /// Guarda las credenciales de forma segura para consultas posteriores
  static Future<void> _guardarCredencialesSeguras(Map<String, dynamic> userData) async {
    try {
      final usuario = userData['usua_Usuario'];
      final clave = userData['usua_Clave'];
      
      if (usuario != null && clave != null) {
        print('Guardando credenciales de forma segura para consultas posteriores...');
        
        // Guardar credenciales para consultas
        await _secureStorage.write(key: 'login_usuario', value: usuario.toString());
        await _secureStorage.write(key: 'login_clave', value: clave.toString());
        
        // También guardar con el usuario como key (método alternativo)
        await _secureStorage.write(key: 'clave_${usuario.toString()}', value: clave.toString());
        
        print('✓ Credenciales guardadas de forma segura');
      } else {
        print('⚠ No se encontraron credenciales válidas para guardar');
      }
    } catch (e) {
      print('Error guardando credenciales seguras: $e');
    }
  }

  /// Cachea clientes organizados por ruta para vendedores
  static Future<void> _cachearClientesPorRuta(Map<String, dynamic> userData) async {
    try {
      print('Cacheando clientes por ruta...');
      
      final tipoUsuario = userData['usua_TipoUsuario'] as String?;
      final vendedorId = userData['usua_IdPersona'] as int?;
      
      if (tipoUsuario == 'Vendedor' && vendedorId != null) {
        final clientesService = ClientesService();
        
        // Obtener clientes de la ruta del vendedor
        final clientesRuta = await clientesService.getClientesPorRuta(vendedorId);
        
        if (clientesRuta.isNotEmpty) {
          // Guardar clientes organizados por ruta
          await _secureStorage.write(
            key: _clientesRutaKey,
            value: jsonEncode(clientesRuta),
          );
          
          // Usar el nuevo método optimizado de ClientesOfflineService
          await ClientesOfflineService.syncDireccionesForAllClients(clientesRuta);
          
          print('Clientes por ruta cacheados: ${clientesRuta.length}');
        }
      }
    } catch (e) {
      print('Error cacheando clientes por ruta: $e');
    }
  }


  /// Cachea productos básicos para la creación de pedidos
  static Future<void> _cachearProductosBasicos() async {
    try {
      print('>>> Iniciando caché de productos básicos...');
      
      List<ProductosPedidosViewModel> productosConvertidos = [];
      bool cacheExitoso = false;
      
      // Estrategia 1: Intentar obtener productos desde múltiples clientes
      final pedidosService = PedidosService();
      final clientesIds = [1, 2, 3]; // Probar con varios IDs de cliente
      
      for (int clienteId in clientesIds) {
        try {
          print('>>> Intentando obtener productos para cliente ID: $clienteId');
          final productos = await pedidosService.getProductosConListaPrecio(clienteId);
          
          if (productos.isNotEmpty) {
            productosConvertidos = productos;
            print('>>> ✓ Productos obtenidos desde API (cliente $clienteId): ${productosConvertidos.length}');
            cacheExitoso = true;
            break;
          } else {
            print('>>> Cliente $clienteId no tiene productos disponibles');
          }
        } catch (e) {
          print('>>> Error con cliente $clienteId: $e');
          continue;
        }
      }
      
      // Estrategia 2: Si no hay productos desde API, intentar desde servicio offline
      if (!cacheExitoso) {
        try {
          print('>>> Intentando productos desde servicio offline...');
          final productosOffline = await ProductosOffline.obtenerProductosLocal();
          print('>>> Productos offline encontrados: ${productosOffline.length}');
          
          if (productosOffline.isNotEmpty) {
            productosConvertidos = productosOffline.map((prod) {
              return ProductosPedidosViewModel(
                prodId: prod.prod_Id,
                prodCodigo: prod.prod_Codigo ?? '',
                prodDescripcionCorta: prod.prod_DescripcionCorta ?? '',
                prodDescripcion: prod.prod_Descripcion ?? '',
                prodPrecioUnitario: prod.prod_PrecioUnitario,
                prodImagen: prod.prod_Imagen,
                prod_Impulsado: false,
                prodEstado: true,
                listasPrecio: null,
                descuentosEscala: null,
                descEspecificaciones: null,
              );
            }).toList();
            cacheExitoso = true;
            print('>>> ✓ Productos convertidos desde offline: ${productosConvertidos.length}');
          }
        } catch (offlineError) {
          print('>>> Error obteniendo productos offline: $offlineError');
        }
      }
      
      // Guardar en caché
      if (productosConvertidos.isNotEmpty) {
        print('>>> Guardando ${productosConvertidos.length} productos en caché...');
        print('>>> Primer producto: ${productosConvertidos.first.prodDescripcionCorta}');
        
        final jsonData = jsonEncode(productosConvertidos.map((p) => p.toJson()).toList());
        await _secureStorage.write(
          key: _productosBasicosKey,
          value: jsonData,
        );
        
        // Verificar que se guardó correctamente
        final verificacion = await _secureStorage.read(key: _productosBasicosKey);
        if (verificacion != null && verificacion.isNotEmpty) {
          print('>>> ✓ PRODUCTOS CACHEADOS EXITOSAMENTE: ${productosConvertidos.length}');
        } else {
          print('>>> ✗ ERROR: No se pudo verificar el caché de productos');
        }
      } else {
        print('>>> ⚠ No se encontraron productos - guardando caché vacío');
        await _secureStorage.write(
          key: _productosBasicosKey,
          value: jsonEncode([]),
        );
      }
    } catch (e) {
      print('>>> ✗ ERROR CRÍTICO cacheando productos básicos: $e');
      print('>>> Stack trace: ${e.toString()}');
      
      // Asegurar que hay algo en el caché aunque sea vacío
      try {
        await _secureStorage.write(
          key: _productosBasicosKey,
          value: jsonEncode([]),
        );
      } catch (storageError) {
        print('>>> ✗ ERROR guardando caché vacío: $storageError');
      }
    }
  }

  /// Cachea pedidos existentes con sus detalles completos
  static Future<void> _cachearPedidosConDetalles(Map<String, dynamic> userData) async {
    try {
      print('Cacheando pedidos con detalles...');
      
      final pedidosService = PedidosService();
      
      // Obtener todos los pedidos
      final pedidos = await pedidosService.getPedidos();
      
      if (pedidos.isNotEmpty) {
        // Guardar lista de pedidos
        await _secureStorage.write(
          key: _pedidosKey,
          value: jsonEncode(pedidos.map((p) => p.toMap()).toList()),
        );
        
        // Cachear detalles de cada pedido
        final detallesMap = <String, dynamic>{};
        
        for (final pedido in pedidos) {
          try {
            final detalle = await pedidosService.getPedidoDetalle(pedido.pediId);
            if (detalle != null) {
              detallesMap[pedido.pediId.toString()] = detalle;
            }
          } catch (e) {
            print('Error obteniendo detalle del pedido ${pedido.pediId}: $e');
          }
        }
        
        if (detallesMap.isNotEmpty) {
          await _secureStorage.write(
            key: _pedidosDetalleKey,
            value: jsonEncode(detallesMap),
          );
          print('Detalles de pedidos cacheados: ${detallesMap.length}');
        }
        
        print('Pedidos cacheados: ${pedidos.length}');
      }
    } catch (e) {
      print('Error cacheando pedidos con detalles: $e');
    }
  }

  /// Establece el tiempo de expiración del caché
  static Future<void> _establecerExpiracionCache() async {
    try {
      final expiracion = DateTime.now().add(_cacheExpiration);
      await _secureStorage.write(
        key: _cacheExpirationKey,
        value: expiracion.millisecondsSinceEpoch.toString(),
      );
      print('Expiración del caché establecida: $expiracion');
    } catch (e) {
      print('Error estableciendo expiración del caché: $e');
    }
  }

  /// Verifica si el caché ha expirado
  static Future<bool> _cacheHaExpirado() async {
    try {
      final expiracionStr = await _secureStorage.read(key: _cacheExpirationKey);
      if (expiracionStr == null) return true;
      
      final expiracion = DateTime.fromMillisecondsSinceEpoch(int.parse(expiracionStr));
      return DateTime.now().isAfter(expiracion);
    } catch (e) {
      print('Error verificando expiración del caché: $e');
      return true;
    }
  }

  /// Obtiene datos del usuario desde el caché
  static Future<Map<String, dynamic>?> obtenerDatosUsuarioCache() async {
    try {
      if (await _cacheHaExpirado()) {
        print('Caché de usuario expirado');
        return null;
      }
      
      final datosStr = await _secureStorage.read(key: _userDataKey);
      if (datosStr == null) return null;
      
      return Map<String, dynamic>.from(jsonDecode(datosStr));
    } catch (e) {
      print('Error obteniendo datos del usuario desde caché: $e');
      return null;
    }
  }

  /// Obtiene clientes por ruta desde el caché
  static Future<List<Map<String, dynamic>>> obtenerClientesRutaCache() async {
    try {
      if (await _cacheHaExpirado()) {
        print('Caché de clientes expirado');
        return [];
      }
      
      final clientesStr = await _secureStorage.read(key: _clientesRutaKey);
      if (clientesStr == null) return [];
      
      final clientesData = jsonDecode(clientesStr);
      return List<Map<String, dynamic>>.from(clientesData);
    } catch (e) {
      return [];
    }
  }

  /// Obtiene direcciones de clientes desde el caché
  static Future<List<Map<String, dynamic>>> obtenerDireccionesClienteCache(int clienteId) async {
    try {
      print('=== OBTENIENDO DIRECCIONES DESDE CACHÉ ===');
      print('Cliente ID solicitado: $clienteId');
      
      // Verificar expiración del caché
      final cacheExpirado = await _cacheHaExpirado();
      print('Caché expirado: $cacheExpirado');
      
      // Verificar conectividad para decidir si usar caché expirado
      final hasConnection = await _hasInternetConnection();
      print('Conexión disponible: $hasConnection');
      
      if (cacheExpirado && hasConnection) {
        print('⚠ Caché expirado y hay conexión - debería refrescarse online');
        // En este caso, el método que llama debería manejar el refresh
        // Pero seguimos intentando leer el caché como fallback
      } else if (cacheExpirado && !hasConnection) {
        print('⚠ Caché expirado pero SIN conexión - usando caché expirado como fallback');
      }
      
      // Leer datos del caché de direcciones (incluso si está expirado en modo offline)
      final direccionesStr = await _secureStorage.read(key: _clientesDireccionesKey);
      print('Datos leídos del caché: ${direccionesStr?.length ?? 0} caracteres');
      
      if (direccionesStr == null || direccionesStr.isEmpty) {
        print('⚠ No hay datos de direcciones en el caché');
        return [];
      }
      
      // Decodificar JSON
      final direccionesMap = Map<String, dynamic>.from(jsonDecode(direccionesStr));
      print('Clientes con direcciones en caché: ${direccionesMap.keys.toList()}');
      
      // Buscar direcciones del cliente específico
      final clienteKey = clienteId.toString();
      print('Buscando direcciones para cliente key: "$clienteKey"');
      
      final direccionesCliente = direccionesMap[clienteKey];
      
      if (direccionesCliente != null) {
        final direcciones = List<Map<String, dynamic>>.from(direccionesCliente);
        print('✓ Direcciones encontradas para cliente $clienteId: ${direcciones.length}');
        
        if (cacheExpirado && !hasConnection) {
          print('⚠ USANDO DIRECCIONES DE CACHÉ EXPIRADO (modo offline)');
        }
        
        // Log de la primera dirección para debug
        if (direcciones.isNotEmpty) {
          print('Primera dirección: ${direcciones[0]}');
        }
        
        return direcciones;
      } else {
        print('⚠ No se encontraron direcciones para cliente $clienteId');
        print('Clientes disponibles en caché: ${direccionesMap.keys.join(", ")}');
        
        // Si estamos offline y no hay direcciones, crear una dirección por defecto
        if (!hasConnection) {
          print('>>> Creando dirección por defecto para modo offline');
          final direccionPorDefecto = {
            'diCl_Id': 1159, // ID temporal para offline
            'diCl_Direccion': 'Dirección por defecto (offline)',
            'diCl_Referencia': 'Creada automáticamente para pedido offline',
            'diCl_ClienteId': clienteId,
            'diCl_Estado': true,
          };
          return [direccionPorDefecto];
        }
        
        return [];
      }
    } catch (e) {
      print('✗ ERROR obteniendo direcciones del cliente desde caché: $e');
      print('Stack trace: ${e.toString()}');
      
      // Si hay error y estamos offline, crear dirección por defecto
      final hasConnection = await _hasInternetConnection();
      if (!hasConnection) {
        print('>>> Error en caché pero offline - creando dirección por defecto');
        final direccionPorDefecto = {
          'diCl_Id': 999999, // ID temporal para offline
          'diCl_Direccion': 'Dirección por defecto (offline)',
          'diCl_Referencia': 'Creada automáticamente para pedido offline',
          'diCl_ClienteId': clienteId,
          'diCl_Estado': true,
        };
        return [direccionPorDefecto];
      }
      
      return [];
    }
  }

  /// Obtiene productos básicos del caché
  static Future<List<ProductosPedidosViewModel>> obtenerProductosBasicosCache() async {
    try {
      print('>>> Iniciando lectura de productos desde caché...');
      
      // Verificar si el caché ha expirado
      final cacheExpirado = await _cacheHaExpirado();
      print('>>> Caché expirado: $cacheExpirado');
      
      if (cacheExpirado) {
        print('>>> Caché de productos expirado');
        
        // Intentar refrescar si hay conexión
        final hasConnection = await _hasInternetConnection();
        print('>>> Conexión disponible: $hasConnection');
        
        if (hasConnection) {
          print('>>> Hay conexión, refrescando caché automáticamente...');
          await _cachearProductosBasicos();
          await _establecerExpiracionCache();
        } else {
          print('>>> Sin conexión, intentando usar caché expirado como fallback');
        }
      }
      
      // Leer del caché
      final productosJson = await _secureStorage.read(key: _productosBasicosKey);
      print('>>> Datos JSON leídos del caché: ${productosJson?.length ?? 0} caracteres');
      
      if (productosJson == null || productosJson.isEmpty) {
        print('>>> ⚠ No hay productos en el caché - JSON vacío o nulo');
        return [];
      }
      
      try {
        final List<dynamic> productosList = jsonDecode(productosJson);
        print('>>> Lista decodificada: ${productosList.length} elementos');
        
        if (productosList.isEmpty) {
          print('>>> ⚠ Lista de productos vacía en el caché');
          return [];
        }
        
        final productos = productosList
            .map((json) => ProductosPedidosViewModel.fromJson(json))
            .toList();
        
        print('>>> ✓ Productos cargados desde cache: ${productos.length}');
        if (productos.isNotEmpty) {
          print('>>> Primer producto: ${productos.first.prodDescripcionCorta}');
        }
        return productos;
      } catch (parseError) {
        print('>>> ✗ Error parseando JSON del caché: $parseError');
        return [];
      }
    } catch (e) {
      print('>>> ✗ Error obteniendo productos básicos del caché: $e');
      print('>>> Stack trace: ${e.toString()}');
      return [];
    }
  }

  /// Obtiene pedidos desde el caché
  static Future<List<PedidosViewModel>> obtenerPedidosCache() async {
    try {
      if (await _cacheHaExpirado()) {
        print('Caché de pedidos expirado');
        return [];
      }
      
      final pedidosStr = await _secureStorage.read(key: _pedidosKey);
      if (pedidosStr == null) return [];
      
      final pedidosData = List<dynamic>.from(jsonDecode(pedidosStr));
      return pedidosData
          .map((p) => PedidosViewModel.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    } catch (e) {
      print('Error obteniendo pedidos desde caché: $e');
      return [];
    }
  }

  /// Obtiene detalle de un pedido específico desde el caché
  static Future<dynamic> obtenerDetallePedidoCache(int pedidoId) async {
    try {
      if (await _cacheHaExpirado()) {
        print('Caché de detalles de pedidos expirado');
        return null;
      }
      
      final detallesStr = await _secureStorage.read(key: _pedidosDetalleKey);
      if (detallesStr == null) return null;
      
      final detallesMap = Map<String, dynamic>.from(jsonDecode(detallesStr));
      return detallesMap[pedidoId.toString()];
    } catch (e) {
      print('Error obteniendo detalle del pedido desde caché: $e');
      return null;
    }
  }

  /// Limpia todo el caché de login
  static Future<void> limpiarCache() async {
    try {
      await _secureStorage.delete(key: _userDataKey);
      await _secureStorage.delete(key: _clientesRutaKey);
      await _secureStorage.delete(key: _clientesDireccionesKey);
      await _secureStorage.delete(key: _productosBasicosKey);
      await _secureStorage.delete(key: _pedidosKey);
      await _secureStorage.delete(key: _pedidosDetalleKey);
      await _secureStorage.delete(key: _cacheExpirationKey);
      print('Caché de login limpiado completamente');
    } catch (e) {
      print('Error limpiando caché de login: $e');
    }
  }

  /// Verifica el estado del caché
  static Future<Map<String, dynamic>> verificarEstadoCache() async {
    try {
      final haExpirado = await _cacheHaExpirado();
      final userData = await _secureStorage.read(key: _userDataKey);
      final clientesRuta = await _secureStorage.read(key: _clientesRutaKey);
      final direcciones = await _secureStorage.read(key: _clientesDireccionesKey);
      final productos = await _secureStorage.read(key: _productosBasicosKey);
      final pedidos = await _secureStorage.read(key: _pedidosKey);
      
      return {
        'expirado': haExpirado,
        'tieneUsuario': userData != null,
        'tieneClientes': clientesRuta != null,
        'tieneDirecciones': direcciones != null,
        'tieneProductos': productos != null,
        'tienePedidos': pedidos != null,
      };
    } catch (e) {
      print('Error verificando estado del caché: $e');
      return {'error': e.toString()};
    }
  }

  /// Verifica conectividad a internet
  static Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conectividad: $e');
      return false;
    }
  }


  /// Verifica si hay datos válidos en el caché
  static Future<bool> tieneDatosValidosEnCache() async {
    try {
      if (await _cacheHaExpirado()) return false;
      
      final userData = await _secureStorage.read(key: _userDataKey);
      return userData != null;
    } catch (e) {
      print('Error verificando datos válidos en caché: $e');
      return false;
    }
  }

  /// Fuerza el refresco del caché de productos
  static Future<void> refrescarCacheProductos() async {
    try {
      print('Forzando refresco del caché de productos...');
      await _cachearProductosBasicos();
      
      // Actualizar la expiración del caché
      await _establecerExpiracionCache();
      print('Caché de productos refrescado exitosamente');
    } catch (e) {
      print('Error refrescando caché de productos: $e');
    }
  }

  /// Obtiene información operativa del usuario desde el caché
  static Future<Map<String, String>> obtenerInformacionOperativa() async {
    try {
      final userData = await obtenerDatosUsuarioCache();
      final productos = await obtenerProductosBasicosCache();
      final pedidos = await obtenerPedidosCache();
      final clientesRuta = await obtenerClientesRutaCache();
      
      // Obtener inventario asignado desde el servicio de inventario
      final inventarioAsignado = await _obtenerInventarioAsignadoDesdeInventario(userData);
      
      // Datos por defecto
      Map<String, String> infoOperativa = {
        'rutaAsignada': 'No asignada',
        'supervisorResponsable': 'No asignado',
        'inventarioAsignado': inventarioAsignado,
        'clientesAsignados': '${clientesRuta.length}',
        'metaVentasDiaria': 'L.7,500.00', // Valor por defecto
        'ventasDelDia': 'L.5,200.00', // Valor por defecto
        'ultimaRecargaSolicitada': 'Sin pedidos registrados',
      };
      
      if (userData != null) {
        // Usar los métodos de extracción que priorizan datos del login
        infoOperativa['rutaAsignada'] = _extraerRutaAsignada(userData);
        infoOperativa['supervisorResponsable'] = _extraerSupervisorResponsable(userData);
        
        // Última recarga desde pedidos
        if (pedidos.isNotEmpty) {
          try {
            // Ordenar pedidos por ID (más reciente primero)
            pedidos.sort((a, b) => b.pediId.compareTo(a.pediId));
            final ultimoPedido = pedidos.first;
            
            final fecha = ultimoPedido.pediFechaPedido;
            final meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                          'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
            final mes = meses[fecha.month - 1];
            final hora = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
            infoOperativa['ultimaRecargaSolicitada'] = '${fecha.day} $mes ${fecha.year} - $hora';
          } catch (e) {
            print('Error procesando última recarga: $e');
          }
        }
      }
      
      return infoOperativa;
    } catch (e) {
      print('Error obteniendo información operativa: $e');
      return {
        'rutaAsignada': 'Error al cargar',
        'supervisorResponsable': 'Error al cargar',
        'inventarioAsignado': 'Error al cargar',
        'clientesAsignados': 'Error al cargar',
        'metaVentasDiaria': 'Error al cargar',
        'ventasDelDia': 'Error al cargar',
        'ultimaRecargaSolicitada': 'Error al cargar',
      };
    }
  }

  /// Obtiene estadísticas de ventas (por implementar con datos reales)
  static Future<Map<String, String>> obtenerEstadisticasVentas() async {
    try {
      // TODO: Implementar lógica para calcular ventas reales
      // Por ahora devolver valores por defecto
      return {
        'metaVentasDiaria': 'L.7,500.00',
        'ventasDelDia': 'L.5,200.00',
        'ventasMes': 'L.156,000.00',
        'porcentajeMeta': '69.3%',
      };
    } catch (e) {
      print('Error obteniendo estadísticas de ventas: $e');
      return {
        'metaVentasDiaria': 'No disponible',
        'ventasDelDia': 'No disponible',
        'ventasMes': 'No disponible',
        'porcentajeMeta': 'No disponible',
      };
    }
  }

  /// Clave para almacenar el diccionario completo de información del usuario
  static const String _userInfoDictionaryKey = 'user_info_dictionary';

  /// Genera y guarda un diccionario completo con toda la información del usuario
  static Future<void> generarYGuardarDiccionarioUsuario() async {
    try {
      print('=== GENERANDO DICCIONARIO COMPLETO DE USUARIO ===');
      
      final userData = await obtenerDatosUsuarioCache();
      final productos = await obtenerProductosBasicosCache();
      final pedidos = await obtenerPedidosCache();
      
      print('DEBUG - userData disponible: ${userData != null}');
      if (userData != null) {
        print('DEBUG - Campos en userData: ${userData.keys.join(", ")}');
        print('DEBUG - datosVendedor disponible: ${userData['datosVendedor'] != null}');
        if (userData['datosVendedor'] != null) {
          final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>;
          print('DEBUG - Campos en datosVendedor: ${datosVendedor.keys.join(", ")}');
        }
      }
      print('DEBUG - Productos encontrados: ${productos.length}');
      print('DEBUG - Pedidos encontrados: ${pedidos.length}');
      
      // Extraer datos con debug
      final nombreCompleto = _extraerNombreCompleto(userData);
      final numeroIdentidad = _extraerNumeroIdentidad(userData);
      final numeroEmpleado = _extraerNumeroEmpleado(userData);
      final correo = extraerCorreo(userData);
      final telefono = extraerTelefono(userData);
      final cargo = _extraerCargo(userData);
      final rutaAsignada = _extraerRutaAsignada(userData);
      final supervisorResponsable = _extraerSupervisorResponsable(userData);
      final fechaIngreso = _extraerFechaIngreso(userData);
      final ultimaRecarga = _extraerUltimaRecarga(pedidos);
      final clientesAsignados = _extraerNumeroClientesAsignados(userData);
      
      print('DEBUG - Datos extraídos:');
      print('  nombreCompleto: $nombreCompleto');
      print('  numeroIdentidad: $numeroIdentidad');
      print('  numeroEmpleado: $numeroEmpleado');
      print('  correo: $correo');
      print('  telefono: $telefono');
      print('  cargo: $cargo');
      print('  rutaAsignada: $rutaAsignada');
      print('  supervisorResponsable: $supervisorResponsable');
      print('  fechaIngreso: $fechaIngreso');
      print('  inventarioAsignado: ${productos.length}');
      print('  clientesAsignados: $clientesAsignados');
      print('  ultimaRecarga: $ultimaRecarga');
      
      // Crear diccionario completo
      Map<String, dynamic> diccionarioCompleto = {
        // Datos personales
        'nombreCompleto': nombreCompleto,
        'numeroIdentidad': numeroIdentidad,
        'numeroEmpleado': numeroEmpleado,
        'correo': correo,
        'telefono': telefono,
        'cargo': cargo,
        
        // Datos de asignación laboral
        'rutaAsignada': rutaAsignada,
        'supervisorResponsable': supervisorResponsable,
        'fechaIngreso': fechaIngreso,
        
        // Información operativa
        'inventarioAsignado': productos.length.toString(),
        'clientesAsignados': clientesAsignados.toString(),
        'metaVentasDiaria': 'L.7,500.00', // Valor por defecto
        'ventasDelDia': 'L.5,200.00', // Valor por defecto
        'ultimaRecargaSolicitada': ultimaRecarga,
        
        // Metadatos
        'fechaGeneracion': DateTime.now().toIso8601String(),
        'totalProductos': productos.length,
        'totalPedidos': pedidos.length,
      };
      
      // Guardar en FlutterSecureStorage
      await _secureStorage.write(
        key: _userInfoDictionaryKey,
        value: jsonEncode(diccionarioCompleto),
      );
      
      print('✓ Diccionario de usuario guardado exitosamente');
      print('Datos guardados: ${diccionarioCompleto.keys.join(", ")}');
      print('Contenido completo del diccionario:');
      diccionarioCompleto.forEach((key, value) {
        print('  $key: $value');
      });
      
    } catch (e) {
      print('✗ Error generando diccionario de usuario: $e');
      print('Stack trace: ${e.toString()}');
    }
  }

  /// Obtiene el diccionario completo de información del usuario
  static Future<Map<String, dynamic>?> obtenerDiccionarioUsuario() async {
    try {
      final diccionarioStr = await _secureStorage.read(key: _userInfoDictionaryKey);
      
      if (diccionarioStr == null || diccionarioStr.isEmpty) {
        print('No hay diccionario de usuario guardado, generando uno nuevo...');
        await generarYGuardarDiccionarioUsuario();
        
        // Intentar leer nuevamente
        final nuevoDiccionarioStr = await _secureStorage.read(key: _userInfoDictionaryKey);
        if (nuevoDiccionarioStr != null) {
          return Map<String, dynamic>.from(jsonDecode(nuevoDiccionarioStr));
        }
        return null;
      }
      
      return Map<String, dynamic>.from(jsonDecode(diccionarioStr));
    } catch (e) {
      print('Error obteniendo diccionario de usuario: $e');
      return null;
    }
  }

  /// Actualiza el diccionario de usuario con datos frescos
  static Future<void> actualizarDiccionarioUsuario() async {
    try {
      print('Actualizando diccionario de usuario...');
      await generarYGuardarDiccionarioUsuario();
    } catch (e) {
      print('Error actualizando diccionario de usuario: $e');
    }
  }

  /// Método de debug para verificar el estado del diccionario
  static Future<void> debugDiccionarioUsuario() async {
    try {
      print('=== DEBUG DICCIONARIO DE USUARIO ===');
      
      // Verificar si existe el diccionario
      final diccionarioStr = await _secureStorage.read(key: _userInfoDictionaryKey);
      print('Diccionario existe: ${diccionarioStr != null}');
      
      if (diccionarioStr != null) {
        print('Tamaño del diccionario: ${diccionarioStr.length} caracteres');
        
        try {
          final diccionario = Map<String, dynamic>.from(jsonDecode(diccionarioStr));
          print('Campos en el diccionario:');
          diccionario.forEach((key, value) {
            print('  $key: $value');
          });
        } catch (e) {
          print('Error parseando diccionario: $e');
        }
      }
      
      // Verificar datos fuente
      final userData = await obtenerDatosUsuarioCache();
      print('\\nDatos fuente disponibles:');
      print('  userData: ${userData != null}');
      if (userData != null) {
        print('  Campos userData: ${userData.keys.join(", ")}');
        if (userData['datosVendedor'] != null) {
          final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>;
          print('  datosVendedor disponible con campos: ${datosVendedor.keys.join(", ")}');
        }
      }
      
      final productos = await obtenerProductosBasicosCache();
      final pedidos = await obtenerPedidosCache();
      print('  productos: ${productos.length}');
      print('  pedidos: ${pedidos.length}');
      
    } catch (e) {
      print('Error en debug: $e');
    }
  }

  /// Fuerza la regeneración del diccionario (para testing)
  static Future<Map<String, dynamic>?> forzarRegeneracionDiccionario() async {
    try {
      print('=== FORZANDO REGENERACIÓN DEL DICCIONARIO ===');
      
      // Eliminar diccionario existente
      await _secureStorage.delete(key: _userInfoDictionaryKey);
      print('Diccionario anterior eliminado');
      
      // Generar nuevo diccionario
      await generarYGuardarDiccionarioUsuario();
      
      // Verificar que se guardó correctamente
      final diccionarioStr = await _secureStorage.read(key: _userInfoDictionaryKey);
      if (diccionarioStr != null) {
        final diccionario = Map<String, dynamic>.from(jsonDecode(diccionarioStr));
        print('✓ Diccionario regenerado exitosamente');
        return diccionario;
      } else {
        print('✗ Error: No se pudo regenerar el diccionario');
        return null;
      }
    } catch (e) {
      print('Error forzando regeneración: $e');
      return null;
    }
  }

  // Métodos auxiliares para extraer datos específicos
  static String _extraerNombreCompleto(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    
    if (userData['nombreCompleto'] != null && userData['nombreCompleto'].toString().isNotEmpty) {
      return userData['nombreCompleto'].toString();
    }
    
    final nombres = userData['nombres']?.toString() ?? '';
    final apellidos = userData['apellidos']?.toString() ?? '';
    
    if (nombres.isNotEmpty && apellidos.isNotEmpty) {
      return '$nombres $apellidos';
    } else if (nombres.isNotEmpty) {
      return nombres;
    } else if (apellidos.isNotEmpty) {
      return apellidos;
    }
    
    return userData['usua_Usuario']?.toString() ?? 'No disponible';
  }

  static String _extraerNumeroIdentidad(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    return userData['dni']?.toString() ?? 'No disponible';
  }

  static String _extraerNumeroEmpleado(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    return userData['usua_Id']?.toString() ?? 'No disponible';
  }

  static String extraerCorreo(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    
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
    
    return 'No disponible';
  }

  static String extraerTelefono(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    
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
    
    return 'No disponible';
  }

  static String _extraerCargo(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    return userData['role_Descripcion']?.toString() ?? userData['cargo']?.toString() ?? 'No disponible';
  }

  static String _extraerRutaAsignada(Map<String, dynamic>? userData) {
    if (userData == null) return 'No asignada';
    
    try {
      // PRIORIDAD 1: Datos directos del login
      // Buscar campos que vienen directamente en la respuesta del login
      final rutaLogin = userData['ruta']?.toString() ?? 
                       userData['rutaAsignada']?.toString() ?? 
                       userData['ruta_Codigo']?.toString() ?? 
                       userData['ruta_Descripcion']?.toString() ?? '';
      
      if (rutaLogin.isNotEmpty && rutaLogin != 'null') {
        return rutaLogin;
      }
      
      // PRIORIDAD 2: Intentar obtener desde rutasDelDiaJson
      final rutasDelDiaJson = userData['rutasDelDiaJson'] as String?;
      if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty && rutasDelDiaJson != 'null') {
        final rutasData = jsonDecode(rutasDelDiaJson) as List<dynamic>;
        if (rutasData.isNotEmpty) {
          final primeraRuta = rutasData.first as Map<String, dynamic>;
          final rutaCodigo = primeraRuta['Ruta_Codigo'] as String?;
          final rutaDescripcion = primeraRuta['Ruta_Descripcion'] as String?;
          
          if (rutaCodigo != null) {
            return rutaDescripcion ?? rutaCodigo;
          }
        }
      }
      
      // PRIORIDAD 3: Fallback desde datosVendedor (solo si no viene en login)
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        final vendCodigo = datosVendedor['vend_Codigo'];
        if (vendCodigo != null) {
          return 'Ruta $vendCodigo';
        }
      }
      
      // PRIORIDAD 4: Usar código del usuario
      final codigo = userData['codigo'] as String?;
      if (codigo != null && codigo.isNotEmpty && codigo != 'null') {
        return codigo;
      }
      
    } catch (e) {
      print('Error extrayendo ruta asignada: $e');
    }
    
    return 'No asignada';
  }

  static String _extraerSupervisorResponsable(Map<String, dynamic>? userData) {
    if (userData == null) return 'No asignado';
    
    try {
      // PRIORIDAD 1: Datos directos del login
      // Buscar campos que vienen directamente en la respuesta del login
      final supervisorLogin = userData['supervisor']?.toString() ?? 
                             userData['supervisorResponsable']?.toString() ?? 
                             userData['supervisor_Nombre']?.toString() ?? 
                             userData['nombreSupervisor']?.toString() ?? '';
      
      if (supervisorLogin.isNotEmpty && supervisorLogin != 'null') {
        return supervisorLogin;
      }
      
      // PRIORIDAD 2: Buscar en campos combinados del login
      final nombreSup = userData['supervisor_Nombres']?.toString() ?? '';
      final apellidoSup = userData['supervisor_Apellidos']?.toString() ?? '';
      if (nombreSup.isNotEmpty || apellidoSup.isNotEmpty) {
        final supervisorCompleto = '$nombreSup $apellidoSup'.trim();
        if (supervisorCompleto.isNotEmpty) {
          return supervisorCompleto;
        }
      }
      
      // PRIORIDAD 3: Fallback desde datosVendedor (solo si no viene en login)
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        final nombreSupervisor = datosVendedor['nombreSupervisor']?.toString() ?? '';
        final apellidoSupervisor = datosVendedor['apellidoSupervisor']?.toString() ?? '';
        final supervisor = '$nombreSupervisor $apellidoSupervisor'.trim();
        if (supervisor.isNotEmpty && supervisor != 'null null') {
          return supervisor;
        }
      }
      
    } catch (e) {
      print('Error extrayendo supervisor responsable: $e');
    }
    
    return 'No asignado';
  }

  static String _extraerFechaIngreso(Map<String, dynamic>? userData) {
    if (userData == null) return 'No disponible';
    
    try {
      // Usar usua_FechaCreacion del endpoint de login
      final fechaCreacion = userData['usua_FechaCreacion'];
      if (fechaCreacion != null && fechaCreacion.toString() != "0001-01-01T00:00:00") {
        try {
          final fecha = DateTime.parse(fechaCreacion.toString());
          return DateFormat('dd/MM/yyyy').format(fecha);
        } catch (e) {
          print('Error parseando usua_FechaCreacion: $e');
        }
      }
      
      // Fallback: intentar desde datosVendedor
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        final fechaCreacion = datosVendedor['vend_FechaCreacion'];
        if (fechaCreacion != null) {
          try {
            final fecha = DateTime.parse(fechaCreacion.toString());
            return DateFormat('dd/MM/yyyy').format(fecha);
          } catch (e) {
            print('Error parseando fecha de ingreso desde datosVendedor: $e');
          }
        }
      }
      
      // Si no hay fecha válida, usar fecha actual como placeholder
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
      
    } catch (e) {
      print('Error extrayendo fecha de ingreso: $e');
    }
    
    return 'No disponible';
  }

  static String _extraerUltimaRecarga(List<PedidosViewModel> pedidos) {
    if (pedidos.isEmpty) return 'Sin pedidos registrados';
    
    try {
      // Ordenar pedidos por ID (más reciente primero)
      pedidos.sort((a, b) => b.pediId.compareTo(a.pediId));
      final ultimoPedido = pedidos.first;
      
      final fecha = ultimoPedido.pediFechaPedido;
      final meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      final mes = meses[fecha.month - 1];
      final hora = '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
      return '${fecha.day} $mes ${fecha.year} - $hora';
    } catch (e) {
      print('Error procesando última recarga: $e');
      return 'Error al procesar fecha';
    }
  }

  static int _extraerNumeroClientesAsignados(Map<String, dynamic>? userData) {
    if (userData == null) return 0;
    
    try {
      final rutasDelDiaJson = userData['rutasDelDiaJson'] as String?;
      if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty) {
        final rutasData = jsonDecode(rutasDelDiaJson) as List<dynamic>;
        if (rutasData.isNotEmpty) {
          final primeraRuta = rutasData.first as Map<String, dynamic>;
          final clientes = primeraRuta['Clientes'] as List<dynamic>?;
          if (clientes != null) {
            return clientes.length;
          }
        }
      }
    } catch (e) {
      print('Error extrayendo número de clientes asignados: $e');
    }
    
    return 0;
  }

  /// Obtiene el inventario asignado desde el servicio de inventario
  static Future<String> _obtenerInventarioAsignadoDesdeInventario(Map<String, dynamic>? userData) async {
    try {
      if (userData == null) return '0';
      
      // Obtener el ID del vendedor
      final vendedorId = userData['usua_IdPersona'] as int?;
      if (vendedorId == null) return '0';
      
      print('Obteniendo inventario asignado para vendedor: $vendedorId');
      
      try {
        // OPCIÓN 1: Intentar obtener desde caché específico de inventario
        final inventoryItems = await _obtenerInventarioDesdeOfflineDatabase(vendedorId);
        
        if (inventoryItems.isNotEmpty) {
          print('✓ Inventario encontrado en caché específico: ${inventoryItems.length} productos');
          return '${inventoryItems.length}';
        }
        
        // OPCIÓN 2: Intentar usar InventoryService (solo lectura de caché)
        final inventoryFromService = await _obtenerInventarioDesdeServicio(vendedorId);
        if (inventoryFromService > 0) {
          print('✓ Inventario encontrado desde servicio: $inventoryFromService productos');
          return '$inventoryFromService';
        }
        
        // OPCIÓN 3: Fallback - usar productos básicos
        final productos = await obtenerProductosBasicosCache();
        print('⚠ Usando productos básicos como fallback: ${productos.length} productos');
        return '${productos.length}';
        
      } catch (e) {
        print('Error obteniendo inventario desde servicio: $e');
        
        // Fallback: usar productos básicos
        final productos = await obtenerProductosBasicosCache();
        return '${productos.length}';
      }
      
    } catch (e) {
      print('Error obteniendo inventario asignado: $e');
      return '0';
    }
  }

  /// Obtiene inventario desde la base de datos offline
  static Future<List<Map<String, dynamic>>> _obtenerInventarioDesdeOfflineDatabase(int vendedorId) async {
    try {
      // Intentar leer desde el caché de inventario offline si existe
      final inventoryStr = await _secureStorage.read(key: 'inventory_cache_$vendedorId');
      
      if (inventoryStr != null && inventoryStr.isNotEmpty) {
        final inventoryData = jsonDecode(inventoryStr);
        if (inventoryData is List) {
          return List<Map<String, dynamic>>.from(inventoryData);
        }
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo inventario desde offline database: $e');
      return [];
    }
  }

  /// Obtiene el conteo de inventario desde el servicio de inventario (solo lectura de caché)
  static Future<int> _obtenerInventarioDesdeServicio(int vendedorId) async {
    try {
      // Buscar diferentes keys posibles donde se pueda guardar el inventario
      final possibleKeys = [
        'inventory_cache_$vendedorId',
        'inventory_data_$vendedorId',
        'offline_inventory_$vendedorId',
        'vendedor_${vendedorId}_inventory',
      ];
      
      for (final key in possibleKeys) {
        try {
          final inventoryStr = await _secureStorage.read(key: key);
          if (inventoryStr != null && inventoryStr.isNotEmpty) {
            final inventoryData = jsonDecode(inventoryStr);
            if (inventoryData is List) {
              print('✓ Inventario encontrado en key: $key con ${inventoryData.length} productos');
              return inventoryData.length;
            } else if (inventoryData is Map && inventoryData.containsKey('items')) {
              final items = inventoryData['items'] as List?;
              if (items != null) {
                print('✓ Inventario encontrado en key: $key con ${items.length} productos');
                return items.length;
              }
            }
          }
        } catch (e) {
          // Continuar con la siguiente key
          continue;
        }
      }
      
      return 0;
    } catch (e) {
      print('Error obteniendo inventario desde servicio: $e');
      return 0;
    }
  }
}