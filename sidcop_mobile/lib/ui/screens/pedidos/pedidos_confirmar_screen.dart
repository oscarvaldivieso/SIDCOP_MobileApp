import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/models/ProductosPedidosViewModel.dart';
import 'package:sidcop_mobile/utils/numero_en_letras.dart';
import 'package:sidcop_mobile/services/EmpresaService.dart';
import 'package:sidcop_mobile/Offline_Services/InicioSesion_OfflineService.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';

class PedidoConfirmarScreen extends StatefulWidget {
  final List<ProductoConfirmacion> productosSeleccionados;
  final int cantidadTotal;
  final num subtotal;
  final num total;
  final int clienteId;
  final DateTime fechaEntrega;
  final dynamic direccionSeleccionada; // Agregamos la dirección seleccionada

  const PedidoConfirmarScreen({
    Key? key,
    required this.productosSeleccionados,
    required this.cantidadTotal,
    required this.subtotal,
    required this.total,
    required this.clienteId,
    required this.fechaEntrega,
    required this.direccionSeleccionada, // Requerimos la dirección
  }) : super(key: key);

  @override
  State<PedidoConfirmarScreen> createState() => _PedidoConfirmarScreenState();
}

class _PedidoConfirmarScreenState extends State<PedidoConfirmarScreen> {
  late List<ProductoConfirmacion> _productosEditables;

  @override
  void initState() {
    super.initState();
    _productosEditables = List.from(widget.productosSeleccionados);
  }
 
  // Actualiza la cantidad de un producto y recalcula su precio final
  void _actualizarCantidad(int index, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarProducto(index);
      return;
    }

