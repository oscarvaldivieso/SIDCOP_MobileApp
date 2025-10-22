// Importaciones necesarias para la funcionalidad del mapa
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla que muestra la ubicación del cliente en un mapa interactivo
/// Permite visualizar las diferentes direcciones del cliente y abrirlas en Google Maps

class ClientLocationScreen extends StatefulWidget {
  /// Lista de ubicaciones del cliente con sus coordenadas y direcciones
  final List<Map<String, dynamic>> locations;
  
  /// Nombre del cliente que se muestra en el marcador del mapa
  final String clientName;
  
  /// Constructor de la pantalla de ubicación del cliente
  /// 
  /// [locations] Lista de ubicaciones con coordenadas y direcciones
  /// [clientName] Nombre del cliente para mostrar en la interfaz
  const ClientLocationScreen({
    Key? key,
    required this.locations,
    required this.clientName,
  }) : super(key: key);

  @override
  State<ClientLocationScreen> createState() => _ClientLocationScreenState();
}

/// Estado que maneja la lógica de la pantalla de ubicación del cliente
class _ClientLocationScreenState extends State<ClientLocationScreen> {
  // Controlador para el mapa de Google Maps
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  
  // Ubicación actualmente seleccionada
  late Map<String, dynamic> _selectedLocation;
  
  // Conjunto de marcadores para mostrar en el mapa
  final Set<Marker> _markers = {};
  
  // Estado de carga del mapa
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Inicializar con la primera ubicación si existe
    if (widget.locations.isNotEmpty) {
      _selectedLocation = widget.locations.first;
      _setupMap();
    } else {
      _isLoading = false; // No hay ubicaciones para mostrar
    }
  }

  /// Configura el mapa con la ubicación inicial
  void _setupMap() {
    _updateMap();
  }

  /// Actualiza el mapa con la ubicación seleccionada
  void _updateMap() {
    // Obtener coordenadas de la ubicación seleccionada
    final lat = _selectedLocation['diCl_Latitud'];
    final lng = _selectedLocation['diCl_Longitud'];
    
    // Verificar si las coordenadas son válidas
    if (lat == null || lng == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Crear objeto LatLng con las coordenadas

    final LatLng clientLocation = LatLng(
      _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0,
      _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0,
    );
    
    // Actualizar la interfaz con el nuevo marcador
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
      _isLoading = false; // Finalizar carga
    });

    // Mover la cámara a la ubicación seleccionada
    _controller.future.then((controller) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(clientLocation, 15), // Zoom 15 para ver la calle
      );
    });
  }

  /// Construye la interfaz de usuario de la pantalla

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra de aplicación con título y botón de regreso
      appBar: AppBar(
        title: const Text('Ubicaciones del Cliente'),
        backgroundColor: const Color(0xFF141A2F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Cuerpo principal con selector de ubicación y mapa
      body: Column(
        children: [
          // Selector de ubicación (solo se muestra si hay más de una ubicación)
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
                          _updateMap(); // Actualizar el mapa con la nueva ubicación
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          // Contenedor del mapa o mensaje de carga
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Construye el cuerpo principal de la pantalla según la plataforma
  /// 
  /// Muestra el mapa en dispositivos móviles y una alternativa en web/escritorio
  Widget _buildBody() {
    // Versión web - Muestra un botón para abrir en Google Maps
    if (kIsWeb) {
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
    // Versión móvil (Android/iOS) - Muestra el mapa integrado
    } else if (Platform.isAndroid || Platform.isIOS) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0,
                  _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0,
                ),
                zoom: 15, // Nivel de zoom por defecto
              ),
              markers: _markers, // Marcadores en el mapa
              myLocationButtonEnabled: true, // Botón de mi ubicación
              myLocationEnabled: true, // Mostrar mi ubicación
              zoomControlsEnabled: true, // Controles de zoom
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller); // Inicializar controlador
              },
            );
    // Otras plataformas (escritorio)
    } else {
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

  /// Abre la ubicación en Google Maps (para web o cuando el mapa integrado no está disponible)
  Future<void> _openInGoogleMaps() async {
    final lat = _selectedLocation['diCl_Latitud']?.toDouble() ?? 0.0;
    final lng = _selectedLocation['diCl_Longitud']?.toDouble() ?? 0.0;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: Mostrar coordenadas si no se puede abrir la URL
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
    // Liberar recursos del controlador del mapa
    _controller.future.then((controller) => controller.dispose());
    super.dispose();
  }
}
