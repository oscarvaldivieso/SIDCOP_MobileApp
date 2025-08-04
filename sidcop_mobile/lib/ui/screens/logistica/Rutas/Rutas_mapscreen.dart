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
  DireccionCliente? _selectedDireccion;
  Cliente? _selectedCliente;
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
        final cliente = clientesFiltrados.firstWhere(
          (c) => c.clie_Id == d.clie_id,
        );
        markers.add(
          Marker(
            markerId: MarkerId(d.dicl_id.toString()),
            position: LatLng(d.dicl_latitud!, d.dicl_longitud!),
            infoWindow: InfoWindow(), // Sin contenido
            onTap: () {
              setState(() {
                _selectedDireccion = d;
                _selectedCliente = cliente;
              });
            },
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
          : Stack(
              children: [
                GoogleMap(
                  mapType: _mapType,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition!,
                    zoom: 12,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                if (_selectedDireccion != null && _selectedCliente != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 40,
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedCliente!.clie_ImagenDelNegocio !=
                                    null &&
                                _selectedCliente!
                                    .clie_ImagenDelNegocio!
                                    .isNotEmpty)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    _selectedCliente!.clie_ImagenDelNegocio!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.store, size: 80),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              (_selectedCliente!.clie_Nombres ?? '') +
                                  ' ' +
                                  (_selectedCliente!.clie_Apellidos ?? ''),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dirección: ${_selectedDireccion!.dicl_direccionexacta}',
                            ),
                            Text(
                              'Teléfono: ${_selectedCliente!.clie_Telefono ?? ""}',
                            ),
                            Text(
                              'Negocio: ${_selectedCliente!.clie_NombreNegocio ?? ""}',
                            ),
                            Text(
                              'Observaciones: ${_selectedDireccion!.dicl_observaciones}',
                            ),
                            const Divider(),
                            Text(
                              'ID Dirección: ${_selectedDireccion!.dicl_id}',
                            ),
                            Text(
                              'Latitud: ${_selectedDireccion!.dicl_latitud}',
                            ),
                            Text(
                              'Longitud: ${_selectedDireccion!.dicl_longitud}',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedDireccion = null;
                                    _selectedCliente = null;
                                  });
                                },
                                child: const Text('Cerrar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
