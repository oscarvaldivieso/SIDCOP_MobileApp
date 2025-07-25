import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_input.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

class AddAddressScreen extends StatefulWidget {
  final int clientId;

  const AddAddressScreen({
    Key? key,
    required this.clientId,
  }) : super(key: key);

  @override
  _AddAddressScreenState createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionClienteService = DireccionClienteService();
  final _direccionExactaController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  List<Colonia> _colonias = [];
  Colonia? _selectedColonia;
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Map variables
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _selectedLocation = const LatLng(15.5, -86.8); // Default to Honduras center
  final Set<Marker> _markers = {};
  // Map controller will be initialized when the map is created

  @override
  void initState() {
    super.initState();
    _updateMarker(_selectedLocation);
    _loadColonias();
  }

  Future<void> _loadColonias() async {
    try {
      final colonias = await _direccionClienteService.getColonias();
      setState(() {
        _colonias = colonias;
        if (colonias.isNotEmpty) {
          _selectedColonia = colonias.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al cargar las colonias: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    _updateMarker(_selectedLocation);
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _updateMarker(location);
    });
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedColonia == null) {
      _showError('Por favor seleccione una colonia');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Crear el objeto de dirección sin intentar guardarlo
      final direccion = DireccionCliente(
        clieId: 0, // Se actualizará con el ID real del cliente después de crearlo
        coloId: _selectedColonia!.coloId,
        direccionExacta: _direccionExactaController.text.trim(),
        observaciones: _observacionesController.text.trim().isNotEmpty 
            ? _observacionesController.text.trim() 
            : null,
        latitud: _selectedLocation.latitude,
        longitud: _selectedLocation.longitude,
        usuaCreacion: 1, // TODO: Replace with actual user ID
        fechaCreacion: DateTime.now(),
      );

      // Mostrar los datos de la dirección que se guardarán
      print('=== Datos de Dirección Preparados ===');
      print('ID Colonia: ${direccion.coloId}');
      print('Dirección: ${direccion.direccionExacta}');
      print('Observaciones: ${direccion.observaciones ?? "Ninguna"}');
      print('Ubicación: (${direccion.latitud}, ${direccion.longitud})');
      print('====================================');
      
      // Solo devolver los datos de la dirección sin intentar guardar
      if (mounted) {
        Navigator.pop(context, direccion);
      }
    } catch (e) {
      _showError('Error al preparar la dirección: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          infoWindow: const InfoWindow(title: 'Ubicación seleccionada'),
        ),
      );
    });
  }



  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAddress,
            tooltip: 'Guardar dirección',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Colonias Dropdown
                    const Text(
                      'Colonia *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<Colonia>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            hint: const Text('Seleccione una colonia'),
                            value: _selectedColonia,
                            items: _colonias.map((colonia) {
                              return DropdownMenuItem<Colonia>(
                                value: colonia,
                                child: Text(colonia.coloDescripcion),
                              );
                            }).toList(),
                            onChanged: (Colonia? newValue) {
                              setState(() {
                                _selectedColonia = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor seleccione una colonia';
                              }
                              return null;
                            },
                          ),
                    const SizedBox(height: 16),
                    
                    // Dirección Exacta
                    CustomInput(
                      label: 'Dirección Exacta *',
                      controller: _direccionExactaController,
                      hint: 'Ingrese la dirección exacta',
                      errorText: _direccionExactaController.text.trim().isEmpty
                          ? 'Por favor ingrese la dirección exacta'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Observaciones
                    CustomInput(
                      label: 'Observaciones',
                      controller: _observacionesController,
                      hint: 'Ingrese observaciones adicionales',
                    ),
                    const SizedBox(height: 24),
                    
                    // Mapa
                    const Text(
                      'Seleccione la ubicación en el mapa:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation,
                            zoom: 15,
                          ),
                          markers: _markers,
                          onTap: _onMapTapped,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Botón de guardar
                    CustomButton(
                      text: 'Guardar Dirección',
                      onPressed: _isSubmitting ? null : _saveAddress,
                      height: 50,
                      icon: _isSubmitting 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _direccionExactaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
}
