import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:flutter/material.dart' show showMenu, RelativeRect;
import 'package:flutter/rendering.dart' show TextOverflow;
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/widgets/map_widget.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Text style constants for consistent typography
final TextStyle _titleStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

final TextStyle _labelStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

final TextStyle _hintStyle = const TextStyle(
  fontFamily: 'Satoshi',
  color: Colors.grey,
);

class AddAddressScreen extends StatefulWidget {
  final int clientId;

  const AddAddressScreen({Key? key, required this.clientId}) : super(key: key);

  @override
  _AddAddressScreenState createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionClienteService = DireccionClienteService();
  final TextEditingController _direccionExactaController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _coloniaController = TextEditingController();
  
  List<Colonia> _colonias = [];
  Colonia? _selectedColonia;
  bool _isLoading = true;
  bool _isSubmitting = false;



  // Map variables
  LatLng _selectedLocation = const LatLng(
    15.5,
    -86.8,
  ); // Default to Honduras center

  @override
  void initState() {
    super.initState();
    _loadColonias();
  }

  Future<void> _loadColonias() async {
    try {
      final colonias = await _direccionClienteService.getColonias();
      setState(() {
        _colonias = colonias;
        // Don't set a default colonia
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error al cargar las colonias: $e');
    }
  }

  Future<void> _showMapModal() async {
    final newLocation = await MapWidget.showAsDialog(
      context: context,
      initialPosition: _selectedLocation,
      title: 'Seleccionar Ubicación',
      confirmButtonText: 'Seleccionar esta ubicación',
    );

    if (newLocation != null) {
      setState(() {
        _selectedLocation = newLocation;
      });
    }
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
        clieId:
            0, // Se actualizará con el ID real del cliente después de crearlo
        coloId: _selectedColonia!.coloId,
        direccionExacta: _direccionExactaController.text.trim(),
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
        depaDescripcion: '',
        muniDescripcion: '',
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Agregar Cliente',
        icon: Icons.add_location,
        onRefresh: () async {
          await _loadColonias();
        },
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back Button
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              size: 20,
                              color: Color(0xFF141A2F),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Text(
                            'Agregar Dirección',
                            style: _titleStyle.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Colonias Dropdown
                      Text(
                        'Colonia *',
                        style: _labelStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: RawAutocomplete<Colonia>(
                                          textEditingController: _coloniaController,
                                          focusNode: FocusNode(),
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return _colonias.take(10);
                                            }
                                            return _colonias.where((colonia) {
                                              final searchValue = textEditingValue.text.toLowerCase();
                                              return colonia.coloDescripcion.toLowerCase().contains(searchValue) ||
                                                  colonia.muniDescripcion.toLowerCase().contains(searchValue) ||
                                                  colonia.depaDescripcion.toLowerCase().contains(searchValue);
                                            });
                                          },
                                          displayStringForOption: (Colonia colonia) => 
                                              '${colonia.coloDescripcion} - ${colonia.muniDescripcion}, ${colonia.depaDescripcion}',
                                          fieldViewBuilder: (
                                            BuildContext context,
                                            TextEditingController textEditingController,
                                            FocusNode focusNode,
                                            VoidCallback onFieldSubmitted,
                                          ) {
                                            // Clear the controller and let the hint text show when no colonia is selected
                                            if (_selectedColonia == null) {
                                              textEditingController.clear();
                                            } else {
                                              textEditingController.text = _selectedColonia!.coloDescripcion;
                                            }
                                            
                                            return TextFormField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              style: _labelStyle,
                                              decoration: InputDecoration(
                                                hintText: 'Buscar colonia...',
                                                hintStyle: _hintStyle,
                                                border: InputBorder.none,
                                                suffixIcon: const Icon(Icons.arrow_drop_down, size: 24),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              // Clear the selection when the text field is tapped
                                              onTap: () {
                                                if (_selectedColonia != null) {
                                                  setState(() {
                                                    _selectedColonia = null;
                                                    textEditingController.clear();
                                                  });
                                                }
                                              },
                                            );
                                          },
                                          optionsViewBuilder: (
                                            BuildContext context,
                                            AutocompleteOnSelected<Colonia> onSelected,
                                            Iterable<Colonia> options,
                                          ) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4.0,
                                                child: Container(
                                                  width: MediaQuery.of(context).size.width * 0.9,
                                                  constraints: const BoxConstraints(maxHeight: 200),
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    itemCount: options.length,
                                                    itemBuilder: (BuildContext context, int index) {
                                                      final Colonia option = options.elementAt(index);
                                                      return InkWell(
                                                        onTap: () {
                                                          onSelected(option);
                                                          setState(() {
                                                            _selectedColonia = option;
                                                          });
                                                        },
                                                        child: _buildOption(context, option),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          onSelected: (Colonia selection) {
                                            setState(() {
                                              _selectedColonia = selection;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedColonia != null) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      '${_selectedColonia!.muniDescripcion}, ${_selectedColonia!.depaDescripcion}',
                                      style: _hintStyle.copyWith(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      const SizedBox(height: 16),

                      // Dirección Exacta
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dirección Exacta *',
                            style: _labelStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _direccionExactaController,
                            style: _labelStyle,
                            decoration: InputDecoration(
                              hintText: 'Ingrese la dirección exacta',
                              hintStyle: _hintStyle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor ingrese la dirección exacta';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Observaciones
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observaciones',
                            style: _labelStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _observacionesController,
                            style: _labelStyle,
                            decoration: InputDecoration(
                              hintText: 'Ingrese observaciones adicionales',
                              hintStyle: _hintStyle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Mapa
                      Text(
                        'Seleccione la ubicación en el mapa:',
                        style: _labelStyle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ubicación actual:',
                              style: _labelStyle.copyWith(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                              style: _labelStyle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showMapModal,
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('Seleccionar en el mapa'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // This is what will be shown in the autocomplete overlay
  static Widget _buildOption(BuildContext context, Colonia colonia) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            colonia.coloDescripcion,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${colonia.muniDescripcion}, ${colonia.depaDescripcion}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _direccionExactaController.dispose();
    _observacionesController.dispose();
    _coloniaController.dispose();
    super.dispose();
  }
}
