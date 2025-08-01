import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'dart:developer' as developer;

class RutaMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;
  const RutaMapScreen({super.key, required this.rutaId, this.descripcion});

  @override
  State<RutaMapScreen> createState() => _RutaMapScreenState();
}

class _RutaMapScreenState extends State<RutaMapScreen> {
  MapType _mapType = MapType.hybrid;
  Set<Marker> _markers = {};
  bool _loading = true;
  LatLng? _initialPosition;

  @override
  void initState() {
    super.initState();
    _loadDirecciones();
  }

  Future<void> _loadDirecciones() async {
    try {
      // 1. Obtener todos los clientes
      final clientesService = ClientesService();
      final clientes = await clientesService.getClientes();
      // 2. Filtrar clientes por rutaId
      print(' cantidad clientes: ${clientes.length} ');

      final clientesFiltrados = clientes
          .where((c) => c.ruta_Id == widget.rutaId)
          .toList();
      print(
        'Clientes filtrados para ruta ${widget.rutaId}: ${clientesFiltrados.length}',
      );
      for (var cliente in clientesFiltrados) {
        print(
          'Cliente: ${cliente.clie_Id}, Nombre: ${cliente.clie_Nombres}, Ruta: ${cliente.ruta_Id}',
        );
      }

      // Obtener todas las direcciones
      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();

      // Filtrar direcciones por los clientes de la ruta
      final clienteIds = clientesFiltrados.map((c) => c.clie_Id).toSet();
      final direccionesFiltradas = todasDirecciones
          .where((d) => clienteIds.contains(d.clieId))
          .toList();

      // 5. Crear los marcadores
      final markers = direccionesFiltradas
          .map(
            (d) => Marker(
              markerId: MarkerId(d.diClId?.toString() ?? d.direccionExacta),
              position: LatLng(d.latitud, d.longitud),
              infoWindow: InfoWindow(
                title: d.direccionExacta,
                snippet: d.observaciones ?? '',
              ),
            ),
          )
          .toSet();

      setState(() {
        _markers = markers;
        _loading = false;
        if (direccionesFiltradas.isNotEmpty) {
          _initialPosition = LatLng(
            direccionesFiltradas.first.latitud,
            direccionesFiltradas.first.longitud,
          );
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.descripcion ?? 'Ubicación Ruta'),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.map),
            onSelected: (type) {
              setState(() {
                _mapType = type;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: MapType.normal, child: const Text('Normal')),
              PopupMenuItem(
                value: MapType.hybrid,
                child: const Text('Satelital'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
