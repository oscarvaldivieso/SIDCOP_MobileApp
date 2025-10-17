import 'dart:async';
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
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Cargar los pedidos al iniciar la pantalla
    _cargarPedidos();

    // Escuchar cambios en la conectividad
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      _handleConnectivityChange(result);
      // Recargar los pedidos cuando cambia la conectividad
      _cargarPedidos();
    });
  }

  // Lista para almacenar los pedidos
  List<PedidosViewModel> _pedidos = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Método para cargar los pedidos
  Future<void> _cargarPedidos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Obtener los pedidos del vendedor
      final pedidos = await _getPedidosDelVendedor();

      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar pedidos: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los pedidos';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Manejar cambios en la conectividad
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (result != ConnectivityResult.none) {
      print('Conectividad restaurada, actualizando caché y sincronizando...');
      
      // Primero actualizar el caché con los pedidos más recientes del servidor
      try {
        final pedidosServidor = await _service.getPedidos();
        
        if (pedidosServidor.isNotEmpty) {
          await PedidosScreenOffline.guardarPedidos(pedidosServidor);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pedidos Actualizados'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
      }
      
      // Luego sincronizar pedidos pendientes
      try {
        final pedidosPendientes =
            await PedidosScreenOffline.obtenerPedidosPendientes();
        if (pedidosPendientes.isNotEmpty) {
          

          int sincronizados = 0;
          for (final pedido in pedidosPendientes) {
            try {
              // Intentar enviar el pedido al servidor
              final response = await _service.insertarPedido(
                diClId: pedido.diClId,
                vendId: pedido.vendId,
                pediCodigo:
                    pedido.pedi_Codigo ??
                    'PED-${DateTime.now().millisecondsSinceEpoch}',
                fechaPedido: pedido.pediFechaPedido,
                fechaEntrega:
                    pedido.pediFechaEntrega ??
                    DateTime.now().add(const Duration(days: 1)),
                usuaCreacion: pedido.usuaCreacion,
                clieId: pedido.clieId ?? 0,
                detalles:
                    (pedido.detalles
                        ?.map<Map<String, dynamic>>((d) => d.toMap())
                        .toList() ??
                    <Map<String, dynamic>>[]),
              );

              if (response['success'] == true) {
                // Eliminar el pedido de la lista de pendientes
                await PedidosScreenOffline.eliminarPedidoPendiente(
                  pedido.pediId,
                );
                sincronizados++;
              }
            } catch (e) {
              print('Error al sincronizar pedido ${pedido.pediId}: $e');
            }
          }

          // Actualizar la lista de pedidos después de la sincronización
          if (mounted) {
            setState(() {});
            if (sincronizados > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$sincronizados pedidos sincronizados correctamente',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } catch (e) {
        print('Error en la sincronización de pedidos: $e');
      }
    }
  }

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

          // SIEMPRE actualizar la caché local cuando estamos online
          print('Actualizando caché local con ${pedidos.length} pedidos...');
          await PedidosScreenOffline.guardarPedidos(pedidos);
          
          // Mostrar notificación de actualización de caché
          if (mounted && pedidos.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pedidos sincronizados'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Si no hay pedidos del servidor, intentar cargar del caché como fallback
          if (pedidos.isEmpty) {
            print(
              'No se encontraron pedidos en línea, intentando cargar del caché...',
            );
            pedidos = await PedidosScreenOffline.obtenerPedidos();
          }
        } catch (e) {
          print('Error obteniendo pedidos del servidor: $e');
          // Si falla la conexión al servidor, usar datos offline
          print('Fallback: usando datos offline...');
          pedidos = await PedidosScreenOffline.obtenerPedidos();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error de conexión, usando datos offline'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        print('Sin conexión, obteniendo pedidos offline...');
        pedidos = await PedidosScreenOffline.obtenerPedidos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modo offline - usando datos en caché'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
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
      onRefresh: _cargarPedidos,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar los pedidos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarPedidos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : _pedidos.isEmpty
          ? const Center(child: Text('No hay pedidos disponibles'))
          : RefreshIndicator(
              onRefresh: _cargarPedidos,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _pedidos.length,
                itemBuilder: (context, index) {
                  final pedido = _pedidos[index];
                  return _buildPedidoCard(pedido);
                },
              ),
            ),
    );
  }

  // Definir colores
  // Using static colors defined at the class level
  // primaryColor and goldColor are already defined as static constants

  Widget _buildPedidoCard(PedidosViewModel pedido) {
    // Calcular la cantidad total de productos
    final int cantidadProductos = _calcularCantidadProductos(pedido);

    return GestureDetector(
      onTap: () => _mostrarDetallePedido(pedido),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 4,
        color: const Color(0xFF141A2F),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono de pedido
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0C7A0).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  color: Color(0xFFE0C7A0),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Información del pedido
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
                      'Cliente: ${pedido.clieNombres ?? ''} ${pedido.clieApellidos ?? ''}'
                          .trim(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${_formatFecha(pedido.pediFechaPedido)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Productos: $cantidadProductos',
                      style: const TextStyle(
                        color: Color(0xFFE0C7A0),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Flecha de navegación
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFE0C7A0),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calcularCantidadProductos(PedidosViewModel pedido) {
    int cantidad = 0;

    try {
      // Primero intentar con detallesJson si está disponible
      if (pedido.detallesJson != null && pedido.detallesJson!.isNotEmpty) {
        try {
          final detalles = jsonDecode(pedido.detallesJson!) as List;
          for (final item in detalles) {
            if (item is Map) {
              final cant = item['peDe_Cantidad'] ?? item['cantidad'];
              if (cant != null) {
                cantidad += (cant is int)
                    ? cant
                    : int.tryParse(cant.toString()) ?? 0;
              }
            }
          }
          return cantidad;
        } catch (e) {
          debugPrint('Error al parsear detallesJson: $e');
        }
      }

      // Si no hay detallesJson o falló el parseo, intentar con la lista de detalles
      if (pedido.detalles.isNotEmpty) {
        for (final item in pedido.detalles) {
          if (item is Map) {
            // Intentar con diferentes formatos de clave
            final cant =
                item['peDe_Cantidad'] ??
                item['cantidad'] ??
                item['peDeCantidad'];
            if (cant != null) {
              cantidad += (cant is int)
                  ? cant
                  : int.tryParse(cant.toString()) ?? 0;
            }
          }
        }
      }

      // Si aún no hay cantidad, usar el valor directo si está disponible
      if (cantidad == 0 && pedido.peDeCantidad != null) {
        cantidad = pedido.peDeCantidad!;
      }
    } catch (e) {
      debugPrint('Error al calcular cantidad de productos: $e');
    }

    return cantidad;
  }

  void _mostrarDetallePedido(PedidosViewModel pedido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PedidoDetalleBottomSheet(pedido: pedido),
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