    setState(() {
      final producto = _productosEditables[index];

      // Recalcular precio con listas de precios y descuentos si tenemos el producto original
      num nuevoPrecioFinal = producto.precioFinal;
      if (producto.productoOriginal != null) {
        nuevoPrecioFinal = _getPrecioPorCantidad(
          producto.productoOriginal!,
          nuevaCantidad,
        );
      }

      _productosEditables[index] = ProductoConfirmacion(
        prodId: producto.prodId,
        nombre: producto.nombre,
        cantidad: nuevaCantidad,
        precioBase: producto.precioBase,
        precioFinal: nuevoPrecioFinal,
        imagen: producto.imagen,
        productoOriginal: producto.productoOriginal,
      );
    });
  }

  void _eliminarProducto(int index) {
    setState(() {
      _productosEditables.removeAt(index);
    });
  }

  // Métodos para cálculo de precios con listas de precios y descuentos
  num _getPrecioPorCantidad(ProductosPedidosViewModel producto, int cantidad) {
    // 1. Obtener el precio base según escala
    num precioBase;
    if (producto.listasPrecio != null &&
        producto.listasPrecio!.isNotEmpty &&
        cantidad > 0) {
      ListaPrecioModel? ultimaEscala;
      for (final lp in producto.listasPrecio!) {
        if (cantidad >= lp.prePInicioEscala && cantidad <= lp.prePFinEscala) {
          precioBase = lp.prePPrecioContado;
          return _aplicarDescuento(producto, cantidad, precioBase);
        }
        ultimaEscala = lp;
      }
      if (ultimaEscala != null && cantidad > ultimaEscala.prePFinEscala) {
        precioBase = ultimaEscala.prePPrecioContado;
        return _aplicarDescuento(producto, cantidad, precioBase);
      }
    }
    precioBase = producto.prodPrecioUnitario ?? 0;
    return _aplicarDescuento(producto, cantidad, precioBase);
  }

  num _aplicarDescuento(
    ProductosPedidosViewModel producto,
    int cantidad,
    num precioBase,
  ) {
    // 2. Verificar si hay descuentos y si aplica
    if (producto.descuentosEscala == null ||
        producto.descuentosEscala!.isEmpty) {
      return precioBase;
    }
    final descEsp = producto.descEspecificaciones;
    if (descEsp == null || descEsp.descTipoFactura != 'AM') {
      return precioBase;
    }
    // Buscar el descuento correspondiente
    DescuentoEscalaModel? ultimoDescuento;
    for (final desc in producto.descuentosEscala!) {
      if (cantidad >= desc.deEsInicioEscala && cantidad <= desc.deEsFinEscala) {
        return _calcularDescuento(precioBase, descEsp, desc.deEsValor);
      }
      ultimoDescuento = desc;
    }
    // Si la cantidad es mayor al último rango, usar el último descuento
    if (ultimoDescuento != null && cantidad > ultimoDescuento.deEsFinEscala) {
      return _calcularDescuento(precioBase, descEsp, ultimoDescuento.deEsValor);
    }
    return precioBase;
  }

  num _calcularDescuento(
    num precioBase,
    DescEspecificacionesModel descEsp,
    num valorDescuento,
  ) {
    if (descEsp.descTipo == 0) {
      // Porcentaje
      return precioBase - (precioBase * (valorDescuento / 100));
    } else if (descEsp.descTipo == 1) {
      // Cantidad fija
      return precioBase - valorDescuento;
    }
    return precioBase;
  }

  int get _cantidadTotal =>
      _productosEditables.fold<int>(0, (sum, p) => sum + p.cantidad);
  num get _subtotal => _productosEditables.fold<num>(
    0,
    (sum, p) => sum + (p.precioBase * p.cantidad),
  );
  num get _total => _productosEditables.fold<num>(
    0,
    (sum, p) => sum + (p.precioFinal * p.cantidad),
  );
  num get _totalDescuento {
    // Solo calcular descuentos reales (no listas de precios)
    num descuentoReal = 0;
    for (final p in _productosEditables) {
      if (p.productoOriginal != null) {
        // Obtener precio base original del producto (sin listas de precios)
        final precioOriginal = p.productoOriginal!.prodPrecioUnitario ?? 0;
        // Solo considerar como descuento si el precio final es menor al precio original
        if (p.precioFinal < precioOriginal) {
          descuentoReal += (precioOriginal - p.precioFinal) * p.cantidad;
        }
      }
    }
    return descuentoReal;
  }

  num get _totalImpuestos => _productosEditables.fold<num>(0, (sum, p) {
    if (p.productoOriginal?.impuValor != null &&
        p.productoOriginal?.prodPagaImpuesto == 'S') {
      return sum +
          (p.precioFinal * p.productoOriginal!.impuValor! * p.cantidad);
    }
    return sum;
  });

  Future<void> _confirmarPedido() async {
    // Validar productos y clienteId (ya están en la pantalla)
    if (_productosEditables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos seleccionados.')),
      );
      return;
    }
    if (widget.clienteId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se seleccionó cliente.')),
      );
      return;
    }

    // Verificar conexión a internet
    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = connectivityResult != ConnectivityResult.none;

    // Si está offline, manejar de forma diferente
    if (!isOnline) {
      await _confirmarPedidoOffline();
      return;
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Obtener datos del usuario actual para la API
      final perfilService = PerfilUsuarioService();
      final datosUsuario = await perfilService.obtenerDatosUsuario();
      if (datosUsuario == null) {
        throw Exception('No se encontraron datos del usuario');
      }

      // Debug: Imprimir todos los datos del usuario
      // print('Datos completos del usuario: $datosUsuario');
      // print('Claves disponibles: ${datosUsuario.keys.toList()}');

      final int usuaId = datosUsuario['usua_Id'] is String
          ? int.tryParse(datosUsuario['usua_Id']) ?? 0
          : datosUsuario['usua_Id'] ?? 0;

      // Usar usuaIdPersona como vendId (común en sistemas donde el vendedor es una persona)
      final int vendId = datosUsuario['usua_IdPersona'] is String
          ? int.tryParse(datosUsuario['usua_IdPersona']) ?? 0
          : datosUsuario['usua_IdPersona'] ?? 0;

      // print('usuaId obtenido: $usuaId');
      // print('vendId (usuaIdPersona) obtenido: $vendId');
      // print('usuaEsVendedor: ${datosUsuario['usua_EsVendedor']}');

      if (usuaId == 0) {
        throw Exception('Usuario ID no válido: $usuaId');
      }

      if (vendId == 0) {
        throw Exception('Vendedor ID no válido: $vendId (usuaIdPersona)');
      }

      // Verificar que el usuario es vendedor
      final bool esVendedor = datosUsuario['usua_EsVendedor'] ?? false;
      if (!esVendedor) {
        throw Exception('El usuario actual no es un vendedor autorizado');
      }

      // Preparar detalles del pedido para la API
      final detallesApi = _productosEditables.map((p) {
        // Buscar el prod_Id del producto (necesitamos agregarlo al ProductoConfirmacion)
        return {
          "prod_Id": p.prodId ?? 0, // Necesitamos agregar este campo
          "peDe_Cantidad": p.cantidad,
          "peDe_ProdPrecio": p.precioBase,
          "peDe_Impuesto": p.productoOriginal?.impuValor ?? 0 * p.precioFinal,
          "peDe_ProdDescuento":
              (p.productoOriginal?.prodPrecioUnitario ?? 0) - p.precioFinal,
          "peDe_Subtotal": p.cantidad * p.precioBase,
          "peDe_ProdPrecioFinal": p.precioFinal,
        };
      }).toList();

      // Obtener DiCl_Id de la dirección seleccionada
      // print('Dirección seleccionada completa: ${widget.direccionSeleccionada}');
      

      int diClId =
          widget.direccionSeleccionada['diCl_Id'] ??
          widget.direccionSeleccionada['DiCl_Id'] ??
          widget.direccionSeleccionada['dicl_Id'] ??
          widget.direccionSeleccionada['Id'] ??
          widget.direccionSeleccionada['id'] ??
          widget.direccionSeleccionada['ID'] ??
          0;

      // print('DiCl_Id obtenido: $diClId');

      // Validar el ID de dirección
      if (diClId == 0) {
        // Si es una dirección de sesión, usar el ID del cliente como fallback
        if (widget.direccionSeleccionada['esDeSesion'] == true) {
          print(
            'Usando dirección de sesión del vendedor, usando ID del cliente como referencia',
          );
          diClId = widget
              .clienteId; // Usar el ID del cliente como referencia para direcciones de sesión
        } else {
          throw Exception(
            'ID de dirección no válido. Dirección: ${widget.direccionSeleccionada}',
          );
        }
      }

      // print('DiCl_Id final a usar: $diClId');

      // Obtener datos necesarios para generar el código del pedido
      final clienteService = ClientesService();
      List<dynamic> direcciones = [];
      List<dynamic> clientes = [];

      try {
        direcciones = await clienteService.getDireccionesCliente(
          widget.clienteId,
        );
        // print('Direcciones obtenidas: ${direcciones.length}');
      } catch (e) {
        // print('Error obteniendo direcciones: $e');
        // Intentar desde caché offline
        try {
          final direccionesCache =
              await InicioSesionOfflineService.obtenerDireccionesClienteCache(
                widget.clienteId,
              );
          direcciones = direccionesCache;
          // print('Direcciones desde caché: ${direcciones.length}');
        } catch (cacheError) {
          // print('Error obteniendo direcciones desde caché: $cacheError');
        }
      }

      try {
        clientes = await clienteService.getClientes();
        // print('Clientes obtenidos: ${clientes.length}');
      } catch (e) {
        // print('Error obteniendo clientes: $e');
        // Intentar desde caché offline
        try {
          final clientesCache =
              await InicioSesionOfflineService.obtenerClientesRutaCache();
          clientes = clientesCache;
          // print('Clientes desde caché: ${clientes.length}');
        } catch (cacheError) {
          // print('Error obteniendo clientes desde caché: $cacheError');
        }
      }

      // Si es una dirección de sesión, agregarla a la lista de direcciones
      List<dynamic> direccionesCompletas = List.from(direcciones);
      if (widget.direccionSeleccionada['esDeSesion'] == true) {
        // Crear una dirección temporal para la generación del código
        final direccionTemporal = {
          'diCl_Id': diClId,
          'clie_Id': widget.clienteId,
          'diCl_DireccionExacta':
              widget.direccionSeleccionada['diCl_DireccionExacta'] ??
              widget.direccionSeleccionada['DiCl_DescripcionExacta'] ??
              'Dirección del vendedor',
          'diCl_EsPrincipal': true,
        };
        direccionesCompletas.add(direccionTemporal);
        // print('Agregada dirección de sesión temporal: $direccionTemporal');
      }

      // Generar el código del pedido
      final pedidosService = PedidosService();
      String pediCodigo = '';

      try {
        pediCodigo = await pedidosService.generarSiguienteCodigo(
          diClId: diClId,
          direcciones: direccionesCompletas,
          clientes: clientes,
        );
        // print('Código de pedido generado: $pediCodigo');
      } catch (e) {
        // print('Error generando código con método normal: $e');
      }

      // Si no se pudo generar el código, usar un código de fallback
      if (pediCodigo.isEmpty) {
        // print('Generando código de fallback...');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        pediCodigo = 'PED-TEMP-${widget.clienteId}-$timestamp';
        // print('Código de fallback generado: $pediCodigo');
      }

      if (pediCodigo.isEmpty) {
        throw Exception('No se pudo generar el código del pedido');
      }

      // Llamar a la API para insertar el pedido
      final resultado = await pedidosService.insertarPedido(
        diClId: diClId,
        vendId: vendId,
        pediCodigo: pediCodigo,
        fechaPedido: DateTime.now(),
        fechaEntrega: widget.fechaEntrega,
        usuaCreacion: usuaId,
        clieId: widget.clienteId,
        detalles: detallesApi,
      );

      if (!resultado['success']) {
        throw Exception(resultado['message'] ?? 'Error al crear el pedido');
      }

      // Usar el código generado como número de pedido real
      final numeroPedidoReal = pediCodigo;

      // Si el pedido se creó exitosamente, obtener datos para la factura
      final cliente = await clienteService.getClienteById(widget.clienteId);
      final empresaService = EmpresaService();
      final empresa = await empresaService.getConfiguracionFactura();
      final nombreCliente =
          ((cliente['clie_Nombres'] ?? '') +
                  ' ' +
                  (cliente['clie_Apellidos'] ?? ''))
              .trim();
      final codigoCliente = cliente['clie_Codigo'] ?? '';

      // Usar la dirección seleccionada
      final direccion =
          widget.direccionSeleccionada['DiCl_DescripcionExacta'] ??
          widget.direccionSeleccionada['descripcion'] ??
          'Dirección no especificada';
      final rtn = cliente['clie_RTN'] ?? '';

      // Obtener datos reales del usuario (vendedor) - reutilizar variables existentes
      String vendedor = 'Vendedor no especificado';
      if (datosUsuario['usua_Id'] != null) {
        final usuario = await perfilService.obtenerDatosCompletoUsuario(
          datosUsuario['usua_Id'],
        );
        if (usuario != null) {
          if (usuario['nombreCompleto'] != null &&
              usuario['nombreCompleto'].toString().isNotEmpty) {
            vendedor = usuario['nombreCompleto'];
          } else if (usuario['nombres'] != null) {
            vendedor = usuario['nombres'];
            if (usuario['apellidos'] != null) {
              vendedor += ' ' + usuario['apellidos'];
            }
          }
        }
      }

      final fechaFactura = DateTime.now();

      // Mapeo productos
      final productosFactura = _productosEditables.map((p) {
        final descuento = p.precioBase - p.precioFinal;
        String descuentoStr = '';
        if (descuento > 0) {
          descuentoStr = (descuento % 1 == 0)
              ? 'L. ${descuento.toStringAsFixed(0)}'
              : 'L. ${descuento.toStringAsFixed(2)}';
        }

        double impuestoCalculado = 0.0;
        if (p.productoOriginal?.impuValor != null &&
            p.productoOriginal?.prodPagaImpuesto == 'S') {
          impuestoCalculado = p.precioFinal * p.productoOriginal!.impuValor!;
        }

        return ProductoFactura(
          nombre: p.nombre,
          cantidad: p.cantidad,
          precio: p.precioBase,
          precioFinal: p.precioFinal,
          descuentoStr: descuentoStr,
          impuesto: impuestoCalculado,
        );
      }).toList();

      final totalDescuento = productosFactura
          .fold<num>(0, (s, p) => s + ((p.precio - p.precioFinal) * p.cantidad))
          .abs();
      final totalImpuestos = productosFactura.fold<num>(
        0,
        (s, p) => s + (p.impuesto * p.cantidad),
      );
      final totalFinal = _total + totalImpuestos;
      final totalEnLetras = NumeroEnLetras.convertir(totalFinal.truncate());

      // Cerrar loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Pedido creado exitosamente! Número: $numeroPedidoReal',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Navegar a la factura
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FacturaTicketScreen(
              empresa: empresa,
              nombreCliente: nombreCliente,
              codigoCliente: codigoCliente,
              direccion: direccion,
              rtn: rtn,
              vendedor: vendedor,
              fechaFactura:
                  '${fechaFactura.day.toString().padLeft(2, '0')}/${fechaFactura.month.toString().padLeft(2, '0')}/${fechaFactura.year}',
              fechaEntrega:
                  '${widget.fechaEntrega.day.toString().padLeft(2, '0')}/${widget.fechaEntrega.month.toString().padLeft(2, '0')}/${widget.fechaEntrega.year}',
              numeroFactura: numeroPedidoReal,
              productos: productosFactura,
              subtotal: _subtotal,
              totalDescuento: totalDescuento,
              total: totalFinal,
              totalEnLetras: totalEnLetras,
            ),
          ),
        );
      }
    } catch (e) {
      // Cerrar loading si hay error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      // print('Error completo al crear pedido: $e');
    }
  }

  Future<void> _confirmarPedidoOffline() async {
    try {
      // print(' DEBUG OFFLINE - Iniciando confirmación de pedido offline...');

      // Obtener datos del usuario actual
      final perfilService = PerfilUsuarioService();
      final userData = await perfilService.obtenerDatosUsuario();

      // print(' DEBUG OFFLINE - Datos del usuario:');
      // print('   - userData completo: $userData');
      // print('   - usua_IdPersona: ${userData?['usua_IdPersona']}');
      // print('   - usua_Id: ${userData?['usua_Id']}');
      // print('   - usua_EsVendedor: ${userData?['usua_EsVendedor']}');

      final int? vendedorId = userData?['usua_IdPersona'] is String
          ? int.tryParse(userData?['usua_IdPersona'])
          : userData?['usua_IdPersona'];

      // print('   - vendedorId procesado: $vendedorId');

      // Debug de productos editables
      // print(' DEBUG OFFLINE - Productos editables:');
      for (int i = 0; i < _productosEditables.length; i++) {
        final p = _productosEditables[i];
        // print('   Producto $i:');
        // print('     - prodId: ${p.prodId}');
        // print('     - nombre: ${p.nombre}');
        // print('     - cantidad: ${p.cantidad}');
        // print('     - precioBase: ${p.precioBase}');
        // print('     - precioFinal: ${p.precioFinal}');
        // print('     - descuento por unidad: ${p.precioBase - p.precioFinal}');
        // print('     - subtotal: ${p.precioFinal * p.cantidad}');
      }

      // Preparar detalles del pedido para guardar offline
      final detallesPedido = _productosEditables.map((p) {
        final detalle = {
          'prodId': p.prodId,
          'cantidad': p.cantidad,
          'precioUnitario': p.precioFinal,
          'descuento': (p.precioBase - p.precioFinal) * p.cantidad,
          'subtotal': p.precioFinal * p.cantidad,
        };
        return detalle;
      }).toList();

      // print(' DEBUG OFFLINE - Detalles del pedido preparados:');
      for (int i = 0; i < detallesPedido.length; i++) {
        // print('   Detalle $i: ${detallesPedido[i]}');
      }

      // Debug de dirección seleccionada
      // print(' DEBUG OFFLINE - Dirección seleccionada:');
      // print(
      //   '   - direccionSeleccionada completa: ${widget.direccionSeleccionada}',
      // );
      // print(
      //   '   - claves disponibles: ${widget.direccionSeleccionada.keys.toList()}',
      // );

      final direccionId =
          widget.direccionSeleccionada['diCl_Id'] ??
          widget.direccionSeleccionada['DiCl_Id'] ??
          widget.clienteId;
      // print('   - direccionId final: $direccionId');

      // // Debug de totales
      // print(' DEBUG OFFLINE - Totales calculados:');
      // print('   - _total: $_total');
      // print('   - _subtotal: $_subtotal');
      // print('   - _cantidadTotal: $_cantidadTotal');

      // Generar código de pedido usando el mismo método que los pedidos online
      String pediCodigo = '';
      try {
        // print(' DEBUG OFFLINE - Generando código de pedido...');

        // Obtener direcciones desde caché offline
        List<dynamic> direcciones = [];
        try {
          final direccionesCache =
              await InicioSesionOfflineService.obtenerDireccionesClienteCache(
                widget.clienteId,
              );
          direcciones = direccionesCache;
          // print('   - Direcciones desde caché: ${direcciones.length}');
        } catch (cacheError) {
          // print('   - Error obteniendo direcciones desde caché: $cacheError');
        }

        // Obtener clientes desde caché offline
        List<dynamic> clientes = [];
        try {
          final clientesCache =
              await InicioSesionOfflineService.obtenerClientesRutaCache();
          clientes = clientesCache;
          // print('   - Clientes desde caché: ${clientes.length}');
        } catch (cacheError) {
          // print('   - Error obteniendo clientes desde caché: $cacheError');
        }

        // Si es una dirección de sesión, agregarla a la lista de direcciones
        List<dynamic> direccionesCompletas = List.from(direcciones);
        if (widget.direccionSeleccionada['esDeSesion'] == true) {
          final direccionTemporal = {
            'diCl_Id': direccionId,
            'clie_Id': widget.clienteId,
            'diCl_DireccionExacta':
                widget.direccionSeleccionada['diCl_DireccionExacta'] ??
                widget.direccionSeleccionada['DiCl_DescripcionExacta'] ??
                'Dirección del vendedor',
            'diCl_EsPrincipal': true,
          };
          direccionesCompletas.add(direccionTemporal);
          // print('   - Agregada dirección de sesión temporal');
        }

        // Generar el código usando el mismo método que los pedidos online
        final pedidosService = PedidosService();
        pediCodigo = await pedidosService.generarSiguienteCodigo(
          diClId: direccionId,
          direcciones: direccionesCompletas,
          clientes: clientes,
        );
        // print('   - Código de pedido generado: $pediCodigo');
      } catch (e) {
        // print('   - Error generando código con método normal: $e');
      }

      // Si no se pudo generar el código, usar un código de fallback
      if (pediCodigo.isEmpty) {
        // print('   - Generando código de fallback...');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        pediCodigo = 'PED-${widget.clienteId}-$timestamp';
        // print('   - Código de fallback generado: $pediCodigo');
      }

      // Crear objeto de pedido offline
      final pedidoOffline = {
        'id': DateTime.now().microsecondsSinceEpoch,
        'clienteId': widget.clienteId,
        'vendedorId': vendedorId,
        'fechaPedido': DateTime.now().toIso8601String(),
        'fechaEntrega': widget.fechaEntrega.toIso8601String(),
        'direccionId': direccionId,
        'total': _total,
        'estado': 'Pendiente Sincronización',
        'detalles': detallesPedido,
        'offline': true,
        'local_signature':
            pediCodigo, // Usar el código generado en lugar del timestamp
        'created_at': DateTime.now().toIso8601String(),
        'sync_attempts': 0,
      };

      // print('DEBUG OFFLINE - Objeto pedido offline completo:');
      // print('$pedidoOffline');

      // Guardar el pedido localmente
      // print(' DEBUG OFFLINE - Guardando pedido offline...');
      await PedidosScreenOffline.guardarPedidoOffline(pedidoOffline);
      // print(' DEBUG OFFLINE - Pedido guardado exitosamente');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Pedido guardado offline! Número: $pediCodigo'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Mostrar mensaje de confirmación y navegar de vuelta
      if (mounted) {
        // Navegar de vuelta a la pantalla principal después de un breve delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar pedido offline: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      // print('Error en _confirmarPedidoOffline: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(permisos: []),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F6F6), Color(0xFFF6F6F6)],
          ),
        ),
        child: Column(
          children: [
            // Header similar to AppBackground
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.03,
                left: 16,
                right: 16,
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Container(
                  color: const Color(0xFF141A2F),
                  child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.10,
                    child: Stack(
                      children: [
                        // Título alineado a la izquierda y centrado verticalmente
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Text(
                              'Confirmar Pedido',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Satoshi',
                                  ),
                            ),
                          ),
                        ),
                        // Icono alineado a la esquina inferior derecha
                        Positioned(
                          bottom: 12,
                          right: 18,
                          child: Icon(
                            Icons.check_circle_outline,
                            color: const Color(0xFFE0C7A0),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contenido scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos seleccionados:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._productosEditables.asMap().entries.map((entry) {
                      final index = entry.key;
                      final p = entry.value;
                      // print(p.prodId);
                      // print(p.nombre);
                      // print(p.cantidad);
                      // print(p.precioFinal);
                      // print(p.precioBase);
                      // print(p.productoOriginal?.toJson());
                      // print(p.productoOriginal?.prodPagaImpuesto);
                      if (p.productoOriginal?.descuentosEscala != null) {
                        for (
                          int i = 0;
                          i < p.productoOriginal!.descuentosEscala!.length;
                          i++
                        ) {
                          print(
                            p.productoOriginal?.descuentosEscala![i].toJson(),
                          );
                        }
                      }
                      // print(p.productoOriginal?.descuentosEscala?.toJson());

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Dismissible(
                          key: Key('producto_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Eliminar producto'),
                                  content: Text(
                                    '¿Estás seguro de que quieres eliminar "${p.nombre}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            _eliminarProducto(index);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${p.nombre}" eliminado'),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFF0F0F0),
                                width: 1,
                              ),
                            ),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header con información del producto
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Información del producto
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.nombre ?? 'Producto sin nombre',
                                            style: const TextStyle(
                                              fontFamily: 'Satoshi',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF141A2F),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Código: ${p.prodId ?? 'N/A'}',
                                              style: const TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 11,
                                                color: Color(0xFF6B7280),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Precio unitario y cantidad
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEFF6FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF3B82F6,
                                                    ),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  'L. ${p.productoOriginal?.prodPrecioUnitario?.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontFamily: 'Satoshi',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '× ${p.cantidad.toStringAsFixed(p.cantidad.truncateToDouble() == p.cantidad ? 0 : 1)}',
                                                style: const TextStyle(
                                                  fontFamily: 'Satoshi',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF374151),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Controles de cantidad
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Botón disminuir cantidad
                                            GestureDetector(
                                              onTap: () {
                                                if (p.cantidad > 1) {
                                                  _actualizarCantidad(
                                                    index,
                                                    p.cantidad - 1,
                                                  );
                                                } else {
                                                  _actualizarCantidad(index, 0);
                                                }
                                              },
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF3F4F6,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE5E7EB,
                                                    ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 48,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF141A2F,
                                                  ),
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  p.cantidad.toInt().toString(),
                                                  style: const TextStyle(
                                                    fontFamily: 'Satoshi',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF141A2F),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Botón aumentar cantidad
                                            GestureDetector(
                                              onTap: () {
                                                _actualizarCantidad(
                                                  index,
                                                  p.cantidad + 1,
                                                );
                                              },
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF141A2F,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ), //WARD ROW

                                const SizedBox(height: 16), //WARD
                                // Separador
                                Container(
                                  height: 1,
                                  color: const Color(0xFFF0F0F0),
                                ),

                                const SizedBox(height: 16),

                                //calculos
                                Column(
                                  children: [
                                    // Subtotal
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6B7280),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Subtotal',
                                              style: TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'L. ${((p.productoOriginal?.prodPrecioUnitario ?? 0) * p.cantidad).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Descuento (si aplica)
                                    if (p.precioFinal !=
                                        (p
                                                .productoOriginal
                                                ?.prodPrecioUnitario ??
                                            0)) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF10B981,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Descuento L. (${((p.productoOriginal?.prodPrecioUnitario ?? 0) - p.precioFinal).toStringAsFixed(0)})',
                                                style: const TextStyle(
                                                  fontFamily: 'Satoshi',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF374151),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '-L. ${(((p.productoOriginal?.prodPrecioUnitario ?? 0) - p.precioFinal) * p.cantidad).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontFamily: 'Satoshi',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    const SizedBox(height: 8),

                                    // ISV
                                    if ((p.productoOriginal?.prodPagaImpuesto ??
                                            "N") ==
                                        "S")
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF374151),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'ISV (${(((p.productoOriginal?.impuValor ?? 0) * 100).toInt()).toStringAsFixed(0)}%)',
                                                style: TextStyle(
                                                  fontFamily: 'Satoshi',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF374151),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '+L. ${(((p.productoOriginal?.impuValor ?? 0) * p.precioFinal) * p.cantidad).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontFamily: 'Satoshi',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),

                                    const SizedBox(height: 12),

                                    // Separador para el total
                                    Container(
                                      height: 1,
                                      color: const Color(0xFFE5E7EB),
                                    ),

                                    const SizedBox(height: 12),

                                    // Total del producto
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF141A2F),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Total producto',
                                              style: TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF141A2F),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF141A2F),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'L. ${(p.precioFinal * p.cantidad + (((p.productoOriginal?.impuValor ?? 0) * p.precioFinal) * p.cantidad)).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              //ward
                                              fontFamily: 'Satoshi',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Información de entrega
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Información de entrega:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fecha: ${widget.fechaEntrega.day.toString().padLeft(2, '0')}/${widget.fechaEntrega.month.toString().padLeft(2, '0')}/${widget.fechaEntrega.year}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dirección: ${widget.direccionSeleccionada['DiCl_DescripcionExacta'] ?? widget.direccionSeleccionada['descripcion'] ?? 'Dirección no especificada'}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Cantidad total de productos: $_cantidadTotal',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Subtotal: L. ${_subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Descuento: L. ${_totalDescuento.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Impuestos: L. ${_totalImpuestos.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Total Final: L. ${(_total + _totalImpuestos).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(
                            height: 80,
                          ), // Espacio para el botón fijo
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _confirmarPedido,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0C7A0),
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ),
      ),
    );
  }
}

class ProductoConfirmacion {
  final int? prodId;
  final String nombre;
  int cantidad;
  final num precioBase;
  num precioFinal;
  final String? imagen;
  final ProductosPedidosViewModel?
  productoOriginal; // Referencia al producto original para cálculos

  ProductoConfirmacion({
    this.prodId,
    required this.nombre,
    required this.cantidad,
    required this.precioBase,
    required this.precioFinal,
    this.imagen,
    this.productoOriginal,
  });
}
