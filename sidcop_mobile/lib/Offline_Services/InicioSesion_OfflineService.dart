import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/Offline_Services/Productos_OfflineService.dart';
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
          
          // Cachear direcciones de cada cliente
          await _cachearDireccionesClientes(clientesRuta);
          
          print('Clientes por ruta cacheados: ${clientesRuta.length}');
        }
      }
    } catch (e) {
      print('Error cacheando clientes por ruta: $e');
    }
  }

  /// Cachea las direcciones de los clientes
  static Future<void> _cachearDireccionesClientes(List<dynamic> clientes) async {
    try {
      print('=== INICIANDO CACHÉ DE DIRECCIONES DE CLIENTES ===');
      print('Número de clientes a procesar: ${clientes.length}');
      
      final clientesService = ClientesService();
      final direccionesMap = <String, List<dynamic>>{};
      
      for (final cliente in clientes) {
        if (cliente is Map<String, dynamic>) {
          final clienteId = cliente['clie_Id'];
          final clienteNombre = cliente['clie_Nombres'] ?? 'Sin nombre';
          print('Procesando cliente ID: $clienteId - $clienteNombre');
          
          if (clienteId != null) {
            try {
              final direcciones = await clientesService.getDireccionesCliente(clienteId);
              print('Cliente $clienteId: ${direcciones.length} direcciones obtenidas');
              
              if (direcciones.isNotEmpty) {
                direccionesMap[clienteId.toString()] = direcciones;
                print('Direcciones guardadas para cliente $clienteId');
              } else {
                print('Cliente $clienteId no tiene direcciones');
              }
            } catch (e) {
              print('Error obteniendo direcciones del cliente $clienteId: $e');
            }
          }
        }
      }
      
      print('Total de clientes con direcciones: ${direccionesMap.length}');
      print('Clientes con direcciones: ${direccionesMap.keys.toList()}');
      
      if (direccionesMap.isNotEmpty) {
        await _secureStorage.write(
          key: _clientesDireccionesKey,
          value: jsonEncode(direccionesMap),
        );
        print('=== DIRECCIONES CACHEADAS EXITOSAMENTE ===');
        print('Clave utilizada: $_clientesDireccionesKey');
      } else {
        print('=== NO SE ENCONTRARON DIRECCIONES PARA CACHEAR ===');
      }
    } catch (e) {
      print('ERROR CRÍTICO cacheando direcciones de clientes: $e');
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
      print('=== VERIFICANDO EXPIRACIÓN DEL CACHÉ ===');
      final expiracionStr = await _secureStorage.read(key: _cacheExpirationKey);
      print('Fecha de expiración almacenada: $expiracionStr');
      
      if (expiracionStr == null) {
        print('No hay fecha de expiración almacenada - caché considerado expirado');
        return true;
      }
      
      final expiracion = DateTime.fromMillisecondsSinceEpoch(int.parse(expiracionStr));
      final ahora = DateTime.now();
      final haExpirado = ahora.isAfter(expiracion);
      
      print('Fecha de expiración: $expiracion');
      print('Fecha actual: $ahora');
      print('¿Ha expirado?: $haExpirado');
      print('Tiempo restante: ${expiracion.difference(ahora)}');
      
      return haExpirado;
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
      print('Error obteniendo clientes desde caché: $e');
      return [];
    }
  }

  /// Obtiene direcciones de clientes desde el caché
  static Future<List<Map<String, dynamic>>> obtenerDireccionesClienteCache(int clienteId, {bool ignorarExpiracion = false}) async {
    try {
      print('=== OBTENIENDO DIRECCIONES DESDE CACHÉ ===');
      print('Cliente ID solicitado: $clienteId');
      print('Ignorar expiración: $ignorarExpiracion');
      
      if (!ignorarExpiracion && await _cacheHaExpirado()) {
        print('Caché de direcciones expirado - intentando usar datos expirados como fallback');
        // No retornar vacío inmediatamente, intentar leer los datos aunque estén expirados
      }
      
      print('Caché no expirado, leyendo direcciones...');
      final direccionesStr = await _secureStorage.read(key: _clientesDireccionesKey);
      print('Datos leídos del storage: ${direccionesStr != null ? "Datos encontrados" : "NULL"}');
      
      if (direccionesStr == null) {
        print('No hay direcciones cacheadas');
        return [];
      }
      
      final direccionesMap = Map<String, dynamic>.from(jsonDecode(direccionesStr));
      print('Clientes con direcciones cacheadas: ${direccionesMap.keys.toList()}');
      
      final direccionesCliente = direccionesMap[clienteId.toString()];
      print('Direcciones para cliente $clienteId: ${direccionesCliente != null ? "Encontradas" : "No encontradas"}');
      
      if (direccionesCliente != null) {
        final resultado = List<Map<String, dynamic>>.from(direccionesCliente);
        print('Retornando ${resultado.length} direcciones');
        return resultado;
      }
      
      print('No hay direcciones para este cliente');
      return [];
    } catch (e) {
      print('Error obteniendo direcciones del cliente desde caché: $e');
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
}