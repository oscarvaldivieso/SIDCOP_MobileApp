import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/services/FacturaService.dart';

class PedidosScreenOffline {
  static const _storage = FlutterSecureStorage();
  static const String _carpetaOffline = 'offline_pedidos';
  static const String _pedidosKey = 'pedidos_list';
  static const String _pedidoDetalleKey = 'pedido_detalle_';
  static const String _pedidosPendientesKey = 'pedidos_pendientes';
  
  /// Guarda cualquier objeto JSON-serializable (similar a recargas)
  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      final key = 'json:$nombreArchivo';
      print('DEBUG guardarJson: Guardando en clave: $key');
      print('DEBUG guardarJson: Contenido: $contenido');
      await _storage.write(key: key, value: contenido);
      
      // Verificar que se guardó correctamente
      final verificacion = await _storage.read(key: key);
      print('DEBUG guardarJson: Verificación - contenido guardado: $verificacion');
    } catch (e) {
      print('DEBUG guardarJson: Error: $e');
      rethrow;
    }
  }

  /// Lee y decodifica JSON desde archivo (similar a recargas)
  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'json:$nombreArchivo';
      print('DEBUG leerJson: Buscando clave: $key');
      final s = await _storage.read(key: key);
      print('DEBUG leerJson: Contenido raw: $s');
      if (s == null) {
        print('DEBUG leerJson: No se encontró contenido para $key');
        return null;
      }
      final decoded = jsonDecode(s);
      print('DEBUG leerJson: Contenido decodificado: $decoded');
      return decoded;
    } catch (e) {
      print('DEBUG leerJson: Error: $e');
      rethrow;
    }
  }

  // Devuelve el directorio de documents
  static Future<Directory> _directorioDocuments() async {
    return await getApplicationDocumentsDirectory();
  }

  // Construye la ruta absoluta para un archivo
  static Future<String> _rutaArchivo(String nombreRelativo) async {
    final docs = await _directorioDocuments();
    final ruta = p.join(docs.path, _carpetaOffline, nombreRelativo);
    final dirPadre = Directory(p.dirname(ruta));
    if (!await dirPadre.exists()) {
      await dirPadre.create(recursive: true);
    }
    return ruta;
  }

  // Guarda datos en el almacenamiento seguro y en archivo
  static Future<void> _guardarDatos(String clave, dynamic datos) async {
    try {
      final contenido = jsonEncode(datos);
      // Guardar en secure storage
      await _storage.write(key: clave, value: contenido);

      // Guardar en archivo como respaldo
      try {
        final ruta = await _rutaArchivo('$clave.json');
        final file = File(ruta);
        await file.writeAsString(contenido, flush: true);
      } catch (e) {
        print('Error al guardar archivo local: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Guarda el detalle de un pedido en el almacenamiento local
  static Future<void> guardarPedidoDetalle(int pedidoId, dynamic detalle) async {
    try {
      final detalleKey = '$_pedidoDetalleKey$pedidoId';
      await _guardarDatos(detalleKey, detalle);
    } catch (e) {
      print('Error al guardar detalle del pedido $pedidoId: $e');
      rethrow;
    }
  }

  // Preload all order details for offline access
  static Future<bool> preloadOrderDetails() async {
    try {
      final pedidosService = PedidosService();
      
      // Get all orders
      final pedidos = await pedidosService.getPedidos();
      
      // Save each order's details
      for (final pedido in pedidos) {
        try {
          final detalle = await pedidosService.getPedidoDetalle(pedido.pediId);
          await guardarPedidoDetalle(pedido.pediId, detalle);
        } catch (e) {
          print('Error al cargar detalle del pedido ${pedido.pediId}: $e');
          continue;
        }
      }
      
      return true;
    } catch (e) {
      print('Error en preloadOrderDetails: $e');
      return false;
    }
  }

  // Guarda un pedido pendiente de sincronización
  static Future<void> guardarPedidoPendiente(Map<String, dynamic> pedidoData) async {
    try {
      // Obtener pedidos pendientes existentes
      final pedidosPendientes = await _obtenerPedidosPendientes();
      
      // Agregar el nuevo pedido
      pedidosPendientes.add(pedidoData);
      
      // Guardar la lista actualizada
      await _guardarDatos(_pedidosPendientesKey, pedidosPendientes);
      
      print('Pedido guardado para sincronización: ${pedidoData['pedidoId']}');
    } catch (e) {
      print('Error al guardar pedido pendiente: $e');
      rethrow;
    }
  }
  
  // Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<Map<String, dynamic>>> _obtenerPedidosPendientes() async {
    try {
      final datos = await _leerDatos(_pedidosPendientesKey);
      if (datos != null && datos is List) {
        return List<Map<String, dynamic>>.from(datos);
      }
      return [];
    } catch (e) {
      print('Error al obtener pedidos pendientes: $e');
      return [];
    }
  }
  
  // Sincroniza los pedidos pendientes con el servidor
  // Este método ya está implementado más abajo en el archivo
  // con la lógica completa de sincronización

  // Lee datos del almacenamiento seguro o del archivo
  static Future<dynamic> _leerDatos(String clave) async {
    try {
      print('Leyendo datos para clave: $clave');

      // Primero intentar leer de secure storage
      String? datos = await _storage.read(key: clave);

      // Si no hay datos en secure storage, intentar leer del archivo
      if (datos == null) {
        print('No se encontraron datos en secure storage, buscando en archivo...');
        try {
          final ruta = await _rutaArchivo('$clave.json');
          final file = File(ruta);

          if (await file.exists()) {
            print('Leyendo archivo: ${file.path}');
            datos = await file.readAsString();

            // Si se encontró en archivo, actualizar secure storage
            if (datos.isNotEmpty) {
              print('Datos encontrados en archivo, actualizando secure storage...');
              await _storage.write(key: clave, value: datos);
            } else {
              print('Archivo vacío');
              return null;
            }
          } else {
            print('Archivo no encontrado: ${file.path}');
            return null;
          }
        } catch (e) {
          print('Error al leer archivo local: $e');
          return null;
        }
      }

      if (datos != null && datos.isNotEmpty) {
        try {
          final decoded = jsonDecode(datos);
          print('Datos decodificados correctamente: ${decoded.runtimeType}');
          return decoded;
        } catch (e) {
          print('Error al decodificar JSON: $e');
          print('Datos crudos: $datos');
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error en _leerDatos: $e');
      rethrow;
    }
  }

  /// Guarda la lista de pedidos en el almacenamiento seguro
  static Future<void> guardarPedidos(List<PedidosViewModel> pedidos) async {
    try {
      print('=== GUARDANDO PEDIDOS ===');
      print('Cantidad de pedidos a guardar: ${pedidos.length}');

      if (pedidos.isEmpty) {
        print('Lista de pedidos vacía, no se guarda nada');
        return;
      }

      // Obtener pedidos existentes
      final pedidosExistentes = await obtenerPedidos();
      print('Pedidos existentes: ${pedidosExistentes.length}');

      // Crear un mapa para evitar duplicados usando pediId como clave
      final mapaPedidos = <int, PedidosViewModel>{};

      // Agregar pedidos existentes al mapa
      for (var pedido in pedidosExistentes) {
        mapaPedidos[pedido.pediId] = pedido;
      }
      print('Mapa inicializado con ${mapaPedidos.length} pedidos existentes');

      // Actualizar o agregar los nuevos pedidos
      for (var pedido in pedidos) {
        // Asegurarse de que los detalles estén en el formato correcto
        if (pedido.detallesJson == null && pedido.detalles.isNotEmpty) {
          pedido = PedidosViewModel(
            coFaNombreEmpresa: pedido.coFaNombreEmpresa,
            coFaDireccionEmpresa: pedido.coFaDireccionEmpresa,
            coFaRTN: pedido.coFaRTN,
            coFaCorreo: pedido.coFaCorreo,
            coFaTelefono1: pedido.coFaTelefono1,
            coFaTelefono2: pedido.coFaTelefono2,
            coFaLogo: pedido.coFaLogo,
            secuencia: pedido.secuencia,
            pediId: pedido.pediId,
            diClId: pedido.diClId,
            vendId: pedido.vendId,
            pediFechaPedido: pedido.pediFechaPedido,
            pediFechaEntrega: pedido.pediFechaEntrega,
            pedi_Codigo: pedido.pedi_Codigo,
            usuaCreacion: pedido.usuaCreacion,
            pediFechaCreacion: pedido.pediFechaCreacion,
            usuaModificacion: pedido.usuaModificacion,
            pediFechaModificacion: pedido.pediFechaModificacion,
            pediEstado: pedido.pediEstado,
            clieCodigo: pedido.clieCodigo,
            clieId: pedido.clieId,
            clieNombreNegocio: pedido.clieNombreNegocio,
            clieNombres: pedido.clieNombres,
            clieApellidos: pedido.clieApellidos,
            coloDescripcion: pedido.coloDescripcion,
            muniDescripcion: pedido.muniDescripcion,
            depaDescripcion: pedido.depaDescripcion,
            diClDireccionExacta: pedido.diClDireccionExacta,
            vendNombres: pedido.vendNombres,
            vendApellidos: pedido.vendApellidos,
            usuarioCreacion: pedido.usuarioCreacion,
            usuarioModificacion: pedido.usuarioModificacion,
            prodCodigo: pedido.prodCodigo,
            prodDescripcion: pedido.prodDescripcion,
            peDeProdPrecio: pedido.peDeProdPrecio,
            peDeCantidad: pedido.peDeCantidad,
            detalles: pedido.detalles,
            detallesJson: jsonEncode(pedido.detalles), // Asegurar que detallesJson esté en formato JSON
          );
        }
        mapaPedidos[pedido.pediId] = pedido;
      }
      print('Después de agregar nuevos: ${mapaPedidos.length} pedidos');

      // Convertir el mapa a lista
      final listaActualizada = mapaPedidos.values.toList();
      final listaJson = listaActualizada
          .map((pedido) => pedido.toMap())
          .toList();

      print('Lista final a guardar: ${listaJson.length} pedidos');

      // Guardar en la clave principal de pedidos
      await _guardarDatos(_pedidosKey, listaJson);

      // También guardar cada pedido individualmente para búsquedas más rápidas
      for (var pedido in listaActualizada) {
        await guardarDetallePedido(pedido);
      }

      print('=== PEDIDOS GUARDADOS EXITOSAMENTE ===');
    } catch (e) {
      print('Error en guardarPedidos: $e');
      rethrow;
    }
  }

  /// Procesa los detalles de un pedido para asegurar el formato correcto
  static void _procesarDetallesPedido(Map<String, dynamic> pedidoMap) {
    try {
      // Si no hay detalles pero sí hay detallesJson, intentar parsear
      if ((pedidoMap['detalles'] == null || 
          (pedidoMap['detalles'] is List && pedidoMap['detalles'].isEmpty)) &&
          pedidoMap['detallesJson'] != null) {
        try {
          if (pedidoMap['detallesJson'] is String) {
            pedidoMap['detalles'] = jsonDecode(pedidoMap['detallesJson']);
          } else {
            pedidoMap['detalles'] = pedidoMap['detallesJson'];
          }
          print('Detalles convertidos desde detallesJson: ${pedidoMap['detalles'].length} items');
        } catch (e) {
          print('Error al parsear detallesJson: $e');
          pedidoMap['detalles'] = [];
        }
      } else if (pedidoMap['detalles'] == null) {
        pedidoMap['detalles'] = [];
      }
      
      // Asegurarse de que los detalles sean una lista
      if (pedidoMap['detalles'] is! List) {
        pedidoMap['detalles'] = [pedidoMap['detalles']].whereType<dynamic>().toList();
      }
      
      // Asegurarse de que cada detalle tenga los campos necesarios
      final detalles = pedidoMap['detalles'] as List;
      for (var i = 0; i < detalles.length; i++) {
        if (detalles[i] is Map) {
          final detalle = Map<String, dynamic>.from(detalles[i]);
          detalle['descripcion'] = detalle['descripcion'] ?? detalle['prod_Descripcion'] ?? 'Producto sin descripción';
          detalle['cantidad'] = detalle['cantidad'] ?? detalle['peDe_Cantidad'] ?? 1;
          detalle['precio'] = detalle['precio'] ?? detalle['peDe_ProdPrecio'] ?? 0.0;
          detalle['imagen'] = detalle['imagen'] ?? detalle['prod_Imagen'] ?? '';
          detalles[i] = detalle;
        }
      }
      
      print('Procesados ${detalles.length} detalles para el pedido');
    } catch (e) {
      print('Error en _procesarDetallesPedido: $e');
      pedidoMap['detalles'] = [];
    }
  }

  /// Obtiene la lista de pedidos guardados localmente
  static Future<List<PedidosViewModel>> obtenerPedidos() async {
    try {
      print('=== OBTENIENDO TODOS LOS PEDIDOS ===');
      final data = await _leerDatos(_pedidosKey);

      if (data == null) {
        print('No se encontraron datos de pedidos en _pedidosKey');
        return [];
      }

      print('Tipo de datos: ${data.runtimeType}');
      print('Datos raw: $data'); // Debug adicional

      if (data is List) {
        print('Procesando lista de ${data.length} elementos');
        final List<PedidosViewModel> pedidos = [];

        for (int i = 0; i < data.length; i++) {
          try {
            final item = data[i];
            if (item is Map) {
              final pedidoMap = Map<String, dynamic>.from(item);

              // Asegurarse de que los detalles estén en el formato correcto
              _procesarDetallesPedido(pedidoMap);
              
              final pedido = PedidosViewModel.fromJson(pedidoMap);
              pedidos.add(pedido);
              print(
                'Pedido ${i + 1}: ID=${pedido.pediId} con ${pedido.detalles.length} detalles',
              );
            } else {
              print('Elemento $i no es un mapa: ${item.runtimeType}');
            }
          } catch (e, stackTrace) {
            print('Error procesando pedido en posición $i: $e');
            print('Stack trace: $stackTrace');
          }
        }

        print('Total de pedidos procesados: ${pedidos.length}');
        print('=== FIN OBTENIENDO PEDIDOS ===');
        return pedidos;
      } else if (data is Map) {
        // Si es un solo pedido (formato antiguo o error)
        print('Dato único detectado, convirtiendo a lista');
        try {
          final pedidoMap = Map<String, dynamic>.from(data);

          // Asegurarse de que los detalles estén en el formato correcto
          _procesarDetallesPedido(pedidoMap);
          
          final pedido = PedidosViewModel.fromJson(pedidoMap);
          print('Pedido único procesado: ID=${pedido.pediId} con ${pedido.detalles.length} detalles');
          return [pedido];
        } catch (e, stackTrace) {
          print('Error al procesar pedido único: $e');
          print('Stack trace: $stackTrace');
          return [];
        }
      }

      print('Formato de datos no reconocido: ${data.runtimeType}');
      return [];
    } catch (e) {
      print('Error al obtener pedidos: $e');
      return [];
    }
  }

  /// Guarda el detalle de un pedido específico
  static Future<void> guardarDetallePedido(PedidosViewModel pedido) async {
    try {
      // Guardar el detalle del pedido
      final pedidoKey = '$_pedidoDetalleKey${pedido.pediId}';
      await _guardarDatos(pedidoKey, pedido.toMap());

      // NO actualizar la lista completa aquí para evitar problemas de concurrencia
      // La lista se actualiza en guardarPedidos()
    } catch (e) {
      print('Error al guardar detalle del pedido: $e');
      rethrow;
    }
  }

  /// Obtiene el detalle de un pedido específico guardado localmente
  static Future<PedidosViewModel?> obtenerDetallePedido(int pedidoId) async {
    try {
      final pedidoKey = '$_pedidoDetalleKey$pedidoId';
      final data = await _leerDatos(pedidoKey);

      if (data == null) {
        // Si no se encuentra el detalle, intentar buscarlo en la lista general
        final todos = await obtenerPedidos();
        final pedido = todos.where((p) => p.pediId == pedidoId).isNotEmpty
            ? todos.firstWhere((p) => p.pediId == pedidoId)
            : null;

        if (pedido != null) {
          await guardarDetallePedido(pedido); // Guardar para futuras búsquedas
          return pedido;
        }
        return null;
      }

      // Asegurarse de que los datos sean un Map<String, dynamic>
      final Map<String, dynamic> pedidoData = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);

      return PedidosViewModel.fromJson(pedidoData);
    } catch (e) {
      print('Error al obtener detalle del pedido $pedidoId: $e');
      return null;
    }
  }

  /// Agrega un pedido a la lista de pendientes de sincronización
  static Future<void> agregarPedidoPendiente(PedidosViewModel pedido) async {
    try {
      print('Iniciando agregarPedidoPendiente para pedido: ${pedido.pediId}');

      // Crear un nuevo pedido con un ID si es necesario
      PedidosViewModel pedidoConId = pedido;
      if (pedido.pediId == 0) {
        pedidoConId = PedidosViewModel(
          pediId: DateTime.now().millisecondsSinceEpoch,
          diClId: pedido.diClId,
          vendId: pedido.vendId,
          pediFechaPedido: pedido.pediFechaPedido,
          pediFechaEntrega: pedido.pediFechaEntrega,
          pedi_Codigo: pedido.pedi_Codigo,
          usuaCreacion: pedido.usuaCreacion,
          pediFechaCreacion: pedido.pediFechaCreacion ?? DateTime.now(),
          pediFechaModificacion: DateTime.now(),
          usuaModificacion: pedido.usuaModificacion,
          pediEstado: pedido.pediEstado,
          clieId: pedido.clieId,
          clieCodigo: pedido.clieCodigo,
          clieNombreNegocio: pedido.clieNombreNegocio,
          clieNombres: pedido.clieNombres,
          clieApellidos: pedido.clieApellidos,
          coloDescripcion: pedido.coloDescripcion,
          muniDescripcion: pedido.muniDescripcion,
          depaDescripcion: pedido.depaDescripcion,
          diClDireccionExacta: pedido.diClDireccionExacta,
          vendNombres: pedido.vendNombres,
          vendApellidos: pedido.vendApellidos,
          usuarioCreacion: pedido.usuarioCreacion,
          usuarioModificacion: pedido.usuarioModificacion,
          prodCodigo: pedido.prodCodigo,
          prodDescripcion: pedido.prodDescripcion,
          peDeProdPrecio: pedido.peDeProdPrecio,
          peDeCantidad: pedido.peDeCantidad,
          detalles: pedido.detalles,
          detallesJson: pedido.detallesJson ?? jsonEncode(pedido.detalles),
          coFaNombreEmpresa: pedido.coFaNombreEmpresa,
          coFaDireccionEmpresa: pedido.coFaDireccionEmpresa,
          coFaRTN: pedido.coFaRTN,
          coFaCorreo: pedido.coFaCorreo,
          coFaTelefono1: pedido.coFaTelefono1,
          coFaTelefono2: pedido.coFaTelefono2,
          coFaLogo: pedido.coFaLogo,
          secuencia: pedido.secuencia,
        );
      }

      // Obtener pedidos pendientes existentes
      print('Obteniendo pedidos pendientes existentes...');
      List<PedidosViewModel> pedidosPendientes = [];

      try {
        pedidosPendientes = await obtenerPedidosPendientes();
        print('Pedidos pendientes actuales: ${pedidosPendientes.length}');
      } catch (e) {
        print('Error al obtener pedidos pendientes: $e');
        pedidosPendientes = [];
      }

      // Verificar si el pedido ya existe en la lista
      final index = pedidosPendientes.indexWhere(
        (p) => p.pediId == pedidoConId.pediId,
      );

      if (index != -1) {
        // Actualizar pedido existente
        print('Actualizando pedido existente con ID: ${pedidoConId.pediId}');
        pedidosPendientes[index] = pedidoConId;
      } else {
        // Agregar nuevo pedido
        print('Agregando nuevo pedido con ID: ${pedidoConId.pediId}');
        pedidosPendientes.add(pedidoConId);
      }

      // Convertir a lista de mapas
      final listaParaGuardar = pedidosPendientes.map((p) => p.toMap()).toList();
      print('Guardando ${listaParaGuardar.length} pedidos pendientes...');

      // Guardar la lista actualizada
      await _guardarDatos(_pedidosPendientesKey, listaParaGuardar);

      // Asegurarse de que el pedido también esté en la lista principal
      print('Guardando detalle del pedido ${pedidoConId.pediId}...');
      await guardarDetallePedido(pedidoConId);

      // Verificar que se guardó correctamente
      final pedidosGuardados = await _leerDatos(_pedidosPendientesKey);
      final totalGuardado = pedidosGuardados is List
          ? pedidosGuardados.length
          : 0;
      print('Verificación: Se guardaron $totalGuardado pedidos en total');

      print(
        'Pedido ${pedidoConId.pediId} procesado correctamente. Total pendientes: ${pedidosPendientes.length}',
      );
    } catch (e) {
      print('Error al agregar pedido pendiente: $e');
      rethrow;
    }
  }

  /// Obtiene la lista de pedidos pendientes de sincronización
  static Future<List<PedidosViewModel>> obtenerPedidosPendientes() async {
    try {
      print('=== INICIO obtenerPedidosPendientes ===');
      final data = await _leerDatos(_pedidosPendientesKey);

      if (data == null) {
        print('No se encontraron datos de pedidos pendientes');
        return [];
      }

      print('Tipo de datos recuperados: ${data.runtimeType}');
      print('Contenido raw de datos: $data'); // Debug adicional

      // Si es una lista, procesar cada elemento
      if (data is List) {
        print('Procesando lista de ${data.length} pedidos...');
        final pedidos = <PedidosViewModel>[];

        for (var i = 0; i < data.length; i++) {
          try {
            final item = data[i];
            print(
              'Procesando item $i: ${item.runtimeType} - $item',
            ); // Debug adicional

            if (item is Map) {
              final pedidoMap = item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item);

              print(
                'PedidoMap keys: ${pedidoMap.keys.toList()}',
              ); // Debug adicional
              print('pediId value: ${pedidoMap['pediId']}'); // Debug adicional

              // Verificar campos requeridos
              if (pedidoMap['pediId'] == null) {
                print('  ⚠️  Pedido sin ID, se omitirá');
                continue;
              }

              final pedido = PedidosViewModel.fromJson(pedidoMap);
              pedidos.add(pedido);
              print('  ✓ Pedido ${pedido.pediId} agregado correctamente');
            } else {
              print(
                '  ⚠️  Elemento en posición $i no es un mapa: ${item.runtimeType}',
              );
            }
          } catch (e, stackTrace) {
            print('  ❌ Error procesando pedido #$i: $e');
            print('  Stack trace: $stackTrace');
          }
        }

        print('Total de pedidos procesados exitosamente: ${pedidos.length}');
        print('=== FIN obtenerPedidosPendientes ===');
        return pedidos;
      }

      // Si es un solo pedido (formato antiguo)
      if (data is Map) {
        print('⚠️  Formato antiguo detectado: un solo pedido');
        try {
          final pedidoMap = data is Map<String, dynamic>
              ? data
              : Map<String, dynamic>.from(data);

          if (pedidoMap['pediId'] == null) {
            print('❌ Pedido sin ID, no se puede procesar');
            return [];
          }

          final pedido = PedidosViewModel.fromJson(pedidoMap);
          print('✓ Pedido único ${pedido.pediId} procesado');
          print('=== FIN obtenerPedidosPendientes ===');
          return [pedido];
        } catch (e) {
          print('❌ Error al procesar pedido único: $e');
          return [];
        }
      }

      print('❌ Formato de datos no soportado: ${data.runtimeType}');
      return [];
    } catch (e, stackTrace) {
      print('❌❌❌ ERROR CRÍTICO en obtenerPedidosPendientes ❌❌❌');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Elimina un pedido de la lista de pendientes después de sincronizar
  static Future<void> eliminarPedidoPendiente(int pedidoId) async {
    try {
      final pedidosPendientes = await obtenerPedidosPendientes();
      final nuevosPendientes = pedidosPendientes
          .where((p) => p.pediId != pedidoId)
          .toList();

      if (nuevosPendientes.length < pedidosPendientes.length) {
        // Solo guardar si hubo cambios
        await _guardarDatos(
          _pedidosPendientesKey,
          nuevosPendientes.map((p) => p.toMap()).toList(),
        );
      }
    } catch (e) {
      print('Error al eliminar pedido pendiente $pedidoId: $e');
      rethrow;
    }
  }

  /// Guarda un pedido offline siguiendo el patrón de recargas
  static Future<void> guardarPedidoOffline(Map<String, dynamic> pedidoData) async {
    try {
      print('💾 DEBUG SAVE - Iniciando guardado de pedido offline...');
      print('💾 DEBUG SAVE - Datos a guardar: $pedidoData');
      
      // Leer pedidos pendientes existentes
      final raw = await leerJson('pedidos_pendientes.json');
      List<dynamic> pendientes = raw != null ? List.from(raw as List) : [];
      
      print('💾 DEBUG SAVE - Pedidos existentes: ${pendientes.length}');
      
      // Agregar el nuevo pedido
      pendientes.add(pedidoData);
      
      print('💾 DEBUG SAVE - Total después de agregar: ${pendientes.length}');
      
      // Guardar la lista actualizada
      await guardarJson('pedidos_pendientes.json', pendientes);
      
      print('✅ DEBUG SAVE - Pedido offline guardado: ${pedidoData['local_signature']}');
      
      // Verificar que se guardó correctamente
      await mostrarPedidosOfflineGuardados();
      
    } catch (e) {
      print('❌ DEBUG SAVE - Error guardando pedido offline: $e');
      rethrow;
    }
  }

  /// Método de debugging para mostrar todos los pedidos offline guardados
  static Future<void> mostrarPedidosOfflineGuardados() async {
    try {
      print('🔍 DEBUG VIEW - Mostrando todos los pedidos offline guardados...');
      
      final raw = await leerJson('pedidos_pendientes.json');
      if (raw == null) {
        print('🔍 DEBUG VIEW - No hay archivo de pedidos pendientes');
        return;
      }
      
      if (raw is! List) {
        print('🔍 DEBUG VIEW - El archivo no contiene una lista válida: ${raw.runtimeType}');
        return;
      }
      
      final pedidos = List<Map<String, dynamic>>.from(raw);
      print('🔍 DEBUG VIEW - Total de pedidos offline: ${pedidos.length}');
      
      if (pedidos.isEmpty) {
        print('🔍 DEBUG VIEW - No hay pedidos offline guardados');
        return;
      }
      
      for (int i = 0; i < pedidos.length; i++) {
        final pedido = pedidos[i];
        print('🔍 DEBUG VIEW - Pedido $i:');
        print('   📋 ID: ${pedido['id']}');
        print('   📋 Local Signature: ${pedido['local_signature']}');
        print('   👤 Cliente ID: ${pedido['clienteId']}');
        print('   👨‍💼 Vendedor ID: ${pedido['vendedorId']}');
        print('   📍 Dirección ID: ${pedido['direccionId']}');
        print('   📅 Fecha Pedido: ${pedido['fechaPedido']}');
        print('   📅 Fecha Entrega: ${pedido['fechaEntrega']}');
        print('   💰 Total: ${pedido['total']}');
        print('   📊 Estado: ${pedido['estado']}');
        print('   🔄 Sync Attempts: ${pedido['sync_attempts'] ?? 0}');
        print('   ⏰ Created At: ${pedido['created_at']}');
        print('   📦 Detalles (${pedido['detalles']?.length ?? 0} productos):');
        
        if (pedido['detalles'] != null && pedido['detalles'] is List) {
          final detalles = List.from(pedido['detalles']);
          for (int j = 0; j < detalles.length; j++) {
            final detalle = detalles[j];
            print('      Producto $j:');
            print('        - ID: ${detalle['prodId']}');
            print('        - Cantidad: ${detalle['cantidad']}');
            print('        - Precio Unitario: ${detalle['precioUnitario']}');
            print('        - Descuento: ${detalle['descuento']}');
            print('        - Subtotal: ${detalle['subtotal']}');
          }
        }
        print('   ─────────────────────────────────────');
      }
      
    } catch (e) {
      print('❌ DEBUG VIEW - Error mostrando pedidos offline: $e');
    }
  }

  /// Obtiene pedidos pendientes simples (estilo recargas)
  static Future<List<Map<String, dynamic>>> obtenerPedidosPendientesSimple() async {
    try {
      final raw = await leerJson('pedidos_pendientes.json');
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      print('Error obteniendo pedidos pendientes simples: $e');
      return [];
    }
  }

  /// Verifica si hay pedidos pendientes
  static Future<bool> hayPedidosPendientes() async {
    try {
      final pendientes = await obtenerPedidosPendientesSimple();
      return pendientes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Cuenta pedidos pendientes
  static Future<int> contarPedidosPendientes() async {
    try {
      final pendientes = await obtenerPedidosPendientesSimple();
      return pendientes.length;
    } catch (e) {
      return 0;
    }
  }

  /// Sincroniza pedidos pendientes offline con el servidor
  static Future<int> sincronizarPedidosPendientesOffline() async {
    try {
      print('🔄 Iniciando sincronización de pedidos pendientes...');
      
      final pendientes = await obtenerPedidosPendientesSimple();
      if (pendientes.isEmpty) {
        print('✅ No hay pedidos pendientes para sincronizar');
        return 0;
      }

      final pedidosService = PedidosService();
      int sincronizadas = 0;
      final pedidosNoSincronizados = <Map<String, dynamic>>[];

      print('📋 Sincronizando ${pendientes.length} pedidos pendientes...');

      for (final pedido in pendientes) {
        try {
          print('🔄 Sincronizando pedido: ${pedido['local_signature']}');
          print('📋 DEBUG - Datos completos del pedido offline:');
          print('   - clienteId: ${pedido['clienteId']}');
          print('   - vendedorId: ${pedido['vendedorId']}');
          print('   - direccionId: ${pedido['direccionId']}');
          print('   - fechaPedido: ${pedido['fechaPedido']}');
          print('   - fechaEntrega: ${pedido['fechaEntrega']}');
          print('   - total: ${pedido['total']}');
          print('   - detalles count: ${pedido['detalles']?.length ?? 0}');
          
          final detalles = List<Map<String, dynamic>>.from(pedido['detalles']);
          print('📦 DEBUG - Detalles de productos:');
          for (int i = 0; i < detalles.length; i++) {
            print('   Producto $i: ${detalles[i]}');
            print('   ⚠️  CRÍTICO - Prod_Id que se enviará: ${detalles[i]['prodId']}');
            print('   ⚠️  CRÍTICO - Tipo de Prod_Id: ${detalles[i]['prodId'].runtimeType}');
          }
          
          // Verificar que todos los Prod_Id sean válidos
          print('🔍 VERIFICACIÓN DE PROD_IDs:');
          bool hayProductosInvalidos = false;
          for (int i = 0; i < detalles.length; i++) {
            final prodId = detalles[i]['prodId'];
            if (prodId == null) {
              print('   ❌ Producto $i tiene Prod_Id NULL');
              hayProductosInvalidos = true;
            } else if (prodId == 0) {
              print('   ❌ Producto $i tiene Prod_Id = 0 (inválido)');
              hayProductosInvalidos = true;
            } else if (prodId is! int) {
              print('   ⚠️  Producto $i tiene Prod_Id no entero: $prodId (${prodId.runtimeType})');
              // Intentar convertir a int
              try {
                final convertido = int.parse(prodId.toString());
                detalles[i]['prodId'] = convertido;
                print('   ✅ Convertido a: $convertido');
              } catch (e) {
                print('   ❌ No se pudo convertir Prod_Id: $e');
                hayProductosInvalidos = true;
              }
            } else {
              print('   ✅ Producto $i tiene Prod_Id válido: $prodId');
            }
          }
          
          if (hayProductosInvalidos) {
            print('❌ HAY PRODUCTOS CON IDs INVÁLIDOS - EL PEDIDO FALLARÁ');
            throw Exception('Productos con IDs inválidos detectados');
          }
          
          print('🌐 DEBUG - Parámetros que se enviarán a la API:');
          print('   - diClId: ${pedido['direccionId']}');
          print('   - vendId: ${pedido['vendedorId']}');
          print('   - pediCodigo: ${pedido['local_signature'] ?? 'PED-${pedido['id']}'}');
          print('   - fechaPedido: ${DateTime.parse(pedido['fechaPedido'])}');
          print('   - fechaEntrega: ${DateTime.parse(pedido['fechaEntrega'])}');
          print('   - usuaCreacion: 7 (fijo)');
          print('   - clieId: ${pedido['clienteId']}');
          print('   - detalles: $detalles');
          
          // Transformar detalles al formato exacto que espera el backend
          final detallesParaAPI = detalles.map((detalle) {
            return {
              "Prod_Id": detalle['prodId'], // Usar exactamente "Prod_Id" como espera el backend
              "PeDe_Cantidad": detalle['cantidad'],
              "PeDe_ProdPrecio": detalle['precioUnitario'],
              "PeDe_Impuesto": 0.0, // Por ahora 0, ajustar si es necesario
              "PeDe_Descuento": detalle['descuento'] ?? 0.0,
              "PeDe_Subtotal": detalle['subtotal'],
              "PeDe_ProdPrecioFinal": detalle['precioUnitario'],
            };
          }).toList();
          
          print('🔧 DEBUG - Detalles transformados para API:');
          for (int i = 0; i < detallesParaAPI.length; i++) {
            print('   Detalle API $i: ${detallesParaAPI[i]}');
            print('   ⚠️  CRÍTICO - Prod_Id final: ${detallesParaAPI[i]['Prod_Id']}');
          }
          
          final resultado = await pedidosService.insertarPedido(
            diClId: pedido['direccionId'],
            vendId: pedido['vendedorId'],
            pediCodigo: pedido['local_signature'] ?? 'PED-${pedido['id']}',
            fechaPedido: DateTime.parse(pedido['fechaPedido']),
            fechaEntrega: DateTime.parse(pedido['fechaEntrega']),
            usuaCreacion: 7, // Usuario fijo que existe en la base de datos
            clieId: pedido['clienteId'],
            detalles: detallesParaAPI, // Usar detalles transformados
          );
          
          print('📡 DEBUG - Respuesta de la API:');
          print('   - success: ${resultado['success']}');
          print('   - message: ${resultado['message']}');
          print('   - data: ${resultado['data']}');

          if (resultado != null && resultado['success'] == true) {
            sincronizadas++;
            print('✅ Pedido sincronizado: ${pedido['local_signature']}');
          } else {
            pedidosNoSincronizados.add(pedido);
            print('⚠️ Pedido no sincronizado: ${pedido['local_signature']}');
          }
        } catch (e) {
          pedidosNoSincronizados.add(pedido);
          print('❌ Error sincronizando pedido ${pedido['local_signature']}: $e');
        }
      }

      // Guardar solo los pedidos que no se pudieron sincronizar
      await guardarJson('pedidos_pendientes.json', pedidosNoSincronizados);
      
      print('🎉 Sincronización completada: $sincronizadas/${pendientes.length} pedidos sincronizados');
      return sincronizadas;
    } catch (e) {
      print('❌ Error en sincronizarPedidosPendientesOffline: $e');
      return 0;
    }
  }

  /// Sincroniza pedidos pendientes simples (estilo recargas) - método legacy
  static Future<int> sincronizarPendientes() async {
    // Usar el nuevo método mejorado
    return await sincronizarPedidosPendientesOffline();
  }

  /// Guarda una factura offline siguiendo el patrón de pedidos
  static Future<void> guardarFacturaOffline(Map<String, dynamic> facturaData) async {
    try {
      print('[DEBUG] Guardando factura offline...');
      print('[DEBUG] Datos de factura: $facturaData');
      
      // Leer facturas pendientes existentes
      final raw = await leerJson('facturas_pendientes.json');
      List<dynamic> pendientes = raw != null ? List.from(raw as List) : [];
      
      print('[DEBUG] Facturas existentes: ${pendientes.length}');
      
      // Agregar la nueva factura
      pendientes.add(facturaData);
      
      print('[DEBUG] Total después de agregar: ${pendientes.length}');
      
      // Guardar la lista actualizada
      await guardarJson('facturas_pendientes.json', pendientes);
      
      print('[DEBUG] Factura offline guardada: ${facturaData['local_signature']}');
      
    } catch (e) {
      print('[ERROR] Error guardando factura offline: $e');
      rethrow;
    }
  }

  /// Obtiene facturas pendientes offline
  static Future<List<Map<String, dynamic>>> obtenerFacturasPendientes() async {
    try {
      final raw = await leerJson('facturas_pendientes.json');
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(raw as List);
    } catch (e) {
      print('[ERROR] Error obteniendo facturas pendientes: $e');
      return [];
    }
  }

  /// Sincroniza facturas pendientes offline con el servidor
  static Future<int> sincronizarFacturasPendientes() async {
    try {
      print('[DEBUG] Iniciando sincronización de facturas pendientes...');
      
      final pendientes = await obtenerFacturasPendientes();
      if (pendientes.isEmpty) {
        print('[DEBUG] No hay facturas pendientes para sincronizar');
        return 0;
      }

      int sincronizadas = 0;
      final facturasNoSincronizadas = <Map<String, dynamic>>[];

      print('[DEBUG] Sincronizando ${pendientes.length} facturas pendientes...');

      for (final factura in pendientes) {
        try {
          print('[DEBUG] Sincronizando factura: ${factura['local_signature']}');
          
          // Implementar sincronización real con FacturaService
          await _sincronizarFacturaIndividual(factura);
          
          sincronizadas++;
          print('[DEBUG] Factura sincronizada: ${factura['local_signature']}');
          
        } catch (e) {
          facturasNoSincronizadas.add(factura);
          print('[ERROR] Error sincronizando factura ${factura['local_signature']}: $e');
        }
      }

      // Guardar solo las facturas que no se pudieron sincronizar
      await guardarJson('facturas_pendientes.json', facturasNoSincronizadas);
      
      print('[DEBUG] Sincronización de facturas completada: $sincronizadas/${pendientes.length} facturas sincronizadas');
      return sincronizadas;
    } catch (e) {
      print('[ERROR] Error en sincronizarFacturasPendientes: $e');
      return 0;
    }
  }

  /// Sincroniza una factura individual con el servidor
  static Future<void> _sincronizarFacturaIndividual(Map<String, dynamic> factura) async {
    print('[DEBUG] Sincronizando factura individual: ${factura['numeroFactura']}');
    print('[DEBUG] Datos completos de factura offline: ${jsonEncode(factura)}');
    
    // Validar datos requeridos
    if (factura['clienteId'] == null || factura['vendedorId'] == null) {
      throw Exception('Faltan datos requeridos: clienteId o vendedorId');
    }
    
    // Convertir clienteId y vendedorId a enteros
    final int clienteId = factura['clienteId'] is int 
        ? factura['clienteId'] 
        : int.tryParse(factura['clienteId'].toString()) ?? 0;
    
    final int vendedorId = factura['vendedorId'] is int 
        ? factura['vendedorId'] 
        : int.tryParse(factura['vendedorId'].toString()) ?? 0;
    
    if (clienteId <= 0 || vendedorId <= 0) {
      throw Exception('IDs inválidos: clienteId=$clienteId, vendedorId=$vendedorId');
    }
    
    // Convertir la factura offline al formato requerido por el API
    final Map<String, dynamic> facturaData = {
      'fact_Numero': factura['numeroFactura']?.toString() ?? '',
      'fact_TipoDeDocumento': 'FAC',
      'regC_Id': 21,
      'diCl_Id': clienteId,
      'vend_Id': vendedorId,
      'fact_TipoVenta': 'CO',
      'fact_FechaEmision': factura['fechaEmision'] ?? DateTime.now().toIso8601String(),
      'fact_Latitud': 0.0,
      'fact_Longitud': 0.0,
      'fact_Referencia': 'Factura sincronizada desde offline - ${factura['local_signature'] ?? ''}',
      'fact_AutorizadoPor': factura['vendedor']?.toString() ?? '',
      'usua_Creacion': vendedorId,
      'fact_EsPedido': false,
      'detallesFacturaInput': _convertirDetallesParaAPI(factura['detalles']),
    };
    
    print('[DEBUG] Datos de factura para API: ${jsonEncode(facturaData)}');
    
    // Validar que hay detalles
    if (facturaData['detallesFacturaInput'].isEmpty) {
      throw Exception('La factura no tiene productos válidos para sincronizar');
    }
    
    // Usar FacturaService para insertar la factura
    final facturaService = FacturaService();
    final response = await facturaService.insertarFactura(facturaData);
    
    print('[DEBUG] Respuesta de sincronización: ${jsonEncode(response)}');
    
    if (response['success'] != true) {
      final errorMsg = response['message'] ?? 'Error desconocido del servidor';
      print('[ERROR] Error del servidor: $errorMsg');
      throw Exception('Error del servidor: $errorMsg');
    }
    
    print('[DEBUG] Factura sincronizada exitosamente: ${factura['numeroFactura']}');
  }
  
  /// Convierte los detalles de factura offline al formato del API
  static List<Map<String, dynamic>> _convertirDetallesParaAPI(dynamic detalles) {
    final List<Map<String, dynamic>> detallesAPI = [];
    
    print('[DEBUG] Convirtiendo detalles para API: $detalles');
    print('[DEBUG] Tipo de detalles: ${detalles.runtimeType}');
    
    if (detalles is List) {
      print('[DEBUG] Procesando ${detalles.length} detalles...');
      
      for (int i = 0; i < detalles.length; i++) {
        final item = detalles[i];
        print('[DEBUG] Detalle $i: $item');
        
        if (item is Map) {
          // Intentar obtener el ID del producto de diferentes campos posibles
          final int prodId = item['id'] is int
              ? item['id']
              : item['prodId'] is int
                  ? item['prodId']
                  : int.tryParse(item['id']?.toString() ?? '') ?? 
                    int.tryParse(item['prodId']?.toString() ?? '') ?? 0;
              
          // Intentar obtener la cantidad de diferentes campos posibles
          final int cantidad = item['cantidad'] is int
              ? item['cantidad']
              : int.tryParse(item['cantidad']?.toString() ?? '') ?? 1;
          
          print('[DEBUG] Detalle $i - prodId: $prodId, cantidad: $cantidad');
          
          if (prodId > 0 && cantidad > 0) {
            final detalleAPI = {
              'prod_Id': prodId,
              'faDe_Cantidad': cantidad
            };
            detallesAPI.add(detalleAPI);
            print('[DEBUG] Detalle $i agregado: $detalleAPI');
          } else {
            print('[WARNING] Detalle $i omitido - prodId o cantidad inválidos');
          }
        } else {
          print('[WARNING] Detalle $i no es un Map: ${item.runtimeType}');
        }
      }
    } else {
      print('[ERROR] Detalles no es una lista: ${detalles.runtimeType}');
    }
    
    print('[DEBUG] Total detalles convertidos: ${detallesAPI.length}');
    return detallesAPI;
  }
}
