import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';
import 'package:sidcop_mobile/services/ClientesService.Dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/utils/numero_en_letras.dart';

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
  
  void _actualizarCantidad(int index, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarProducto(index);
      return;
    }
    
    setState(() {
      _productosEditables[index] = ProductoConfirmacion(
        prodId: _productosEditables[index].prodId,
        nombre: _productosEditables[index].nombre,
        cantidad: nuevaCantidad,
        precioBase: _productosEditables[index].precioBase,
        precioFinal: _productosEditables[index].precioFinal,
        imagen: _productosEditables[index].imagen,
      );
    });
  }
  
  void _eliminarProducto(int index) {
    setState(() {
      _productosEditables.removeAt(index);
    });
  }
  
  int get _cantidadTotal => _productosEditables.fold<int>(0, (sum, p) => sum + p.cantidad);
  num get _subtotal => _productosEditables.fold<num>(0, (sum, p) => sum + (p.precioBase * p.cantidad));
  num get _total => _productosEditables.fold<num>(0, (sum, p) => sum + (p.precioFinal * p.cantidad));

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Confirmar Pedido',
      icon: Icons.check_circle_outline,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Productos seleccionados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ..._productosEditables.asMap().entries.map((entry) {
              final index = entry.key;
              final p = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Dismissible(
                  key: Key('producto_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Eliminar producto'),
                          content: Text('¿Estás seguro de que quieres eliminar "${p.nombre}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    _eliminarProducto(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${p.nombre}" eliminado')),
                    );
                  },
                  child: ListTile(
                    leading: p.imagen != null && p.imagen!.isNotEmpty
                        ? Image.network(p.imagen!, width: 48, height: 48, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 40),
                    title: Text(p.nombre),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Precio unitario: L. ${p.precioFinal.toStringAsFixed(2)}'),
                        Text('Total: L. ${(p.precioFinal * p.cantidad).toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: Container(
                      width: 120,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => _actualizarCantidad(index, p.cantidad - 1),
                          ),
                          Container(
                            width: 30,
                            child: Text(
                              '${p.cantidad}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => _actualizarCantidad(index, p.cantidad + 1),
                          ),
                        ],
                      ),
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
                    const Text('Información de entrega:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Fecha: ${widget.fechaEntrega.day.toString().padLeft(2, '0')}/${widget.fechaEntrega.month.toString().padLeft(2, '0')}/${widget.fechaEntrega.year}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
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
                  Text('Cantidad total de productos: $_cantidadTotal', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('Subtotal: L. ${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text('Total (con descuento): L. ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Validar productos y clienteId (ya están en la pantalla)
                        if (_productosEditables.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay productos seleccionados.')));
                          return;
                        }
                        if (widget.clienteId == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se seleccionó cliente.')));
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
                          print('Datos completos del usuario: $datosUsuario');
                          print('Claves disponibles: ${datosUsuario.keys.toList()}');
                          
                          final int usuaId = datosUsuario['usua_Id'] is String 
                              ? int.tryParse(datosUsuario['usua_Id']) ?? 0
                              : datosUsuario['usua_Id'] ?? 0;
                          
                          // Usar usuaIdPersona como vendId (común en sistemas donde el vendedor es una persona)
                          final int vendId = datosUsuario['usua_IdPersona'] is String 
                              ? int.tryParse(datosUsuario['usua_IdPersona']) ?? 0
                              : datosUsuario['usua_IdPersona'] ?? 0;
                          
                          print('usuaId obtenido: $usuaId');
                          print('vendId (usuaIdPersona) obtenido: $vendId');
                          print('usuaEsVendedor: ${datosUsuario['usua_EsVendedor']}');
                              
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
                              "peDe_ProdPrecioFinal": p.precioFinal,
                            };
                          }).toList();

                          // Obtener DiCl_Id de la dirección seleccionada
                          print('Dirección seleccionada completa: ${widget.direccionSeleccionada}');
                          print('Claves disponibles en dirección: ${widget.direccionSeleccionada.keys.toList()}');
                          
                          final int diClId = widget.direccionSeleccionada['diCl_Id'] ?? 
                                           widget.direccionSeleccionada['DiCl_Id'] ?? 
                                           widget.direccionSeleccionada['dicl_Id'] ?? 
                                           widget.direccionSeleccionada['Id'] ?? 
                                           widget.direccionSeleccionada['id'] ?? 
                                           widget.direccionSeleccionada['ID'] ?? 0;
                          
                          print('DiCl_Id obtenido: $diClId');
                          
                          if (diClId == 0) {
                            throw Exception('ID de dirección no válido. Dirección: ${widget.direccionSeleccionada}');
                          }

                          // Llamar a la API para insertar el pedido
                          final pedidosService = PedidosService();
                          final resultado = await pedidosService.insertarPedido(
                            diClId: diClId,
                            vendId: vendId,
                            fechaPedido: DateTime.now(),
                            fechaEntrega: widget.fechaEntrega,
                            usuaCreacion: usuaId,
                            clieId: widget.clienteId,
                            detalles: detallesApi,
                          );

                          if (!resultado['success']) {
                            throw Exception(resultado['message'] ?? 'Error al crear el pedido');
                          }

                          // Obtener número de pedido real de la respuesta de la API
                          final pedidoData = resultado['data'];
                          final numeroPedidoReal = pedidoData != null && pedidoData['pedi_Id'] != null 
                              ? 'PED-${pedidoData['pedi_Id']}'
                              : 'PED-${DateTime.now().millisecondsSinceEpoch}';

                          // Si el pedido se creó exitosamente, obtener datos para la factura
                          final clienteService = ClientesService();
                          final cliente = await clienteService.getClienteById(widget.clienteId);
                          final nombreCliente = ((cliente['clie_Nombres'] ?? '') + ' ' + (cliente['clie_Apellidos'] ?? '')).trim();
                          final codigoCliente = cliente['clie_Codigo'] ?? '';
                          
                          // Usar la dirección seleccionada
                          final direccion = widget.direccionSeleccionada['DiCl_DescripcionExacta'] ?? 
                                           widget.direccionSeleccionada['descripcion'] ?? 
                                           'Dirección no especificada';
                          final rtn = cliente['clie_RTN'] ?? '';

                          // Obtener datos reales del usuario (vendedor) - reutilizar variables existentes
                          String vendedor = 'Vendedor no especificado';
                          if (datosUsuario != null && datosUsuario['usua_Id'] != null) {
                            final usuario = await perfilService.obtenerDatosCompletoUsuario(datosUsuario['usua_Id']);
                            if (usuario != null) {
                              if (usuario['nombreCompleto'] != null && usuario['nombreCompleto'].toString().isNotEmpty) {
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
                            return ProductoFactura(
                              nombre: p.nombre,
                              cantidad: p.cantidad,
                              precio: p.precioBase,
                              precioFinal: p.precioFinal,
                              descuentoStr: descuentoStr,
                              impuesto: 0, // Agregar cálculo de impuesto si es necesario
                            );
                          }).toList();
                          
                          final totalDescuento = productosFactura.fold<num>(0, (s, p) => s + ((p.precio - p.precioFinal) * p.cantidad));
                          final totalEnLetras = NumeroEnLetras.convertir(_total.truncate());
                          
                          // Cerrar loading
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          
                          // Mostrar mensaje de éxito
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('¡Pedido creado exitosamente! Número: $numeroPedidoReal'),
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
                                  nombreCliente: nombreCliente,
                                  codigoCliente: codigoCliente,
                                  direccion: direccion,
                                  rtn: rtn,
                                  vendedor: vendedor,
                                  fechaFactura: '${fechaFactura.day.toString().padLeft(2, '0')}/${fechaFactura.month.toString().padLeft(2, '0')}/${fechaFactura.year}',
                                  fechaEntrega: '${widget.fechaEntrega.day.toString().padLeft(2, '0')}/${widget.fechaEntrega.month.toString().padLeft(2, '0')}/${widget.fechaEntrega.year}',
                                  numeroFactura: numeroPedidoReal,
                                  productos: productosFactura,
                                  subtotal: _subtotal,
                                  totalDescuento: totalDescuento,
                                  total: _total,
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
                          print('Error completo al crear pedido: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0C7A0),
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductoConfirmacion {
  final int? prodId; // ID del producto para la API
  final String nombre;
  final int cantidad;
  final num precioFinal;
  final num precioBase;
  final String? imagen;

  ProductoConfirmacion({
    this.prodId,
    required this.nombre,
    required this.cantidad,
    required this.precioFinal,
    required this.precioBase,
    this.imagen,
  });
}
