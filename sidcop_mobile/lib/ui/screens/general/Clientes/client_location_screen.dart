import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientLocationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> locations;
  final String clientName;
  
  const ClientLocationScreen({
    Key? key,
    required this.locations,
    required this.clientName,
  }) : super(key: key);

  @override
  State<ClientLocationScreen> createState() => _ClientLocationScreenState();
}

class _ClientLocationScreenState extends State<ClientLocationScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  late Map<String, dynamic> _selectedLocation;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.locations.isNotEmpty) {
      _selectedLocation = widget.locations.first;
      _setupMap();
    } else {
      _isLoading = false;
    }
  }

  void _setupMap() {
    _updateMap();
  }

  void _updateMap() {
    final lat = _selectedLocation['diCl_Latitud'];
    final lng = _selectedLocation['diCl_Longitud'];
    
    if (lat == null || lng == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final LatLng clientLocation = LatLng(
      _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0,
      _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0,
    );
    
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('client_location'),
          position: clientLocation,
          infoWindow: InfoWindow(
            title: widget.clientName,
            snippet: _selectedLocation['diCl_DireccionExacta'] ?? 'Sin dirección',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      _isLoading = false;
    });

    // Mover la cámara a la ubicación seleccionada
    _controller.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(clientLocation, 15),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicaciones del Cliente'),
        backgroundColor: const Color(0xFF141A2F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Dropdown para seleccionar ubicación
          if (widget.locations.length > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF141A2F), width: 1.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedLocation,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF141A2F)),
                    items: widget.locations.map<DropdownMenuItem<Map<String, dynamic>>>((location) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: location,
                        child: Text(
                          location['diCl_DireccionExacta'] ?? 'Sin dirección',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (Map<String, dynamic>? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLocation = newValue;
                          _updateMap();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          // Mapa o mensaje de carga
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(),
        backgroundColor: const Color(0xFF141A2F),
        label: const Text('Volver al listado', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.list, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (kIsWeb) {
      // For web, show a button that opens Google Maps in a new tab
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'La visualización del mapa no está disponible en la versión web.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _openInGoogleMaps();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141A2F),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Abrir en Google Maps'),
            ),
          ],
        ),
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile, show the Google Map
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0,
                  _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0,
                ),
                zoom: 15,
              ),
              markers: _markers,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            );
    } else {
      // For other platforms (Windows, macOS, Linux)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'La visualización del mapa no está disponible en esta plataforma.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _openInGoogleMaps();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141A2F),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Abrir en Google Maps'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0;
    final lng = _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: Show coordinates if can't launch URL
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coordenadas: $lat, $lng'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.future.then((controller) => controller.dispose());
    super.dispose();
  }
}
