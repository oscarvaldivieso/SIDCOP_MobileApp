import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedido_detalle_bottom_sheet.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final PedidosService _service = PedidosService();
  final PerfilUsuarioService _perfilService = PerfilUsuarioService();
  bool _isLoading = false;
  bool _isOffline = false;
  String _errorMessage = '';
  bool _isSyncing = false;

  static const Color primaryColor = Color(0xFF141A2F); // Drawer principal
  static const Color goldColor = Color(0xFFE0C7A0); // Íconos y títulos

  @override
  void initState() {
    super.initState();
    // Check connectivity when the screen loads
    _checkConnectivity();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) async {
      final isOnline = result != ConnectivityResult.none;
      setState(() {
        _isOffline = !isOnline;
      });
      
      // If we just came back online, try to sync pending orders
      if (isOnline && !_isSyncing) {
        await _sincronizarPedidosPendientes();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
  }

  Future<void> _sincronizarPedidosPendientes() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      _errorMessage = '';
    });

    try {
      final sincronizados = await _service.sincronizarPedidosPendientes();
      
      if (sincronizados > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sincronizados pedido(s) sincronizado(s) con éxito'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh the list
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al sincronizar pedidos: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<List<PedidosViewModel>> _getPedidosDelVendedor() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get all orders (service will handle online/offline logic)
      final todosPedidos = await _service.getPedidos();
      
      // Get current user data
      final datosUsuario = await _perfilService.obtenerDatosUsuario();
      if (datosUsuario == null) {
        print('No se encontraron datos del usuario');
        return todosPedidos; // If we can't get the vendor, show all
      }

      // Get vendor ID (usuaIdPersona)
      final int vendedorId = datosUsuario['usua_IdPersona'] is String 
          ? int.tryParse(datosUsuario['usua_IdPersona']) ?? 0
          : datosUsuario['usua_IdPersona'] ?? 0;

      if (vendedorId == 0) {
        print('ID de vendedor no válido: $vendedorId');
        return todosPedidos; // If we can't get the vendor, show all
      }

      print('Filtrando pedidos para vendedor ID: $vendedorId');
      // Filter orders that belong to the current vendor
      final pedidosFiltrados = todosPedidos.where((pedido) => pedido.vendId == vendedorId).toList();
      
      // Sort by date (newest first)
      pedidosFiltrados.sort((a, b) => b.pediFechaPedido.compareTo(a.pediFechaPedido));
      
      print('Pedidos encontrados para el vendedor: ${pedidosFiltrados.length} de ${todosPedidos.length} totales');
      
      return pedidosFiltrados;
    } catch (e) {
      print('Error obteniendo pedidos del vendedor: $e');
      setState(() {
        _errorMessage = 'Error al cargar los pedidos: $e';
      });
      return [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarDetallePedido(PedidosViewModel pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PedidoDetalleBottomSheet(
        pedido: pedido,
        onPedidoUpdated: () async {
          setState(() {});
          await _getPedidosDelVendedor();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Pedidos',
      icon: Icons.assignment,
      onRefresh: () async {
        setState(() {});
      },
      child: Column(
        children: [
          // Offline/Sync status bar
          if (_isOffline)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange[800],
              child: Row(
                children: [
                  const Icon(Icons.signal_wifi_off, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Modo sin conexión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isSyncing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _sincronizarPedidosPendientes,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'REINTENTAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Error message
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.red[800],
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: FutureBuilder<List<PedidosViewModel>>(
              future: _getPedidosDelVendedor(),
              builder: (context, snapshot) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error al cargar los pedidos: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                
                final pedidos = snapshot.data ?? [];
                
                if (pedidos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay pedidos registrados',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Los pedidos se sincronizarán cuando haya conexión',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = pedidos[index];
                      final esOffline = pedido.pediId < 0; // Check if it's an offline order
                      
                      int cantidadProductos = 0;
                      if (pedido.detallesJson != null && pedido.detallesJson!.isNotEmpty) {
                        try {
                          final List<dynamic> detalles = List.from(jsonDecode(pedido.detallesJson!));
                          for (final item in detalles) {
                            if (item is Map && item.containsKey('cantidad')) {
                              final cant = item['cantidad'];
                              if (cant is int) {
                                cantidadProductos += cant;
                              } else if (cant is String) {
                                cantidadProductos += int.tryParse(cant) ?? 0;
                              }
                            }
                          }
                        } catch (_) {
                          cantidadProductos = 0;
                        }
                      }
                      
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: esOffline 
                              ? BorderSide(color: Colors.orange, width: 1.5)
                              : BorderSide.none,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        color: primaryColor,
                        child: InkWell(
                          onTap: () => _mostrarDetallePedido(pedido),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left side - Icon and product count
                                Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: esOffline 
                                            ? Colors.orange.withOpacity(0.2)
                                            : goldColor.withOpacity(0.13),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        esOffline ? Icons.cloud_off : Icons.assignment,
                                        color: esOffline ? Colors.orange : goldColor,
                                        size: 32,
                                      ),
                                    ),
                                    if (esOffline)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.sync_disabled,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Middle - Order details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // First row - Order number and status
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Pedido #${pedido.pediCodigo ?? 'N/A'}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'Satoshi',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: esOffline 
                                                  ? Colors.orange.withOpacity(0.2)
                                                  : Colors.green.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              esOffline ? 'Pendiente' : 'Sincronizado',
                                              style: TextStyle(
                                                color: esOffline ? Colors.orange : Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Second row - Client name
                                      Text(
                                        pedido.clieNombreNegocio ?? 'Sin nombre de negocio',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Third row - Client contact
                                      Text(
                                        '${pedido.clieNombres ?? ''} ${pedido.clieApellidos ?? ''}'.trim(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Fourth row - Date and product count
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatFecha(pedido.pediFechaPedido),
                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.shopping_cart, size: 14, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$cantidadProductos producto${cantidadProductos != 1 ? 's' : ''}',
                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      
                                      // Fifth row - Address
                                      if (pedido.diClDireccionExacta?.isNotEmpty == true) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on, size: 14, color: Colors.white54),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                pedido.diClDireccionExacta!,
                                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                
                                // Right side - Arrow icon
                                const Icon(Icons.chevron_right, color: Color(0xFFE0C7A0), size: 24),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final meses = [
      '',
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${fecha.day} ${meses[fecha.month]}, ${fecha.year}';
  }
}
