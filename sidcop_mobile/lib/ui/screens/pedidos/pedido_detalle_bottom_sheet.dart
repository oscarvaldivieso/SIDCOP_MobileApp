import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/FacturaSyncService.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/invoice_preview_screen.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';

class PedidoDetalleBottomSheet extends StatefulWidget {
  final PedidosViewModel pedido;
  const PedidoDetalleBottomSheet({super.key, required this.pedido});

  @override
  State<PedidoDetalleBottomSheet> createState() =>
      _PedidoDetalleBottomSheetState();
}

class _PedidoDetalleBottomSheetState extends State<PedidoDetalleBottomSheet> {
  final FacturaService _facturaService = FacturaService();
  bool _isInsertingInvoice = false;
  bool _isSyncing = false;

  Color get _primaryColor => const Color(0xFF141A2F);
  Color get _goldColor => const Color(0xFFE0C7A0);
  Color get _surfaceColor => const Color(0xFFF8FAFC);
  Color get _borderColor => const Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Color(0xFFE0C7A0),
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Detalle del Pedido',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  _isInsertingInvoice
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black54,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.shopping_cart,
                            color: Colors.black54,
                          ),
                          onPressed: () async {
                            // print('\n=== BOTÓN DE FACTURA PRESIONADO ===');
                            // Insertar la factura (la navegación se maneja dentro del método)
                            await _insertarFactura();
                            // print('=== BOTÓN DE FACTURA COMPLETADO ===\n');
                          },
                          tooltip: 'Ver Factura',
                        ),
                  const SizedBox(width: 8),
                  _isSyncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.sync,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            await _sincronizarFacturasOffline();
                          },
                          tooltip: 'Sincronizar Facturas Offline',
                        ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildInfoCard(
                icon: Icons.store,
                title: 'Negocio',
                value: widget.pedido.clieNombreNegocio ?? '-',
                color: _goldColor,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.event,
                      title: 'Pedido',
                      value: _formatFecha(widget.pedido.pediFechaPedido),
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.local_shipping,
                      title: 'Entrega',
                      value: _formatFecha(widget.pedido.pediFechaEntrega),
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Productos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              detalles.isEmpty
                  ? const Text('No hay productos en este widget.pedido.')
                  : Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: detalles.length,
                        separatorBuilder: (_, __) => const Divider(height: 22),
                        itemBuilder: (context, i) {
                          final item = detalles[i];
                          return _buildDetalleItem(item);
                        },
                      ),
                    ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _parseDetalles(String? detallesJson) {
    try {
      if (detallesJson == null || detallesJson.isEmpty) {
        // Si no hay detallesJson, verificar si hay detalles directos en el pedido
        if (widget.pedido.detalles.isNotEmpty) {
          return widget.pedido.detalles;
        }
        return [];
      }

      // Intentar parsear como JSON
      final parsed = jsonDecode(detallesJson);

      // Si es una lista, devolverla directamente
      if (parsed is List) return parsed;

      // Si es un mapa, verificar si tiene una propiedad 'detalles' o similar
      if (parsed is Map) {
        if (parsed['detalles'] is List) {
          return parsed['detalles'];
        }
        // Si no tiene 'detalles', devolver el mapa dentro de una lista
        return [parsed];
      }

      return [];
    } catch (e) {
      print('Error al parsear detalles del pedido: $e');
      // Si hay un error, verificar si hay detalles directos en el pedido
      if (widget.pedido.detalles.isNotEmpty) {
        return widget.pedido.detalles;
      }
      return [];
    }
  }

  Widget _buildDetalleItem(dynamic item) {
    // Handle different possible field names for product details
    final Map<String, dynamic> itemMap = item is Map
        ? Map<String, dynamic>.from(item)
        : {};

    // Try different possible field names for description
    final String descripcion =
        itemMap['descripcion']?.toString() ??
        itemMap['prod_Descripcion']?.toString() ??
        itemMap['producto']?.toString() ??
        'Producto sin nombre';

    // Try different possible field names for image
    final String imagen =
        itemMap['imagen']?.toString() ??
        itemMap['prod_Imagen']?.toString() ??
        '';

    // Try different possible field names for quantity
    final int cantidad = _parseIntFromDynamic(
      itemMap['cantidad'] ??
          itemMap['peDe_Cantidad'] ??
          itemMap['cantidadProducto'],
    );

    // Try different possible field names for price
    final double precio = _parseDoubleFromDynamic(
      itemMap['precio'] ??
          itemMap['peDe_Precio'] ??
          itemMap['peDe_ProdPrecio'] ??
          itemMap['precioProducto'],
    );

    // Debug print to see the actual item structure
    print('Detalle del ítem: $itemMap');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imagen.isNotEmpty
              ? Image.network(imagen, width: 60, height: 60, fit: BoxFit.cover)
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    size: 32,
                    color: Colors.grey,
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descripcion,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text('Cantidad: $cantidad', style: const TextStyle(fontSize: 13)),
              Text('Precio: L. $precio', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to parse int from dynamic value
  int _parseIntFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  // Helper method to parse double from dynamic value
  double _parseDoubleFromDynamic(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '-';
    DateTime? f;
    if (fecha is DateTime) {
      f = fecha;
    } else if (fecha is String && fecha.isNotEmpty) {
      try {
        f = DateTime.parse(fecha);
      } catch (_) {}
    }
    if (f == null) return '-';
    final meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return "${f.day} de ${meses[f.month]} del ${f.year}";
  }

  Future<void> _insertarFactura() async {
    print('\n=== _insertarFactura INICIADO ===');

    if (_isInsertingInvoice) {

      return;
    }

    print('CAMBIANDO ESTADO A _isInsertingInvoice = true');
    setState(() {
      _isInsertingInvoice = true;
    });

    try {
      print('VERIFICANDO CONECTIVIDAD...');
      // Verificar conectividad
      final hasConnection = await SyncService.hasInternetConnection();
      print('[DEBUG] Conectividad disponible: $hasConnection');

      if (hasConnection) {
        print('MODO ONLINE - LLAMANDO _insertarFacturaOnline()');
        // Modo online - usar el flujo original
        await _insertarFacturaOnline();
        print('_insertarFacturaOnline() COMPLETADO');
      } else {
        print('MODO OFFLINE - LLAMANDO _insertarFacturaOffline()');
        // Modo offline - guardar localmente y mostrar factura
        await _insertarFacturaOffline();
        print('_insertarFacturaOffline() COMPLETADO');
      }
    } catch (e, stackTrace) {
      print('\n=== EXCEPCIÓN EN _insertarFactura ===');
      print('TIPO: ${e.runtimeType}');
      print('MENSAJE: $e');
      print('STACK TRACE: $stackTrace');
      if (mounted) {
        // Verificar si es un error de inventario insuficiente
        if (e is InventarioInsuficienteException) {
          // Mostrar un diálogo con el mensaje de error de inventario insuficiente
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text(
                  'Inventario Insuficiente',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Entendido'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        } else {
          // Mostrar un SnackBar para otros tipos de errores
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrar la factura: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      print('EJECUTANDO BLOQUE FINALLY');
      if (mounted) {
        print('WIDGET MONTADO - CAMBIANDO _isInsertingInvoice = false');
        setState(() {
          _isInsertingInvoice = false;
        });
      } else {
        print('WIDGET NO MONTADO - NO SE PUEDE CAMBIAR ESTADO');
      }
      print('=== _insertarFactura FINALIZADO ===\n');
    }
  }

  Future<void> _insertarFacturaOnline() async {
    print('=== INICIANDO INSERCIÓN DE FACTURA ONLINE ===');
    print('PEDIDO ID: ${widget.pedido.pediId}');
    print('CLIENTE ID: ${widget.pedido.clieId}');
    print('VENDEDOR ID: ${widget.pedido.vendId}');
    print('CODIGO PEDIDO: ${widget.pedido.pedi_Codigo}');
    print('=== DEBUGGING USUARIO ID ===');
    print('globalVendId actual: $globalVendId');
    print('widget.pedido.usuaCreacion: ${widget.pedido.usuaCreacion}');
    print('widget.pedido.vendId: ${widget.pedido.vendId}');
    print('Tipo de globalVendId: ${globalVendId.runtimeType}');

    // Obtener la ubicación actual (si no está disponible, usar valores predeterminados)
    final double latitud = 0.0; // Idealmente obtener la ubicación actual
    final double longitud = 0.0; // Idealmente obtener la ubicación actual

    // Parsear los detalles del pedido para obtener los productos
    final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);

    // Log para ver el contenido de detallesJson
    print('DETALLES JSON RAW: ${widget.pedido.detallesJson}');
    print('DETALLES PARSEADOS: $detalles');
    print('CANTIDAD DE DETALLES: ${detalles.length}');

    // Crear la lista de detallesFacturaInput
    final List<Map<String, dynamic>> detallesFactura = [];

    // Recorrer los productos y añadirlos al formato requerido
    for (int index = 0; index < detalles.length; index++) {
      var item = detalles[index];
      print('--- PROCESANDO ITEM $index ---');
      print('ITEM COMPLETO: ${jsonEncode(item)}');
      print('TIPO DE ITEM: ${item.runtimeType}');

      if (item is Map) {
        print('KEYS DISPONIBLES EN ITEM: ${item.keys.toList()}');
        print('VALUES EN ITEM: ${item.values.toList()}');
      }

      // Extraer el ID del producto con múltiples intentos
      final int prodId = item['id'] is int
          ? item['id']
          : item['prod_Id'] is int
          ? item['prod_Id']
          : item['prodId'] is int
          ? item['prodId']
          : int.tryParse(item['id']?.toString() ?? '') ??
                int.tryParse(item['prod_Id']?.toString() ?? '') ??
                int.tryParse(item['prodId']?.toString() ?? '') ??
                0;

      // Extraer la cantidad con múltiples intentos
      final int cantidad = item['cantidad'] is int
          ? item['cantidad']
          : item['peDe_Cantidad'] is int
          ? item['peDe_Cantidad']
          : item['faDe_Cantidad'] is int
          ? item['faDe_Cantidad']
          : int.tryParse(item['cantidad']?.toString() ?? '') ??
                int.tryParse(item['peDe_Cantidad']?.toString() ?? '') ??
                int.tryParse(item['faDe_Cantidad']?.toString() ?? '') ??
                0;

      print('PROD_ID EXTRAÍDO: $prodId');
      print('CANTIDAD EXTRAÍDA: $cantidad');

      // Solo añadir productos con ID y cantidad válidos
      if (prodId > 0 && cantidad > 0) {
        final detalleItem = {'prod_Id': prodId, 'faDe_Cantidad': cantidad};
        detallesFactura.add(detalleItem);
        print('DETALLE AÑADIDO: ${jsonEncode(detalleItem)}');
      } else {
        print('ITEM IGNORADO - ID o cantidad inválidos');
      }
    }

    print('DETALLES FACTURA FINAL: $detallesFactura');

    // Determinar el Usua_Id a usar con validación
    final int usuaIdToUse = globalVendId ?? 1;
    
    // Preparar los datos de la factura
    final Map<String, dynamic> facturaData = {
      'fact_Numero': widget.pedido.pedi_Codigo,
      'fact_TipoDeDocumento': 'FAC', // Factura
      'regC_Id': 21, // Cambiado de 1 a 21 para encontrar un rango CAI válido
      'diCl_Id': widget.pedido.diClId,
      'vend_Id': widget.pedido.vendId,
      'fact_TipoVenta': 'CO', // Contado
      'fact_FechaEmision': DateTime.now().toIso8601String(),
      'fact_Latitud': latitud,
      'fact_Longitud': longitud,
      'fact_Referencia': 'Pedido generado desde app móvil',
      'fact_AutorizadoPor': widget.pedido.vendNombres ?? '',
      'Usua_Creacion': 1, // CORREGIDO: Usar Usua_Creacion en lugar de Usua_Id
      'fact_EsPedido': true, // Marcar como pedido
      'pedi_Id': widget.pedido.pediId, // ID del pedido actual
      'detallesFacturaInput': detallesFactura, // Añadir los productos
    };

    // Log detallado del objeto que se envía a la API
    print('=== DATOS DE FACTURA A ENVIAR ===');
    print('FACTURA DATA KEYS: ${facturaData.keys.toList()}');
    print('OBJETO COMPLETO A ENVIAR:');
    print(jsonEncode(facturaData));
    print('TAMAÑO DEL JSON: ${jsonEncode(facturaData).length} caracteres');
    print('DETALLES FACTURA COUNT: ${detallesFactura.length}');

    // Llamar al servicio para insertar la factura
    print('=== LLAMANDO AL SERVICIO DE FACTURA ===');
    
    try {
      final response = await _facturaService.insertarFactura(facturaData);
     
      // Si hay error, mostrar detalles adicionales
      if (response['code_Status'] != 1 || response['success'] == false) {
        print('=== ERROR EN LA INSERCIÓN ===');
        print('STATUS CODE: ${response['code_Status']}');
        print('SUCCESS FLAG: ${response['success']}');
        print('ERROR MESSAGE: ${response['message']}');
        print('STATUS MESSAGE: ${response['message_Status']}');
        
        // Lanzar excepción con el mensaje de error del servidor
        throw Exception(response['message_Status'] ?? response['message'] ?? 'Error desconocido en la inserción');
      }
    } catch (e) {
  
      rethrow; // Re-lanzar la excepción para que sea manejada por el bloque superior
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura registrada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Si la inserción fue exitosa, navegar a la pantalla de vista previa
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoicePreviewScreen(pedido: widget.pedido),
        ),
      );
    }
  }

  // Actualiza tu método _insertarFacturaOffline en PedidoDetalleBottomSheet

  Future<void> _insertarFacturaOffline() async {
    final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);

    final int usuaIdToUse = 1;

    // Crear la estructura de la factura offline IDÉNTICA a la online
    final Map<String, dynamic> facturaOffline = {
      // Campos básicos de identificación
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'local_signature': DateTime.now().millisecondsSinceEpoch.toString(),
      'offline': true,
      'sync_status': 'pending',
      'sync_attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
      
      // DATOS EXACTOS COMO LA FACTURA ONLINE
      'fact_Numero': widget.pedido.pedi_Codigo,
      'fact_TipoDeDocumento': 'FAC',
      'regC_Id': 21,
      'diCl_Id': widget.pedido.diClId,
      'vend_Id': widget.pedido.vendId,
      'fact_TipoVenta': 'CO',
      'fact_FechaEmision': DateTime.now().toIso8601String(),
      'fact_Latitud': 0.0,
      'fact_Longitud': 0.0,
      'fact_Referencia': 'Pedido generado desde app móvil',
      'fact_AutorizadoPor': widget.pedido.vendNombres ?? '',
      'Usua_Creacion': 1,
      'fact_EsPedido': true,
      'pedi_Id': widget.pedido.pediId,
      'detallesFacturaInput': detalles,
      
      // Campos adicionales para compatibilidad
      'numeroFactura': widget.pedido.pedi_Codigo,
      'clienteId': widget.pedido.clieId,
      'vendedorId': widget.pedido.vendId,
      'direccionId': widget.pedido.diClId,
      'usuaCreacion': usuaIdToUse,
      'fechaEmision': DateTime.now().toIso8601String(),
      'nombreCliente': widget.pedido.clieNombreNegocio ?? 'Cliente',
      'vendedor': widget.pedido.vendNombres ?? 'Vendedor',
      'detalles': detalles,
    };

    // Guardar la factura offline
    try {
      await PedidosScreenOffline.guardarFacturaOffline(facturaOffline);
      print(
        '[DEBUG] Factura offline guardada exitosamente con ID: ${facturaOffline['id']}',
      );

      if (mounted) {
        // Mostrar mensaje de éxito offline con alerta prominente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.offline_bolt, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '📱 FACTURA GUARDADA OFFLINE\nSe sincronizará automáticamente cuando haya conexión a internet.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Mostrar diálogo de confirmación adicional
        _mostrarDialogoFacturaOffline(facturaOffline);

        // Intentar sincronización inmediata (por si regresó la conexión)
        _intentarSincronizacionInmediata();

        // Inicializar el sistema de sincronización automática
        FacturaSyncService.inicializarSincronizacion();

        // Navegar directamente a la pantalla de factura con los datos offline
        await _mostrarFacturaOffline(facturaOffline, detalles);
      }
    } catch (e) {
      throw Exception('Error guardando factura offline: $e');
    }
  }

  /// Muestra un diálogo de confirmación para factura offline
  void _mostrarDialogoFacturaOffline(Map<String, dynamic> facturaOffline) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.offline_bolt,
            color: Colors.orange,
            size: 48,
          ),
          title: const Text(
            'Factura Guardada Offline',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Número: ${facturaOffline['numeroFactura']}'),
              Text('Cliente: ${facturaOffline['nombreCliente']}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La factura se sincronizará automáticamente cuando se restaure la conexión a internet.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Intenta sincronización inmediata en caso de que la conexión haya regresado
  Future<void> _intentarSincronizacionInmediata() async {

    // Esperar un momento para que el usuario vea el mensaje
    await Future.delayed(const Duration(seconds: 2));

    // Verificar si hay conexión
    final hasConnection = await SyncService.hasInternetConnection();
    if (hasConnection) {
      print('[DEBUG] Conexión disponible, intentando sincronizar facturas pendientes...');
      
      try {
        final sincronizadas = await FacturaSyncService.sincronizarFacturasPendientes();
        
        if (sincronizadas > 0 && mounted) {
          // Mostrar mensaje de sincronización exitosa
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cloud_done, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ $sincronizadas factura(s) sincronizada(s) exitosamente con el servidor',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        print('[ERROR] Error en sincronización inmediata: $e');
      }
    } else {
      print('[DEBUG] Sin conexión, factura permanece offline');
    }
  }

  Future<void> _mostrarFacturaOffline(
    Map<String, dynamic> facturaData,
    List<dynamic> detalles,
  ) async {
    // Preparar los productos para la pantalla de factura
    List<ProductoFactura> productos = [];
    double subtotal = 0.0;
    double totalDescuento = 0.0;

    for (var item in detalles) {
      final String descripcion =
          item['descripcion']?.toString() ??
          item['prod_Descripcion']?.toString() ??
          item['producto']?.toString() ??
          'Producto sin nombre';

      final int cantidad = _parseIntFromDynamic(
        item['cantidad'] ?? item['peDe_Cantidad'] ?? item['cantidadProducto'],
      );

      final double precio = _parseDoubleFromDynamic(
        item['precio'] ??
            item['peDe_Precio'] ??
            item['peDe_ProdPrecio'] ??
            item['precioProducto'],
      );

      final double descuento = _parseDoubleFromDynamic(
        item['descuento'] ?? item['peDe_Descuento'] ?? 0.0,
      );

      final double precioFinal = precio - (precio * descuento / 100);
      final double totalProducto = precioFinal * cantidad;

      productos.add(
        ProductoFactura(
          nombre: descripcion,
          cantidad: cantidad,
          precio: precio,
          precioFinal: precioFinal,
          descuentoStr: descuento > 0
              ? '${descuento.toStringAsFixed(1)}%'
              : '0%',
          impuesto: 0.0, // Por ahora sin impuestos
        ),
      );

      subtotal += totalProducto;
      totalDescuento += (precio * descuento / 100) * cantidad;
    }

    final double total = subtotal;
    final String totalEnLetras = _convertirNumeroALetras(total);

    // Navegar a la pantalla de factura
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacturaTicketScreen(
          nombreCliente: facturaData['nombreCliente'] ?? 'Cliente',
          codigoCliente: facturaData['codigoCliente'] ?? '',
          direccion: null, // Por ahora sin dirección
          rtn: null, // Por ahora sin RTN
          vendedor: facturaData['vendedor'] ?? 'Vendedor',
          fechaFactura: _formatearFecha(facturaData['fechaEmision']),
          fechaEntrega: _formatearFecha(facturaData['fechaEntrega']),
          numeroFactura: facturaData['numeroFactura'] ?? 'N/A',
          productos: productos,
          subtotal: subtotal,
          totalDescuento: totalDescuento,
          total: total,
          totalEnLetras: totalEnLetras,
          empresa: [], // Por ahora sin datos de empresa
        ),
      ),
    );
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return DateTime.now().toString().split(' ')[0];
    try {
      final fecha = DateTime.parse(fechaIso);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (e) {
      return DateTime.now().toString().split(' ')[0];
    }
  }

  String _convertirNumeroALetras(double numero) {
    // Implementación básica - se puede mejorar
    final int parteEntera = numero.floor();
    final int centavos = ((numero - parteEntera) * 100).round();

    if (parteEntera == 0) {
      return 'CERO LEMPIRAS CON ${centavos.toString().padLeft(2, '0')}/100';
    }

    // Por simplicidad, retornar formato básico
    return '${parteEntera.toString().toUpperCase()} LEMPIRAS CON ${centavos.toString().padLeft(2, '0')}/100';
  }

  /// Método para sincronizar facturas offline manualmente
  Future<void> _sincronizarFacturasOffline() async {
    if (_isSyncing) return; // Evitar múltiples sincronizaciones simultáneas

    setState(() {
      _isSyncing = true;
    });

    try {
      // Mostrar mensaje de inicio de sincronización
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Iniciando sincronización de facturas offline...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Usar el servicio de sincronización de facturas
      final facturasSincronizadas = await FacturaSyncService.sincronizarFacturasPendientes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              facturasSincronizadas > 0
                  ? 'Se sincronizaron $facturasSincronizadas facturas correctamente'
                  : 'No hay facturas offline pendientes por sincronizar',
            ),
            backgroundColor: facturasSincronizadas > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la sincronización: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
