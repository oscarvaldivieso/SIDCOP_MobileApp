import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/invoice_preview_screen.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';

class PedidoDetalleBottomSheet extends StatefulWidget {
  final PedidosViewModel pedido;
  final VoidCallback? onPedidoUpdated;
  
  const PedidoDetalleBottomSheet({
    super.key, 
    required this.pedido,
    this.onPedidoUpdated,
  });

  @override
  State<PedidoDetalleBottomSheet> createState() => _PedidoDetalleBottomSheetState();
}

class _PedidoDetalleBottomSheetState extends State<PedidoDetalleBottomSheet> {
  final FacturaService _facturaService = FacturaService();
  final PedidosService _pedidosService = PedidosService();
  bool _isInsertingInvoice = false;
  bool _isOffline = false;
  bool _isSyncing = false;

  Color get _primaryColor => const Color(0xFF141A2F);
  Color get _goldColor => const Color(0xFFE0C7A0);
  Color get _surfaceColor => const Color(0xFFF8FAFC);
  Color get _borderColor => const Color(0xFFE2E8F0);
  
  // Check if the current order is an offline order (has negative ID)
  bool get _isOfflineOrder => widget.pedido.pediId < 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }
  
  Future<void> _sincronizarPedido() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      // Try to sync the order
      final sincronizados = await _pedidosService.sincronizarPedidosPendientes();
      
      if (sincronizados > 0 && mounted) {
        if (widget.onPedidoUpdated != null) {
          widget.onPedidoUpdated!();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido sincronizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Close the bottom sheet if the order was synced
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar el pedido: $e'),
            backgroundColor: Colors.red,
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
              // Header with title and actions
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFFE0C7A0), size: 30),
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
                  // Show sync button for offline orders
                  if (_isOfflineOrder) ...[
                    _isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.sync, color: Colors.orange),
                            onPressed: _sincronizarPedido,
                            tooltip: 'Sincronizar Pedido',
                          ),
                    const SizedBox(width: 8),
                  ],
                  // Show invoice button only for synced orders
                  if (!_isOfflineOrder) ...[
                    _isInsertingInvoice
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.shopping_cart, color: Colors.black54),
                            onPressed: _insertarFactura,
                            tooltip: 'Ver Factura',
                          ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              // Offline indicator for offline orders
              if (_isOfflineOrder) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Este pedido está guardado localmente y se sincronizará cuando haya conexión',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 18),
              
              // Order information cards
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
              
              // Order status for offline orders
              if (_isOfflineOrder) ...[
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.info_outline,
                  title: 'Estado',
                  value: 'Pendiente de sincronización',
                  color: Colors.orange,
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Products list header
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Productos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _primaryColor,
                  ),
                ),
              ),
              
              // Products list or empty state
              if (detalles.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, 
                            size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos en este pedido',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
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
              
              // Bottom padding
              const SizedBox(height: 10),
              
              // Sync button for offline orders
              if (_isOfflineOrder && !_isSyncing && !_isOffline) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sincronizarPedido,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sync, size: 20),
                    label: const Text(
                      'SINCRONIZAR AHORA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String value, required Color color}) {
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
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
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
    if (detallesJson == null || detallesJson.isEmpty) return [];
    try {
      return jsonDecode(detallesJson) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Widget _buildDetalleItem(dynamic item) {
    final String descripcion = item['descripcion']?.toString() ?? 'Producto sin nombre';
    final String imagen = item['imagen']?.toString() ?? '';
    final int cantidad = item['cantidad'] is int
        ? item['cantidad']
        : int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
    final double precio = item['precio'] is double
        ? item['precio']
        : double.tryParse(item['precio']?.toString() ?? '') ?? 0.0;
    final double total = cantidad * precio;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
            color: Colors.grey.shade100,
            child: imagen.isNotEmpty
                ? Image.network(
                    imagen, 
                    width: 60, 
                    height: 60, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.inventory_2_outlined, 
                      size: 32, 
                      color: Colors.grey
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined, 
                    size: 32, 
                    color: Colors.grey
                  ),
          ),
        ),
        
        const SizedBox(width: 14),
        
        // Product details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product name
              Text(
                descripcion,
                style: const TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: 15,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 6),
              
              // Quantity and price
              Row(
                children: [
                  // Quantity
                  _buildDetailChip(
                    '${cantidad}x',
                    icon: Icons.format_list_numbered_outlined,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Unit price
                  _buildDetailChip(
                    'L. ${precio.toStringAsFixed(2)}',
                    icon: Icons.attach_money_outlined,
                  ),
                  
                  const Spacer(),
                  
                  // Total
                  Text(
                    'L. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF141A2F),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailChip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    
    return '${f.day} ${meses[f.month]}, ${f.year}';
  }

  Future<void> _insertarFactura() async {
    if (_isInsertingInvoice || _isOfflineOrder) return;

    setState(() {
      _isInsertingInvoice = true;
    });

    try {
      // Check connectivity before proceeding
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay conexión a Internet. No se puede generar la factura.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Obtener la ubicación actual (si no está disponible, usar valores predeterminados)
      final double latitud = 0.0; // Idealmente obtener la ubicación actual
      final double longitud = 0.0; // Idealmente obtener la ubicación actual

      // Parsear los detalles del pedido para obtener los productos
      final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);
      
      // Log para ver el contenido de detallesJson
      print('DETALLES JSON: ${widget.pedido.detallesJson}');
      print('DETALLES PARSEADOS: $detalles');
      
      // Crear la lista de detallesFacturaInput
      final List<Map<String, dynamic>> detallesFactura = [];
      
      // Recorrer los productos y añadirlos al formato requerido
      for (var item in detalles) {
        // Log para ver cada item
        print('ITEM: $item');
        print('KEYS EN ITEM: ${item.keys.toList()}');
        
        // Extraer el ID del producto y la cantidad
        final int prodId = item['id'] is int
            ? item['id']
            : int.tryParse(item['id']?.toString() ?? '') ?? 0;
            
        final int cantidad = item['cantidad'] is int
            ? item['cantidad']
            : int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
        
        print('PROD_ID: $prodId, CANTIDAD: $cantidad');
        
        // Solo añadir productos con ID y cantidad válidos
        if (prodId > 0 && cantidad > 0) {
          detallesFactura.add({
            'prod_Id': prodId,
            'faDe_Cantidad': cantidad
          });
        }
      }
      
      print('DETALLES FACTURA FINAL: $detallesFactura');

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
        'usua_Creacion': widget.pedido.usuaCreacion,
        'fact_EsPedido': true, // Marcar como pedido
        'pedi_Id': widget.pedido.pediId, // ID del pedido actual
        'detallesFacturaInput': detallesFactura, // Añadir los productos
      };

      // Log para mostrar el objeto completo que se envía a la API
      print('OBJETO COMPLETO A ENVIAR: ${jsonEncode(facturaData)}');
      
      // Llamar al servicio para insertar la factura
      await _facturaService.insertarFactura(facturaData);
      
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
    } catch (e) {
      if (mounted) {
        // Verificar si es un error de inventario insuficiente
        if (e is InventarioInsuficienteException) {
          // Mostrar un diálogo con el mensaje de error de inventario insuficiente
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Inventario Insuficiente', 
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
      if (mounted) {
        setState(() {
          _isInsertingInvoice = false;
        });
      }
    }
  }
}
