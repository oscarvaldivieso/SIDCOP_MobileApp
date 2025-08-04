import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sidcop_mobile/services/global_service.dart';

class RutaMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;
  const RutaMapScreen({Key? key, required this.rutaId, this.descripcion})
    : super(key: key);

  @override
  State<RutaMapScreen> createState() => _RutaMapScreenState();
}

class _RutaMapScreenState extends State<RutaMapScreen> {
  final String _googleApiKey = mapApikey;
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  MapType _mapType = MapType.hybrid;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _loading = true;
  LatLng? _initialPosition;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  Stream<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadDirecciones();
    _getUserLocation();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _positionStream!.listen((position) {
      if (position != null) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _updateUserMarker();
          if (_polylines.isNotEmpty) {
            _updateRoutePolyline();
          }
        });
      }
    });
  }

  void _updateUserMarker() {
    _markers = _markers
        .where((m) => m.markerId.value != 'user_location')
        .toSet();
  }

  void _updateRoutePolyline() {
    if (_userLocation == null || _markers.isEmpty) return;
    final markerPoints = _markers
        .where((m) => m.markerId.value != 'user_location')
        .map((m) => m.position)
        .toList();
    if (markerPoints.isEmpty) return;

    String origin = '${_userLocation!.latitude},${_userLocation!.longitude}';
    String destination =
        '${markerPoints.last.latitude},${markerPoints.last.longitude}';
    String waypoints = markerPoints.length > 1
        ? markerPoints
              .sublist(0, markerPoints.length - 1)
              .map((p) => '${p.latitude},${p.longitude}')
              .join('|')
        : '';

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_googleApiKey';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=$waypoints';
    }

    http.get(Uri.parse(url)).then((response) {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final points = _decodePolyline(
            data['routes'][0]['overview_polyline']['points'],
          );
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.blue,
                width: 6,
                points: points,
              ),
            };
          });
        }
      }
    });
  }

  List<LatLng> _decodePolyline(String poly) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {}
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
        _polylines = {};
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
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _customInfoWindowController.googleMapController =
                        controller;
                    _mapController = controller;
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
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        backgroundColor: const Color(0xFF141A2F),
                        foregroundColor: const Color(0xFFD6B68A),
                        onPressed: _userLocation == null || _markers.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _updateRoutePolyline();
                                });
                              },
                        child: const Icon(Icons.alt_route),
                        tooltip: 'Ver rutas',
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        backgroundColor: const Color(0xFF141A2F),
                        foregroundColor: const Color(0xFFD6B68A),
                        onPressed:
                            _userLocation == null || _mapController == null
                            ? null
                            : () {
                                _mapController!.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: _userLocation!,
                                      zoom: 16,
                                    ),
                                  ),
                                );
                              },
                        child: const Icon(Icons.my_location),
                        tooltip: 'Centrar en mi ubicación',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
