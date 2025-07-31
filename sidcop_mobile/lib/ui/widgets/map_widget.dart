import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class MapWidget extends StatefulWidget {
  final LatLng initialPosition;
  final ValueChanged<LatLng>? onLocationSelected;
  final double height;
  final double? width;
  final double initialZoom;
  final bool showMarker;
  final Color? markerColor;
  final bool isFullScreen;
  final VoidCallback? onClose;
  final String? confirmButtonText;
  final bool showConfirmButton;

  const MapWidget({
    Key? key,
    required this.initialPosition,
    this.onLocationSelected,
    this.height = 250,
    this.width,
    this.initialZoom = 15.0,
    this.showMarker = true,
    this.markerColor,
    this.isFullScreen = false,
    this.onClose,
    this.confirmButtonText = 'Confirmar Ubicación',
    this.showConfirmButton = true,
  }) : super(key: key);

  static Future<LatLng?> showAsDialog({
    required BuildContext context,
    required LatLng initialPosition,
    String title = 'Seleccionar Ubicación',
    String confirmButtonText = 'Confirmar Ubicación',
  }) async {
    LatLng? selectedLocation;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: MapWidget(
            initialPosition: initialPosition,
            isFullScreen: true,
            onLocationSelected: (location) {
              selectedLocation = location;
            },
            confirmButtonText: confirmButtonText,
          ),
        ),
      ),
    );
    
    return selectedLocation;
  }

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController _mapController;
  late LatLng _currentPosition;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
    _updateMarker(_currentPosition);
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los servicios de ubicación están desactivados.')),
        );
      }
      return;
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se necesitan permisos de ubicación para esta función.')),
          );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los permisos de ubicación están permanentemente denegados. Por favor, actívalos manualmente en la configuración del dispositivo.'),
          ),
        );
      }
      return;
    }

    // Get current location
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _updateMarker(_currentPosition);
          _moveCamera(_currentPosition);
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error getting location: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación actual')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPosition != oldWidget.initialPosition) {
      _updatePosition(widget.initialPosition);
    }
  }

  void _updatePosition(LatLng newPosition) {
    if (_currentPosition != newPosition) {
      setState(() {
        _currentPosition = newPosition;
        _updateMarker(newPosition);
      });
      _moveCamera(newPosition);
    }
  }

  void _updateMarker(LatLng position) {
    if (widget.showMarker) {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Ubicación seleccionada'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.markerColor != null
                ? _colorToHue(widget.markerColor!)
                : BitmapDescriptor.hueRed,
          ),
        ),
      };
    } else {
      _markers.clear();
    }
  }

  Future<void> _moveCamera(LatLng position) async {
    try {
      await _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: await _mapController.getZoomLevel(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error moving camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isFullScreen) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentPosition.latitude.toStringAsFixed(6)}, ${_currentPosition.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _moveCamera(_currentPosition);
                },
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: widget.initialZoom,
                ),
                markers: _markers,
                onTap: widget.onLocationSelected != null ? (latLng) {
                  widget.onLocationSelected!(latLng);
                  _updatePosition(latLng);
                } : null,
                // Optimización de rendimiento
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                zoomControlsEnabled: !widget.isFullScreen,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // We'll use our custom button
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                mapType: MapType.normal,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                // Mejoras de rendimiento
                compassEnabled: false,
                mapToolbarEnabled: false,
                buildingsEnabled: false,
                trafficEnabled: false,
                indoorViewEnabled: false,
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  mini: true,
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location, color: Colors.black87, size: 20),
                ),
              ),
            ],
          ),
        ),
        if (widget.isFullScreen && widget.showConfirmButton && widget.onLocationSelected != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                widget.onLocationSelected!(_currentPosition);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(widget.confirmButtonText ?? 'Confirmar'),
            ),
          ),
      ],
    );

    if (widget.isFullScreen) {
      return mapContent;
    }

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: mapContent,
      ),
    );
  }

  double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue / 360.0 * 255.0;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
