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
    print('initState llamado, rutaId: [32m${widget.rutaId}[0m');
    _loadDirecciones();
  }

  Future<void> _loadDirecciones() async {
    print('Entrando a _loadDirecciones');
    try {
      print('Dentro del try de _loadDirecciones');
      // 1. Obtener todos los clientes
      final clientesService = ClientesService();
      final clientesJson = await clientesService.getClientes();
      print('clientesJson obtenido: ${clientesJson.length}');
      final clientes = clientesJson
          .map<Cliente>((json) => Cliente.fromJson(json))
          .toList();
      print('Cantidad total de clientes: ${clientes.length}');
      print('Clientes recibidos:');

      // Filtrar clientes por ruta_Id
      final clientesFiltrados = clientes
          .where((c) => c.ruta_Id == widget.rutaId)
          .toList();
      print(
        'Clientes filtrados por ruta_Id (${widget.rutaId}): ${clientesFiltrados.length}',
      );
      for (var cliente in clientesFiltrados) {
        print(
          'Cliente filtrado => ruta_Id: ${cliente.ruta_Id}, clie_Id: ${cliente.clie_Id}, Nombre: ${cliente.clie_Nombres}',
        );
      }

      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();
      print('Cantidad total de direcciones: ${todasDirecciones.length}');
      print('Direcciones recibidas:');

      // Filtrar direcciones por los clientes filtrados (por clie_id)
      final clienteIds = clientesFiltrados.map((c) => c.clie_Id).toSet();
      final direccionesFiltradas = todasDirecciones
          .where((d) => clienteIds.contains(d.clie_id))
          .toList();
      print(
        'Direcciones filtradas por cliente: ${direccionesFiltradas.length}',
      );
      // Mostrar solo las direcciones filtradas en el mapa
      print('Direcciones mostradas: ${direccionesFiltradas.length}');
      final Set<Marker> markers = {};
      for (var d in direccionesFiltradas) {
        // Buscar el cliente correspondiente para obtener el nombre completo
        final cliente = clientesFiltrados.firstWhere(
          (c) => c.clie_Id == d.clie_id,
        );
        final nombreCompleto =
            (cliente.clie_Nombres ?? '') + ' ' + (cliente.clie_Apellidos ?? '');
        markers.add(
          Marker(
            markerId: MarkerId(d.dicl_id.toString()),
            position: LatLng(d.dicl_latitud!, d.dicl_longitud!),
            infoWindow: InfoWindow(
              title: nombreCompleto,
              snippet:
                  '${d.dicl_direccionexacta}\nTel: ${cliente.clie_Telefono ?? ""}\nNegocio: ${cliente.clie_NombreNegocio ?? ""}\n---\nPrueba 1\nPrueba 2\nPrueba 3',
            ),
          ),
        );
      }

      setState(() {
        _markers = markers;
        _loading = false;
        if (markers.isNotEmpty) {
          final firstMarker = markers.first;
          _initialPosition = firstMarker.position;
        }
      });
      setState(() {
        _loading = false;
      });
    } catch (e) {
      print('Error en _loadDirecciones: $e');
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _initialPosition == null
          ? const Center(child: Text('No hay direcciones para mostrar'))
          : GoogleMap(
              mapType: _mapType,
              initialCameraPosition: CameraPosition(
                target: _initialPosition!,
                zoom: 12,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
