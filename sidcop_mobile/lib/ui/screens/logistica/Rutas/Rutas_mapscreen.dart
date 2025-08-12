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

import 'package:sidcop_mobile/services/GlobalService.Dart';

List<Map<String, dynamic>> _ordenParadas = [];
List<DireccionCliente> _direccionesFiltradas = [];
List<Cliente> _clientesFiltrados = [];
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class RutaMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;
  const RutaMapScreen({Key? key, required this.rutaId, this.descripcion})
    : super(key: key);

  @override
  State<RutaMapScreen> createState() => _RutaMapScreenState();
}

class _RutaMapScreenState extends State<RutaMapScreen> {
  // scando dsitancia por metros y no solo coordenadas
  Future<DireccionCliente?> _getClienteMasCercanoPorRuta() async {
    if (_userLocation == null || _direccionesFiltradas.isEmpty) return null;
    double minDist = double.infinity;
    DireccionCliente? closest;
    for (var d in _direccionesFiltradas) {
      String origin = '${_userLocation!.latitude},${_userLocation!.longitude}';
      String destination = '${d.dicl_latitud},${d.dicl_longitud}';
      String url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'];
          if (legs != null && legs.isNotEmpty) {
            final distance = legs[0]['distance']['value']; // metros
            if (distance < minDist) {
              minDist = distance.toDouble();
              closest = d;
            }
          }
        }
      }
    }
    return closest;
  }

  //  individual a un cliente
  void _mostrarRutaACliente(DireccionCliente destino) async {
    if (_userLocation == null) return;
    String origin = '${_userLocation!.latitude},${_userLocation!.longitude}';
    String destination = '${destino.dicl_latitud},${destino.dicl_longitud}';
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_googleApiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final points = _decodePolyline(
          data['routes'][0]['overview_polyline']['points'],
        );
        setState(() {
          _polylines = {};
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route_cliente'),
              color: Colors.blue,
              width: 4,
              patterns: [],
              endCap: Cap.roundCap,
              startCap: Cap.roundCap,
              jointType: JointType.round,
              points: points,
            ),
          };
        });
      }
    }
  }

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
    _getUserLocation();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _positionStream!.listen((position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _updateUserMarker();
        // Ya no se actualiza la ruta general
      });
      // Cuando la ubicación cambia, recalcula el orden de visitas
      _loadDirecciones();
    });
  }

  void _updateUserMarker() {
    _markers = _markers
        .where((m) => m.markerId.value != 'user_location')
        .toSet();
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
      // Una vez obtenida la ubicación, carga las direcciones y calcula el orden
      await _loadDirecciones();
    } catch (e) {}
  }

  Future<void> _loadDirecciones() async {
    try {

      final clientesService = ClientesService();
      final clientesJson = await clientesService.getClientes();
      final clientes = clientesJson
          .map<Cliente>((json) => Cliente.fromJson(json))
          .toList();
      _clientesFiltrados = clientes
          .where((c) => c.ruta_Id == widget.rutaId)
          .toList();
      final direccionesService = DireccionClienteService();
      final todasDirecciones = await direccionesService
          .getDireccionesPorCliente();
      final clienteIds = _clientesFiltrados.map((c) => c.clie_Id).toSet();
      _direccionesFiltradas = todasDirecciones
          .where((d) => clienteIds.contains(d.clie_id))
          .toList();
      final Set<Marker> markers = {};
      for (var d in _direccionesFiltradas) {
        final cliente = _clientesFiltrados.firstWhere(
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
                GestureDetector(
                  onTap: () {
                    _customInfoWindowController.hideInfoWindow!();
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child:
                                        (cliente.clie_ImagenDelNegocio !=
                                                null &&
                                            cliente
                                                .clie_ImagenDelNegocio!
                                                .isNotEmpty)
                                        ? Image.network(
                                            cliente.clie_ImagenDelNegocio!,
                                            width: 220,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
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
                                            width: 220,
                                            height: 140,
                                            child: const Icon(
                                              Icons.store,
                                              size: 60,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  cliente.clie_NombreNegocio ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  // Nombre completo del cliente
                                  'Cliente: ${(cliente.clie_Nombres ?? '')} ${(cliente.clie_Apellidos ?? '')}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (cliente.clie_RTN != null &&
                                    cliente.clie_RTN!.isNotEmpty)
                                  Text(
                                    'RTN: ${cliente.clie_RTN}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                if (cliente.clie_DNI != null &&
                                    cliente.clie_DNI!.isNotEmpty)
                                  Text(
                                    'DNI: ${cliente.clie_DNI}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (cliente.clie_Telefono != null &&
                                    cliente.clie_Telefono != '')
                                  Text(
                                    'Teléfono: ${cliente.clie_Telefono}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  'Dirección:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${d.dicl_direccionexacta}, ${d.muni_descripcion}, ${d.depa_descripcion}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                if (d.dicl_observaciones.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Observaciones: ${d.dicl_observaciones}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
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
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                ),
                LatLng(d.dicl_latitud!, d.dicl_longitud!),
              );
            },
          ),
        );
      }
      // Generar orden de paradas automáticamente (sin necesidad de calcular ruta)
      List<Map<String, dynamic>> orden = [];
      if (_userLocation != null) {
        orden.add({
          'tipo': 'origen',
          'nombre': 'Tu ubicación',
          'direccion': '',
          'latlng': _userLocation,
        });
      }
      // Ordenar todas las direcciones por distancia desde la ubicación del usuario
      if (_direccionesFiltradas.isNotEmpty && _userLocation != null) {
        final direccionesOrdenadas = List<DireccionCliente>.from(
          _direccionesFiltradas,
        );
        direccionesOrdenadas.sort((a, b) {
          final distA = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            a.dicl_latitud!,
            a.dicl_longitud!,
          );
          final distB = Geolocator.distanceBetween(
            _userLocation!.latitude,
            _userLocation!.longitude,
            b.dicl_latitud!,
            b.dicl_longitud!,
          );
          return distA.compareTo(distB);
        });
        for (var d in direccionesOrdenadas) {
          final cliente = _clientesFiltrados.firstWhere(
            (c) => c.clie_Id == d.clie_id,
            orElse: () => Cliente(),
          );
          orden.add({
            'tipo': 'parada',
            'nombre': cliente.clie_NombreNegocio ?? '',
            'cliente': cliente,
            'direccion':
                '${d.dicl_direccionexacta}, ${d.muni_descripcion}, ${d.depa_descripcion}',
            'latlng': LatLng(d.dicl_latitud!, d.dicl_longitud!),
          });
        }
      }
      setState(() {
        _markers = markers;
        // Solo limpiar _polylines si no hay una ruta activa
        if (_polylines.isEmpty) {
          _polylines = {};
        }
        if (_direccionesFiltradas.isNotEmpty) {
          _initialPosition = LatLng(
            _direccionesFiltradas.first.dicl_latitud!,
            _direccionesFiltradas.first.dicl_longitud!,
          );
        }
        _ordenParadas = orden;
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
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.descripcion ?? 'Ubicación Ruta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Ver orden de paradas',
            onPressed: () {
              // Solo abrir el drawer, NO mostrar la ruta automáticamente
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
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
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Orden de visitas',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _ordenParadas.isEmpty
                    ? const Center(child: Text('No hay orden disponible'))
                    : ListView.builder(
                        itemCount: _ordenParadas.length,
                        itemBuilder: (context, idx) {
                          final parada = _ordenParadas[idx];
                          if (parada['tipo'] == 'origen') {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF141A2F),
                                child: Icon(
                                  Icons.person_pin_circle,
                                  color: Color(0xFFD6B68A),
                                ),
                              ),
                              title: Text('Tu ubicación'),
                              onTap: () {
                                Navigator.of(context).pop();
                                if (_userLocation != null &&
                                    _mapController != null) {
                                  _mapController!.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: _userLocation!,
                                        zoom: 16,
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }
                          final cliente = parada['cliente'] as Cliente?;
                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF141A2F),
                              child: Text(
                                '${idx}',
                                style: const TextStyle(
                                  color: Color(0xFFD6B68A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cliente?.clie_Nombres != null &&
                                            cliente?.clie_Apellidos != null
                                        ? '${cliente?.clie_Nombres ?? ''} ${cliente?.clie_Apellidos ?? ''}'
                                        : parada['nombre'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Checkbox(value: false, onChanged: null),
                              ],
                            ),
                            children: [
                              if (cliente?.clie_NombreNegocio != null &&
                                  cliente!.clie_NombreNegocio!.isNotEmpty)
                                ListTile(
                                  title: const Text('Negocio'),
                                  subtitle: Text(
                                    cliente.clie_NombreNegocio ?? '',
                                  ),
                                ),
                              if (cliente?.clie_Telefono != null &&
                                  cliente?.clie_Telefono != '')
                                ListTile(
                                  title: const Text('Teléfono'),
                                  subtitle: Text(cliente?.clie_Telefono ?? ''),
                                ),
                              if (parada['direccion'] != null &&
                                  parada['direccion'] != '')
                                ListTile(
                                  title: const Text('Dirección'),
                                  subtitle: Text(parada['direccion']),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF141A2F,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFD6B68A,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.w500
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.location_on,
                                        size: 18,
                                      ),
                                      label: const Text('Mostrar en mapa'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        if (parada['latlng'] != null &&
                                            _mapController != null) {
                                          _mapController!.animateCamera(
                                            CameraUpdate.newCameraPosition(
                                              CameraPosition(
                                                target: parada['latlng'],
                                                zoom: 16,
                                              ),
                                            ),
                                          );
                                          // Opcional: mostrar info window si lo deseas
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF141A2F,
                                        ),
                                        foregroundColor: const Color(
                                          0xFFD6B68A,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.alt_route,
                                        size: 18,
                                      ),
                                      label: const Text('Ver ruta'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        final paradaLatLng = parada['latlng'];
                                        final idxDireccion = _direccionesFiltradas.indexWhere(
                                          (d) => d.dicl_latitud == paradaLatLng.latitude && d.dicl_longitud == paradaLatLng.longitude,
                                        );
                                        if (_userLocation != null && idxDireccion != -1) {
                                          final destino = _direccionesFiltradas[idxDireccion];
                                          _mostrarRutaACliente(destino);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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
                            : () async {
                                await _loadDirecciones();
                                if (_direccionesFiltradas.isNotEmpty &&
                                    _userLocation != null) {
                                  // Buscar el cliente más cercano por ruta real
                                  DireccionCliente? closest =
                                      await _getClienteMasCercanoPorRuta();
                                  if (closest != null) {
                                    _mostrarRutaACliente(closest);
                                    if (_mapController != null) {
                                      _mapController!.animateCamera(
                                        CameraUpdate.newCameraPosition(
                                          CameraPosition(
                                            target: LatLng(
                                              closest.dicl_latitud!,
                                              closest.dicl_longitud!,
                                            ),
                                            zoom: 16,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
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
