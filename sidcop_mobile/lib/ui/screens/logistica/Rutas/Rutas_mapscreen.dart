import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/VendedoresService.dart';
import 'package:sidcop_mobile/services/clientesService.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'dart:ui' as ui; // Para generar el bitmap custom
import 'dart:typed_data';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.Dart';
import 'package:sidcop_mobile/models/ClientesVisitaHistorialModel.Dart';

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
  // Icono personalizado para "negocio"
  BitmapDescriptor? _negocioIcon;
  bool _generatingNegocioIcon = false;
  // Clientes marcados como visitados (checkbox en la barra lateral)
  final Set<int> _clientesVisitados = {};
  bool _enviandoVisita = false;
  bool _historialCargado = false;

  Future<void> _cargarHistorialVisitas(Set<int?> clienteIdsRuta) async {
    if (_historialCargado) return; // evitar recargas múltiples en esta sesión
    try {
      final servicio = ClientesVisitaHistorialService();
      final historial = await servicio.listarPorVendedor();
      final previos = historial
          .where((h) => h.clie_Id != null && clienteIdsRuta.contains(h.clie_Id))
          .map((h) => h.clie_Id!)
          .toSet();
      if (previos.isNotEmpty) {
        setState(() {
          _clientesVisitados.addAll(previos);
        });
      }
      _historialCargado = true;
    } catch (_) {
      // Silencioso: si falla no bloquea la pantalla
    }
  }

  Future<void> _confirmarVisitaCliente(
    Cliente cliente,
    int indiceLista,
    LatLng? paradaLatLng,
  ) async {
    if (_enviandoVisita) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _darkBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirmar visita',
            style: TextStyle(
              color: _gold,
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Marcar al cliente "${cliente.clie_NombreNegocio ?? (cliente.clie_Nombres ?? '')}" como visitado?',
            style: const TextStyle(color: _body, fontFamily: 'Satoshi'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: _bodyDim, fontFamily: 'Satoshi'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirmar',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmado != true) return;
    try {
      setState(() => _enviandoVisita = true);
      final servicio = ClientesVisitaHistorialService();
      // TODO: Obtener usuario real autenticado. Usando 1 como placeholder.
      final int usuarioId = 1;
      // Obtener veRuId correcto usando el endpoint ListarPorRutas
      final vendedoresService = VendedoresService();
      final vendedoresPorRuta = await vendedoresService.listarPorRutas();
      final vendedorRuta = vendedoresPorRuta.firstWhere(
        (v) => v.ruta_Id == widget.rutaId && v.vend_Id == globalVendId,
      );
      final veruId = vendedorRuta?.veRu_Id ?? widget.rutaId;

      // Obtener la dirección seleccionada para este cliente/parada
      int? diclId;
      if (paradaLatLng != null) {
        final idxDireccion = _direccionesFiltradas.indexWhere(
          (d) =>
              d.dicl_latitud == paradaLatLng.latitude &&
              d.dicl_longitud == paradaLatLng.longitude,
        );
        if (idxDireccion != -1) {
          diclId = _direccionesFiltradas[idxDireccion].dicl_id;
        }
      }
      final registro = ClientesVisitaHistorialModel(
        veRu_Id: veruId,
        diCl_Id:
            diclId ??
            0, // Usa el id de la dirección seleccionada, o 0 si no se encuentra
        esVi_Id: 1, // O el estado que corresponda
        clVi_Observaciones: 'Visitado',
        clVi_Fecha: DateTime.now(),
        usua_Creacion: usuarioId,
        clVi_FechaCreacion: DateTime.now(),
      );
      await servicio.insertar(registro);
      if (mounted) {
        setState(() {
          if (cliente.clie_Id != null) {
            _clientesVisitados.add(cliente.clie_Id!);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _darkBg,
            content: const Text(
              'Cliente marcado como visitado',
              style: TextStyle(color: _gold, fontFamily: 'Satoshi'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              'Error al registrar visita: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoVisita = false);
    }
  }

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
      // Cargar historial de visitas para marcar ya visitados
      final idsRuta = _clientesFiltrados.map((c) => c.clie_Id).toSet();
      await _cargarHistorialVisitas(idsRuta);
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
      child: Scaffold(
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
            IconButton(
              icon: const Icon(Icons.list_alt, color: _gold),
              tooltip: 'Ver orden de paradas',
              onPressed: () {
                // Solo abrir el drawer, NO mostrar la ruta automáticamente
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
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
                                                cliente?.clie_Apellidos != null
                                            ? '${cliente?.clie_Nombres ?? ''} ${cliente?.clie_Apellidos ?? ''}'
                                            : parada['nombre'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _body,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ),
                                    if (cliente != null &&
                                        cliente.clie_Id != null)
                                      Checkbox(
                                        value: _clientesVisitados.contains(
                                          cliente.clie_Id,
                                        ),
                                        onChanged:
                                            _clientesVisitados.contains(
                                                  cliente.clie_Id,
                                                ) ||
                                                _enviandoVisita
                                            ? null
                                            : (val) async {
                                                if (val == true) {
                                                  await _confirmarVisitaCliente(
                                                    cliente,
                                                    idx,
                                                    parada['latlng'],
                                                  );
                                                }
                                              },
                                        checkColor: Colors.green,
                                        side: const BorderSide(
                                          color: _gold,
                                          width: 1.4,
                                        ),
                                      ),
                                  ],
                                ),
                                children: [
                                  if (cliente?.clie_NombreNegocio != null &&
                                      cliente!.clie_NombreNegocio!.isNotEmpty)
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
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _darkBg,
                                            foregroundColor: _gold,
                                            padding: const EdgeInsets.symmetric(
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
                                            backgroundColor: _darkBg,
                                            foregroundColor: _gold,
                                            padding: const EdgeInsets.symmetric(
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
                          onPressed: _userLocation == null || _markers.isEmpty
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
    );
  }
}
