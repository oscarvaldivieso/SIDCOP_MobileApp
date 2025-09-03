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
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:sidcop_mobile/services/GlobalService.dart';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/visita_create.dart';

List<Map<String, dynamic>> _ordenParadas = [];
List<DireccionCliente> _direccionesFiltradas = [];
List<Cliente> _clientesFiltrados = [];
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
final Set<int> _direccionesVisitadas = {};

class RutaMapScreen extends StatefulWidget {
  final int rutaId;
  final String? descripcion;
  final int? vendId; // vend_Id opcional pasado desde la pantalla anterior
  const RutaMapScreen({
    Key? key,
    required this.rutaId,
    this.descripcion,
    this.vendId,
  }) : super(key: key);

  @override
  State<RutaMapScreen> createState() => _RutaMapScreenState();
}

bool isOnline = true;

class _RutaMapScreenState extends State<RutaMapScreen> {
  // Removed unused _rutaImagenMapaStatic
  // Descarga y guarda la imagen de Google Maps Static
  Future<String?> guardarImagenDeMapaStatic(
    String imageUrl,
    String nombreArchivo,
  ) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$nombreArchivo.png';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        try {
          final metaPath = '${directory.path}/$nombreArchivo.url.txt';
          final metaFile = File(metaPath);
          await metaFile.writeAsString(
            'url:$imageUrl\nbytes:${response.bodyBytes.length}',
          );
        } catch (_) {}
        developer.log(
          'DEBUG: guardarImagenDeMapaStatic saved $filePath',
          name: 'RutasMapScreen',
        );
        return filePath;
      }
    } catch (e) {
      developer.log(
        'Error guardando imagen de mapa: $e',
        name: 'RutasMapScreen',
      );
    }
    return null;
  }

  // Paleta local (solo para esta pantalla)
  static const Color _darkBg = Color(0xFF141A2F);
  static const Color _gold = Color(0xFFD6B68A);
  static const Color _body = Color(0xFFE6E8EC);
  static const Color _bodyDim = Color(0xFFB5B8BF);
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
        // store the full route points into the class-level list and set the visible polyline
        _activeRoutePoints = points;
        _setPolylineFromActivePoints();
      }
    }
  }

  final String _googleApiKey = mapApikey;
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  MapType _mapType = MapType.hybrid;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  // active route points for the currently displayed polyline
  List<LatLng> _activeRoutePoints = [];
  bool _loading = true;
  LatLng? _initialPosition;
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  // Icono personalizado para "negocio"
  BitmapDescriptor? _negocioIcon;
  bool _generatingNegocioIcon = false;
  // Clientes marcados como visitados (checkbox en la barra lateral)
  // Eliminado: Set<int> _clientesVisitados
  bool _enviandoVisita = false;
  // _historialCargado removed (not used)

  Future<void> _cargarHistorialVisitas(Set<int?> diclIdsRuta) async {
    try {
      final servicio = ClientesVisitaHistorialService();
      // Usar el endpoint general y filtrar localmente por vendedor global
      final historial = await servicio.listar();
      // Filtrar historial por los clientes que pertenecen a la ruta
      // y por el vendedor actual (globalVendId)
      final visitasFiltradasModel = historial
          .where(
            (h) =>
                h.diCl_Id != null &&
                (diclIdsRuta.isEmpty || diclIdsRuta.contains(h.diCl_Id)),
          )
          .toList();

      // Mostrar las visitas ya filtradas (modelos) para diagnóstico
      print(
        'Visitas filtradas (models): ${visitasFiltradasModel.map((h) => {'clVi_Id': h.clVi_Id, 'diCl_Id': h.diCl_Id, 'vend_Id': h.vend_Id}).toList()}',
      );

      final direccionesPrevias = visitasFiltradasModel
          .map((h) => h.diCl_Id!)
          .toSet();
      setState(() {
        _direccionesVisitadas.clear();
        _direccionesVisitadas.addAll(direccionesPrevias);
      });
      // (Se omite impresión adicional) direccionesPrevias actualizado
    } catch (e) {
      developer.log('Error al cargar historial: $e', name: 'RutasMapScreen');
    }
  }

  // NOTE: Visit-adding logic removed. Visit creation should be handled in a dedicated
  // screen. The checkbox will now redirect to the visit-entry screen.

  Stream<Position>? _positionStream;

  Future<void> _openExternalDirections(LatLng destino) async {
    if (_userLocation == null) return;
    final origin = '${_userLocation!.latitude},${_userLocation!.longitude}';
    final dest = '${destino.latitude},${destino.longitude}';
    // Prefer Google Maps app scheme
    final googleMapsUri = Uri.parse('google.navigation:q=$dest&mode=d');
    // Fallback to web directions
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
        return;
      }
    } catch (_) {}
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openExternalWaze(LatLng destino) async {
    final lat = destino.latitude;
    final lon = destino.longitude;
    final wazeUri = Uri.parse('waze://?ll=$lat,$lon&navigate=yes');
    final webUri = Uri.parse(
      'https://www.waze.com/ul?ll=$lat,$lon&navigate=yes',
    );
    try {
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri);
        return;
      }
    } catch (_) {}
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

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
      // Trim active route polyline as user moves
      if (_userLocation != null) {
        _trimRouteToPosition(_userLocation!);
      }
      // Cuando la ubicación cambia, recalcula el orden de visitas
      _loadDirecciones();
    });
    // Pre-generar el icono de negocio en segundo plano
    _generateNegocioMarker();
  }

  void _updateUserMarker() {
    _markers = _markers
        .where((m) => m.markerId.value != 'user_location')
        .toSet();
  }

  Future<void> _centerOnUser() async {
    if (_mapController == null) return;
    LatLng? pos = _userLocation;
    if (pos == null) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        pos = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() => _userLocation = pos);
        }
      } catch (_) {
        return;
      }
    }
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 16)),
    );
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

  void _setPolylineFromActivePoints() {
    if (_activeRoutePoints.isEmpty) {
      setState(() {
        _polylines = {};
      });
      return;
    }
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_cliente'),
          color: Colors.blue,
          width: 4,
          patterns: [],
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
          points: List<LatLng>.from(_activeRoutePoints),
        ),
      };
    });
  }

  void _trimRouteToPosition(LatLng userPos, {double thresholdMeters = 20}) {
    if (_activeRoutePoints.isEmpty) return;
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _activeRoutePoints.length; i++) {
      final p = _activeRoutePoints[i];
      final d = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    int startIdx;
    if (bestDist <= thresholdMeters) {
      // user is within threshold of the nearest route point — drop up to it
      startIdx = bestIdx;
    } else {
      // not quite on the route point yet; keep a small look-back to avoid
      // trimming too aggressively and producing a jumpy polyline
      startIdx = (bestIdx > 0) ? bestIdx - 1 : 0;
    }
    if (startIdx > 0 && startIdx < _activeRoutePoints.length) {
      _activeRoutePoints = _activeRoutePoints.sublist(startIdx);
      _setPolylineFromActivePoints();
    }
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
      if (_negocioIcon == null && !_generatingNegocioIcon) {
        await _generateNegocioMarker();
      }
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
      // Cargar historial de visitas para marcar ya visitados: usar dicl_id y vendedor
      final diclIdsRuta = _direccionesFiltradas.map((d) => d.dicl_id).toSet();
      await _cargarHistorialVisitas(diclIdsRuta);
      final Set<Marker> markers = {};
      for (var d in _direccionesFiltradas) {
        final cliente = _clientesFiltrados.firstWhere(
          (c) => c.clie_Id == d.clie_id,
        );
        markers.add(
          Marker(
            markerId: MarkerId(d.dicl_id.toString()),
            position: LatLng(d.dicl_latitud!, d.dicl_longitud!),
            icon:
                _negocioIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueYellow,
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
                        return Container(
                          decoration: BoxDecoration(
                            color: _darkBg,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Padding(
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
                                      color: _gold,
                                      fontFamily: 'Satoshi',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cliente: ${(cliente.clie_Nombres ?? '')} ${(cliente.clie_Apellidos ?? '')}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: _body,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (cliente.clie_RTN != null &&
                                      cliente.clie_RTN!.isNotEmpty)
                                    Text(
                                      'RTN: ${cliente.clie_RTN}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: _body,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  if (cliente.clie_DNI != null &&
                                      cliente.clie_DNI!.isNotEmpty)
                                    Text(
                                      'DNI: ${cliente.clie_DNI}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: _body,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (cliente.clie_Telefono != null &&
                                      cliente.clie_Telefono != '')
                                    Text(
                                      'Teléfono: ${cliente.clie_Telefono}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: _body,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Action buttons: Ruta + external navigation
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _gold,
                                            foregroundColor: _darkBg,
                                          ),
                                          icon: const Icon(Icons.alt_route),
                                          label: const Text('Ruta'),
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            // try to find the direccion for this cliente
                                            DireccionCliente? direccion;
                                            try {
                                              direccion = _direccionesFiltradas
                                                  .firstWhere(
                                                    (d) =>
                                                        d.clie_id ==
                                                        cliente.clie_Id,
                                                  );
                                            } catch (_) {
                                              direccion = null;
                                            }
                                            if (direccion != null &&
                                                direccion.dicl_latitud !=
                                                    null &&
                                                direccion.dicl_longitud !=
                                                    null) {
                                              _mostrarRutaACliente(direccion);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                icon: const Icon(Icons.map),
                                                label: const Text(
                                                  'Google Maps',
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  DireccionCliente? direccion;
                                                  try {
                                                    direccion =
                                                        _direccionesFiltradas
                                                            .firstWhere(
                                                              (d) =>
                                                                  d.clie_id ==
                                                                  cliente
                                                                      .clie_Id,
                                                            );
                                                  } catch (_) {
                                                    direccion = null;
                                                  }
                                                  if (direccion != null &&
                                                      direccion.dicl_latitud !=
                                                          null &&
                                                      direccion.dicl_longitud !=
                                                          null) {
                                                    _openExternalDirections(
                                                      LatLng(
                                                        direccion.dicl_latitud!,
                                                        direccion
                                                            .dicl_longitud!,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.navigation,
                                                ),
                                                label: const Text('Waze'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  DireccionCliente? direccion;
                                                  try {
                                                    direccion =
                                                        _direccionesFiltradas
                                                            .firstWhere(
                                                              (d) =>
                                                                  d.clie_id ==
                                                                  cliente
                                                                      .clie_Id,
                                                            );
                                                  } catch (_) {
                                                    direccion = null;
                                                  }
                                                  if (direccion != null &&
                                                      direccion.dicl_latitud !=
                                                          null &&
                                                      direccion.dicl_longitud !=
                                                          null) {
                                                    _openExternalWaze(
                                                      LatLng(
                                                        direccion.dicl_latitud!,
                                                        direccion
                                                            .dicl_longitud!,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dirección:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _gold,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  Text(
                                    '${d.dicl_direccionexacta}, ${d.muni_descripcion}, ${d.depa_descripcion}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: _body,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  if (d.dicl_observaciones.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Observaciones: ${d.dicl_observaciones}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: _body,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
                      color: _darkBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
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
                              color: _gold,
                              fontFamily: 'Satoshi',
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
                              color: _body,
                              fontFamily: 'Satoshi',
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

  // Genera un BitmapDescriptor personalizado estilizado con el color dorado y un ícono de tienda
  Future<void> _generateNegocioMarker() async {
    if (_generatingNegocioIcon || _negocioIcon != null) return;
    _generatingNegocioIcon = true;
    try {
      const double size = 140; // tamaño base del canvas
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint fillPaint = Paint()..color = const Color(0xFFD6B68A);
      final Paint strokePaint = Paint()
        ..color = const Color(0xFF141A2F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      // Gota simétrica mejor proporcionada
      final double r = size * 0.30; // radio base ligeramente menor para nitidez
      final Offset c = Offset(size / 2, r + 6);
      const double tailFactor = 1.75; // largo controlado
      final double bottomY = c.dy + r * tailFactor;
      final Path drop = Path();
      // Punto superior
      drop.moveTo(c.dx, c.dy - r);
      // Lado derecho (dos curvas: superior y hacia la punta)
      drop.quadraticBezierTo(
        c.dx + r,
        c.dy - r,
        c.dx + r * 0.92,
        c.dy + r * 0.15,
      );
      drop.quadraticBezierTo(c.dx + r * 0.60, c.dy + r * 0.95, c.dx, bottomY);
      // Lado izquierdo espejo
      drop.quadraticBezierTo(
        c.dx - r * 0.60,
        c.dy + r * 0.95,
        c.dx - r * 0.92,
        c.dy + r * 0.15,
      );
      drop.quadraticBezierTo(c.dx - r, c.dy - r, c.dx, c.dy - r);
      drop.close();

      canvas.drawPath(drop, fillPaint);
      canvas.drawPath(drop, strokePaint);

      // Ícono de tienda dentro del círculo usando el font de Material Icons
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.store.codePoint),
          style: TextStyle(
            fontSize: r * 1.55, // escala relativa al radio
            fontFamily: 'MaterialIcons',
            color: const Color(0xFF141A2F),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));

      // Finalizar y convertir a bytes
      final ui.Picture picture = recorder.endRecording();
      final double totalHeight =
          bottomY + r * 0.35; // margen extra para evitar corte
      final ui.Image image = await picture.toImage(
        size.toInt(),
        totalHeight.toInt(),
      );
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final icon = BitmapDescriptor.fromBytes(pngBytes);
        setState(() {
          _negocioIcon = icon;
        });
        // Reemplazar íconos existentes de clientes si ya estaban en el mapa
        _rebuildMarkersWithNegocioIcon();
      }
    } catch (e) {
      // Fallback silencioso: deja el icono por defecto
    } finally {
      _generatingNegocioIcon = false;
    }
  }

  void _rebuildMarkersWithNegocioIcon() {
    if (_negocioIcon == null || _markers.isEmpty) return;
    final updated = _markers.map((m) {
      // si en el futuro añadimos marker de usuario lo saltamos
      if (m.markerId.value == 'user_location') return m;
      return m.copyWith(iconParam: _negocioIcon);
    }).toSet();
    setState(() {
      _markers = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: const PopupMenuThemeData(
          color: _darkBg,
          textStyle: TextStyle(
            fontFamily: 'Satoshi',
            color: _body,
            fontSize: 14,
          ),
        ),
        dividerColor: const Color(0xFF2A344A),
      ),
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              backgroundColor: _darkBg,
              iconTheme: const IconThemeData(color: _gold),
              title: Text(
                widget.descripcion ?? 'Ubicación Ruta',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: _gold,
                ),
              ),
              actions: [
                PopupMenuButton<MapType>(
                  color: _darkBg,
                  icon: const Icon(Icons.map, color: _gold),
                  onSelected: (type) {
                    setState(() {
                      _mapType = type;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: MapType.normal,
                      child: Text('Normal', style: TextStyle(color: _body)),
                    ),
                    const PopupMenuItem(
                      value: MapType.hybrid,
                      child: Text('Satelital', style: TextStyle(color: _body)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.list_alt, color: _gold),
                  tooltip: 'Ver orden de paradas',
                  onPressed: () {
                    // Solo abrir el drawer, NO mostrar la ruta automáticamente
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
              ],
            ),
            endDrawer: Drawer(
              backgroundColor: _darkBg,
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
                          fontFamily: 'Satoshi',
                          color: _gold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ordenParadas.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay orden disponible',
                                style: TextStyle(
                                  color: _bodyDim,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _ordenParadas.length,
                              itemBuilder: (context, idx) {
                                final parada = _ordenParadas[idx];
                                if (parada['tipo'] == 'origen') {
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: _darkBg,
                                      child: Icon(
                                        Icons.person_pin_circle,
                                        color: _gold,
                                      ),
                                    ),
                                    title: const Text(
                                      'Tu ubicación',
                                      style: TextStyle(
                                        color: _body,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
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
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    collapsedIconColor: _gold,
                                    iconColor: _gold,
                                    leading: CircleAvatar(
                                      backgroundColor: _darkBg,
                                      child: Text(
                                        '$idx',
                                        style: const TextStyle(
                                          color: _gold,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cliente?.clie_Nombres != null &&
                                                    cliente?.clie_Apellidos !=
                                                        null
                                                ? '${cliente?.clie_Nombres ?? ''} ${cliente?.clie_Apellidos ?? ''}'
                                                : parada['nombre'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _body,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                        ),
                                        // Marcar dirección como visitada si su dicl_id está en _direccionesVisitadas
                                        if (parada['latlng'] != null)
                                          Builder(
                                            builder: (context) {
                                              int? dicl_Id;
                                              final paradaLatLng =
                                                  parada['latlng'] as LatLng?;
                                              if (paradaLatLng != null) {
                                                final idxDireccion =
                                                    _direccionesFiltradas
                                                        .indexWhere(
                                                          (d) =>
                                                              d.dicl_latitud ==
                                                                  paradaLatLng
                                                                      .latitude &&
                                                              d.dicl_longitud ==
                                                                  paradaLatLng
                                                                      .longitude,
                                                        );
                                                if (idxDireccion != -1) {
                                                  dicl_Id =
                                                      _direccionesFiltradas[idxDireccion]
                                                          .dicl_id;
                                                }
                                              }
                                              developer.log(
                                                'Render Checkbox: dicl_Id=$dicl_Id, visitados=$_direccionesVisitadas',
                                                name: 'RutasMapScreen',
                                              );
                                              return Checkbox(
                                                value:
                                                    dicl_Id != null &&
                                                    _direccionesVisitadas
                                                        .contains(dicl_Id),
                                                onChanged:
                                                    (dicl_Id != null &&
                                                            _direccionesVisitadas
                                                                .contains(
                                                                  dicl_Id,
                                                                )) ||
                                                        _enviandoVisita
                                                    ? null
                                                    : (val) async {
                                                        if (val == true &&
                                                            cliente != null) {
                                                          // Redirect to visit-entry screen
                                                          final paradaLatLng =
                                                              parada['latlng']
                                                                  as LatLng?;
                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                          final result = await Navigator.of(context).push<bool>(
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  const VisitaCreateScreen(),
                                                              settings: RouteSettings(
                                                                arguments: {
                                                                  'clienteId':
                                                                      cliente
                                                                          .clie_Id,
                                                                  'diclId':
                                                                      dicl_Id,
                                                                  // parada (destination) coordinates
                                                                  'paradaLat':
                                                                      paradaLatLng
                                                                          ?.latitude,
                                                                  'paradaLon':
                                                                      paradaLatLng
                                                                          ?.longitude,
                                                                  // user (origin) coordinates at that moment
                                                                  'userLat':
                                                                      _userLocation
                                                                          ?.latitude,
                                                                  'userLon':
                                                                      _userLocation
                                                                          ?.longitude,
                                                                  'rutaId': widget
                                                                      .rutaId,
                                                                },
                                                              ),
                                                            ),
                                                          );
                                                          if (result == true) {
                                                            await _loadDirecciones();
                                                          }
                                                        }
                                                      },
                                                checkColor: Colors.green,
                                                side: const BorderSide(
                                                  color: _gold,
                                                  width: 1.4,
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    children: [
                                      if (cliente?.clie_NombreNegocio != null &&
                                          cliente!
                                              .clie_NombreNegocio!
                                              .isNotEmpty)
                                        ListTile(
                                          title: const Text(
                                            'Negocio',
                                            style: TextStyle(
                                              color: _gold,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          subtitle: Text(
                                            cliente.clie_NombreNegocio ?? '',
                                            style: const TextStyle(
                                              color: _body,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                        ),
                                      if (cliente?.clie_Telefono != null &&
                                          cliente?.clie_Telefono != '')
                                        ListTile(
                                          title: const Text(
                                            'Teléfono',
                                            style: TextStyle(
                                              color: _gold,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          subtitle: Text(
                                            cliente?.clie_Telefono ?? '',
                                            style: const TextStyle(
                                              color: _body,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                        ),
                                      if (parada['direccion'] != null &&
                                          parada['direccion'] != '')
                                        ListTile(
                                          title: const Text(
                                            'Dirección',
                                            style: TextStyle(
                                              color: _gold,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          subtitle: Text(
                                            parada['direccion'],
                                            style: const TextStyle(
                                              color: _body,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                          horizontal: 16.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _darkBg,
                                                foregroundColor: _gold,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Satoshi',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.location_on,
                                                size: 18,
                                              ),
                                              label: const Text('Ubicación'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                if (parada['latlng'] != null &&
                                                    _mapController != null) {
                                                  _mapController!.animateCamera(
                                                    CameraUpdate.newCameraPosition(
                                                      CameraPosition(
                                                        target:
                                                            parada['latlng'],
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
                                                backgroundColor: _darkBg,
                                                foregroundColor: _gold,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Satoshi',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.alt_route,
                                                size: 18,
                                              ),
                                              label: const Text('Ver ruta'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                final paradaLatLng =
                                                    parada['latlng'];
                                                final idxDireccion =
                                                    _direccionesFiltradas
                                                        .indexWhere(
                                                          (d) =>
                                                              d.dicl_latitud ==
                                                                  paradaLatLng
                                                                      .latitude &&
                                                              d.dicl_longitud ==
                                                                  paradaLatLng
                                                                      .longitude,
                                                        );
                                                if (_userLocation != null &&
                                                    idxDireccion != -1) {
                                                  final destino =
                                                      _direccionesFiltradas[idxDireccion];
                                                  _mostrarRutaACliente(destino);
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          collapsedIconColor: _gold,
                                          iconColor: _gold,
                                          tilePadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Abrir en...',
                                            style: TextStyle(
                                              color: _body,
                                              fontFamily: 'Satoshi',
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16.0,
                                                    vertical: 6.0,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: _darkBg,
                                                      foregroundColor: _gold,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 14,
                                                            fontFamily:
                                                                'Satoshi',
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons.map,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      'Google Maps',
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      final paradaLatLng =
                                                          parada['latlng']
                                                              as LatLng?;
                                                      if (paradaLatLng !=
                                                          null) {
                                                        await _openExternalDirections(
                                                          paradaLatLng,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(width: 12),
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: _darkBg,
                                                      foregroundColor: _gold,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      textStyle:
                                                          const TextStyle(
                                                            fontSize: 14,
                                                            fontFamily:
                                                                'Satoshi',
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons.navigation,
                                                      size: 18,
                                                    ),
                                                    label: const Text('Waze'),
                                                    onPressed: () async {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      final paradaLatLng =
                                                          parada['latlng']
                                                              as LatLng?;
                                                      if (paradaLatLng !=
                                                          null) {
                                                        await _openExternalWaze(
                                                          paradaLatLng,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ); // end Theme
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
                ? const Center(
                    child: Text(
                      'No hay direcciones para mostrar',
                      style: TextStyle(color: _bodyDim, fontFamily: 'Satoshi'),
                    ),
                  )
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
                              backgroundColor: _darkBg,
                              foregroundColor: _gold,
                              onPressed:
                                  _userLocation == null || _markers.isEmpty
                                  ? null
                                  : () async {
                                      await _loadDirecciones();
                                      if (_direccionesFiltradas.isNotEmpty &&
                                          _userLocation != null) {
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
                              backgroundColor: _darkBg,
                              foregroundColor: _gold,
                              onPressed: _mapController == null
                                  ? null
                                  : _centerOnUser,
                              child: const Icon(Icons.my_location),
                              tooltip: 'Centrar en mi ubicación',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (_enviandoVisita)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD6B68A)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
