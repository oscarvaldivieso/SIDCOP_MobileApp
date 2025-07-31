import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/RutasViewModel.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidcop_mobile/services/RutasService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';

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
      // Obtener todos los clientes
      final clientesService = ClientesService();
      final clientes = await clientesService.getClientes();
      //  Obtener todas las direcciones
      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();
      // omito el filtrar por ruta ya que las tablas recibiran cambios

      final markers = todasDirecciones
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
        if (todasDirecciones.isNotEmpty) {
          _initialPosition = LatLng(
            todasDirecciones.first.latitud,
            todasDirecciones.first.longitud,
          );
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      // Puedes mostrar un error aquí si lo deseas
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
              initialCameraPosition: CameraPosition(
                target: _initialPosition!,
                zoom: 15,
              ),
              mapType: _mapType,
              markers: _markers,
            ),
    );
  }
}
