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
      print('Cantidad total de clientes: ${clientes.length}');
      print('Clientes recibidos:');
      for (var cliente in clientes) {
        print(cliente);
      }

      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();
      print('Cantidad total de direcciones: ${todasDirecciones.length}');
      print('Direcciones recibidas:');
      for (var direccion in todasDirecciones) {
        print(direccion);
        try {
          print(
            'Campos: latitud=${direccion.dicl_latitud}, longitud=${direccion.dicl_longitud}, id=${direccion.dicl_id}',
          );
        } catch (e) {
          print('No se pudo acceder a los campos principales: $e');
        }
      }

      final direccionesFiltradas = todasDirecciones;
      print('Direcciones filtradas: ${direccionesFiltradas.length}');

      // 5. Crear los marcadores
      final markers = direccionesFiltradas
          .map(
            (d) => Marker(
              markerId: MarkerId(d.dicl_id.toString()),
              position: LatLng(d.dicl_latitud ?? 0, d.dicl_longitud ?? 0),
              infoWindow: InfoWindow(
                title: d.dicl_direccionexacta,
                snippet: d.dicl_observaciones,
              ),
            ),
          )
          .toSet();

      setState(() {
        _markers = markers;
        _loading = false;
        if (direccionesFiltradas.isNotEmpty) {
          _initialPosition = LatLng(
            direccionesFiltradas.first.dicl_latitud ?? 0.0,
            direccionesFiltradas.first.dicl_longitud ?? 0.0,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _initialPosition == null
          ? const Center(child: Text('No hay direcciones para mostrar'))
          : GoogleMap(
              mapType: _mapType,
              initialCameraPosition: CameraPosition(
                target: _initialPosition!,
                zoom: 14,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
