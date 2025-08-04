import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';

class RutaMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;
  const RutaMapScreen({Key? key, required this.rutaId, this.descripcion})
    : super(key: key);

  @override
  State<RutaMapScreen> createState() => _RutaMapScreenState();
}

class _RutaMapScreenState extends State<RutaMapScreen> {
  MapType _mapType = MapType.hybrid;
  Set<Marker> _markers = {};
  bool _loading = true;
  LatLng? _initialPosition;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  @override
  void initState() {
    super.initState();
    _loadDirecciones();
  }

  Future<void> _loadDirecciones() async {
    try {
      final clientesService = ClientesService();
      final clientesJson = await clientesService.getClientes();
      final clientes = clientesJson
          .map<Cliente>((json) => Cliente.fromJson(json))
          .toList();
      final clientesFiltrados = clientes
          .where((c) => c.ruta_Id == widget.rutaId)
          .toList();
      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();
      final clienteIds = clientesFiltrados.map((c) => c.clie_Id).toSet();
      final direccionesFiltradas = todasDirecciones
          .where((d) => clienteIds.contains(d.clie_id))
          .toList();
      final Set<Marker> markers = {};
      for (var d in direccionesFiltradas) {
        final cliente = clientesFiltrados.firstWhere(
          (c) => c.clie_Id == d.clie_id,
        );
        markers.add(
          Marker(
            markerId: MarkerId(d.dicl_id.toString()),
            position: LatLng(d.dicl_latitud!, d.dicl_longitud!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            onTap: () {
              _customInfoWindowController.addInfoWindow!(
                Container(
                  constraints: BoxConstraints(
                    minWidth: 180,
                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child:
                                (cliente.clie_ImagenDelNegocio != null &&
                                    cliente.clie_ImagenDelNegocio!.isNotEmpty)
                                ? Image.network(
                                    cliente.clie_ImagenDelNegocio!,
                                    width: 220,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.store,
                                          size: 60,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.store, size: 60),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cliente.clie_NombreNegocio ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (cliente.clie_Nombres ?? '') +
                              ' ' +
                              (cliente.clie_Apellidos ?? ''),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                LatLng(d.dicl_latitud!, d.dicl_longitud!),
              );
            },
          ),
        );
      }
      setState(() {
        _markers = markers;
        if (direccionesFiltradas.isNotEmpty) {
          _initialPosition = LatLng(
            direccionesFiltradas.first.dicl_latitud!,
            direccionesFiltradas.first.dicl_longitud!,
          );
        }
        _loading = false;
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
                  onMapCreated: (GoogleMapController controller) {
                    _customInfoWindowController.googleMapController =
                        controller;
                  },
                  onCameraMove: (position) {
                    _customInfoWindowController.onCameraMove!();
                  },
                  onTap: (position) {
                    _customInfoWindowController.hideInfoWindow!();
                  },
                ),
                CustomInfoWindow(
                  controller: _customInfoWindowController,
                  height: 220,
                  width: MediaQuery.of(context).size.width * 0.6,
                  offset: 40,
                ),
              ],
            ),
    );
  }
}
