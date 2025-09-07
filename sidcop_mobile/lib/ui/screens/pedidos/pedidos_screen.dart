import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/services/PedidosService.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedido_detalle_bottom_sheet.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final PedidosService _service = PedidosService();
  final PerfilUsuarioService _perfilService = PerfilUsuarioService();

  static const Color primaryColor = Color(0xFF141A2F); // Drawer principal
  static const Color goldColor = Color(0xFFE0C7A0); // Íconos y títulos

  Future<List<PedidosViewModel>> _getPedidosDelVendedor() async {
    try {
      // Verificar conexión a internet
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult != ConnectivityResult.none;

      print('Estado de conexión: ${isOnline ? 'ONLINE' : 'OFFLINE'}');

      // Obtener datos del usuario actual para el filtrado
      final datosUsuario = await _perfilService.obtenerDatosUsuario();
      
      // Obtener el ID del vendedor para el filtrado
      int vendedorId = 0;
      if (datosUsuario != null) {
        vendedorId = datosUsuario['usua_IdPersona'] is String
            ? int.tryParse(datosUsuario['usua_IdPersona']) ?? 0
            : datosUsuario['usua_IdPersona'] ?? 0;
      }

      // Obtener pedidos según el modo (online/offline)
      List<PedidosViewModel> pedidos = [];

      if (isOnline) {
        try {
          print('Obteniendo pedidos desde el servidor...');
          pedidos = await _service.getPedidos();

          // Si obtuvimos datos del servidor, actualizar la caché local
          if (pedidos.isNotEmpty) {
            print('Actualizando caché local con ${pedidos.length} pedidos...');
            await PedidosScreenOffline.guardarPedidos(pedidos);
          }
          
          // Si no hay pedidos, intentar cargar del caché
          if (pedidos.isEmpty) {
            print('No se encontraron pedidos en línea, intentando cargar del caché...');
            pedidos = await PedidosScreenOffline.obtenerPedidos();
          }
        } catch (e) {
          print('Error obteniendo pedidos del servidor: $e');
          // Si falla la conexión al servidor, usar datos offline
          print('Fallback: usando datos offline...');
          pedidos = await PedidosScreenOffline.obtenerPedidos();
        }
      } else {
        print('Sin conexión, obteniendo pedidos offline...');
        pedidos = await PedidosScreenOffline.obtenerPedidos();
      }

      print('Total de pedidos obtenidos: ${pedidos.length}');

      // Si no hay ID de vendedor o es cero, devolver todos los pedidos
      if (vendedorId == 0) {
        print('ID de vendedor no válido, devolviendo todos los pedidos');
        return pedidos;
      }

      print('Filtrando pedidos para vendedor ID: $vendedorId');

      // Filtrar por vendedor
      final pedidosFiltrados = pedidos.where((pedido) {
        print(
          'Pedido ${pedido.pediId}: vendId=${pedido.vendId}, filtro=$vendedorId',
        );
        return pedido.vendId == vendedorId;
      }).toList();

      print(
        'Pedidos filtrados: ${pedidosFiltrados.length} de ${pedidos.length} totales',
      );
      
      return pedidosFiltrados;
    } catch (e, stackTrace) {
      print('Error crítico en _getPedidosDelVendedor: $e');
      print('Stack trace: $stackTrace');

      // En caso de error crítico, intentar obtener datos locales
      try {
        print('Último intento: obteniendo datos offline...');
        return await PedidosScreenOffline.obtenerPedidos();
      } catch (e2) {
        print('Error también en último intento: $e2');
        return [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Pedidos',
      icon: Icons.assignment,
      onRefresh: () async {
        // Forzar actualización de datos
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) {
          // Si hay conexión, intentar sincronizar pendientes
          try {
            await PedidosScreenOffline.sincronizarPedidosPendientes();
          } catch (e) {
            print('Error sincronizando pedidos pendientes: $e');
          }
        }
        setState(() {});
      },
      child: FutureBuilder<List<PedidosViewModel>>(
        future: _getPedidosDelVendedor(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final pedidos = snapshot.data ?? [];
          if (pedidos.isEmpty) {
            return const Center(child: Text('No hay pedidos.'));
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pedidos.length,
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return _buildPedidoCard(pedido);
            },
          );
        },
      ),
    );
  }

  Widget _buildPedidoCard(PedidosViewModel pedido) {
    int cantidadProductos = 0;
    if (pedido.detallesJson != null && pedido.detallesJson!.isNotEmpty) {
      try {
        final List<dynamic> detalles = List.from(
          jsonDecode(pedido.detallesJson!),
        );
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
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PedidoDetalleBottomSheet(pedido: pedido),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 4,
        color: primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: goldColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment, color: goldColor, size: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$cantidadProductos producto${cantidadProductos == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.clieNombreNegocio ?? 'Sin nombre de negocio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cliente: ${pedido.clieNombres ?? ''} ${pedido.clieApellidos ?? ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha pedido: ${_formatFecha(pedido.pediFechaPedido)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dirección: ${pedido.diClDireccionExacta ?? '-'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: goldColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
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
    return "${fecha.day} de ${meses[fecha.month]} del ${fecha.year}";
  }
}
