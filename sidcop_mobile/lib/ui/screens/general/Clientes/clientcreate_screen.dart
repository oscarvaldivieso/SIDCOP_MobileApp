import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/add_address_screen.dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/ui/widgets/custom_input.dart';
import 'package:flutter/services.dart';

class ClientCreateScreen extends StatefulWidget {
  const ClientCreateScreen({Key? key}) : super(key: key);

  @override
  _ClientCreateScreenState createState() => _ClientCreateScreenState();
}

class _ClientCreateScreenState extends State<ClientCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  final DropdownDataService _dropdownService = DropdownDataService();
  final DireccionClienteService _direccionClienteService = DireccionClienteService();
  
  // Form controllers
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _dniController = TextEditingController();
  final _nombreNegocioController = TextEditingController();
  final List<DireccionCliente> _direcciones = [];

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _dniController.dispose();
    _nombreNegocioController.dispose();
    super.dispose();
  }

  Future<void> _agregarUbicacion() async {
    final direccion = await Navigator.push<DireccionCliente>(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressScreen(
          clientId: 0, // Will be updated after client creation
        ),
      ),
    );

    if (direccion != null) {
      setState(() {
        _direcciones.add(direccion);
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección agregada exitosamente')),
      );
    }
  }

  void _removeAddress(int index) {
    setState(() {
      _direcciones.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos requeridos')),
      );
      return;
    }

    // Check if there's at least one address
    if (_direcciones.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin direcciones'),
          content: const Text('¿Desea continuar sin agregar una dirección al cliente?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }
    }

    if (!mounted) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      String? imageUrl;
      
      // 1. Upload image if exists
      if (_selectedImage != null || _selectedImageBytes != null) {
        try {
          imageUrl = await _uploadImage();
          if (imageUrl == null) {
            throw Exception('No se pudo subir la imagen');
          }
        } catch (e) {
          print('Error al subir la imagen: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al subir la imagen. Continuando sin imagen...'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // 2. Prepare and insert client
      final clienteData = {
        'clie_Codigo': 'CLI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'clie_Nombres': _nombresController.text.trim(),
        'clie_Apellidos': _apellidosController.text.trim(),
        'clie_DNI': _dniController.text.trim(),
        'clie_RTN': 'RTN-${_dniController.text.trim()}',
        'clie_NombreNegocio': _nombreNegocioController.text.trim(),
        'clie_ImagenDelNegocio': imageUrl ?? '',
        'clie_Telefono': '0000-0000', // Default value, can be updated later
        'clie_Correo': '${_nombresController.text.trim().toLowerCase()}.${_apellidosController.text.trim().toLowerCase()}@example.com',
        'clie_Sexo': 'M', // Default value
        'clie_FechaNacimiento': DateTime(1990, 1, 1).toIso8601String(), // Default value
        'cana_Id': 1, // Default value
        'esCv_Id': 1, // Default value
        'ruta_Id': 1, // Default value, should be selected from UI
        'clie_LimiteCredito': 0, // Default value
        'clie_DiasCredito': 0, // Default value
        'clie_Saldo': 0, // Default value
        'clie_Vencido': false, // Default value
        'clie_Observaciones': 'Cliente creado desde la app móvil',
        'clie_ObservacionRetiro': 'Ninguna',
        'clie_Confirmacion': false,
        'TiVi_Id': 1, // Default value
        'Clie_Nacionalidad': 'HND', // Default value
        'usua_Creacion': 1, // TODO: Replace with actual user ID
        'clie_FechaCreacion': DateTime.now().toIso8601String(),
        'clie_Estado': true,
      };

      print('Enviando datos del cliente: $clienteData');
      
      // 3. Insert client
      final response = await _dropdownService.insertCliente(clienteData);
      print('Respuesta del servidor: $response');
      
      if (response['success'] != true) {
        throw Exception('Error al crear el cliente: ${response['message'] ?? 'Error desconocido'}');
      }

      // Extract client ID from the nested response
      final clientData = response['data'];
      if (clientData == null || clientData['data'] == null) {
        throw Exception('No se recibió un ID de cliente válido del servidor');
      }
      
      // Parse client ID whether it comes as String or int
      final clientId = clientData['data'] is String 
          ? int.tryParse(clientData['data']) 
          : (clientData['data'] as num?)?.toInt();
          
      if (clientId == null) {
        throw Exception('Formato de ID de cliente inválido: ${clientData['data']}');
      }
      
      print('Client ID extraído: $clientId (${clientId.runtimeType})');
      
      // 4. Insert all addresses with the new client ID
      if (_direcciones.isNotEmpty) {
        int successfulAddresses = 0;
        
        for (var direccion in _direcciones) {
          try {
            // Actualizar el ID del cliente en cada dirección
            final direccionData = direccion.copyWith(clieId: clientId);
            
            print('=== Enviando dirección para cliente $clientId ===');
            print('Datos completos: ${direccionData.toJson()}');
            
            final result = await _direccionClienteService.insertDireccionCliente(direccionData);
            
            print('Respuesta del servidor para dirección: $result');
            
            if (result['success'] == true) {
              successfulAddresses++;
              print('✅ Dirección guardada exitosamente');
            } else {
              print('❌ Error al guardar dirección: ${result['message']}');
            }
          } catch (e) {
            print('Excepción al guardar dirección: $e');
          }
        }
        
        if (successfulAddresses < _direcciones.length) {
          // Show warning if not all addresses were saved
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cliente creado, pero algunas direcciones no se guardaron correctamente ($successfulAddresses/${_direcciones.length} guardadas)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      // 5. Show success message and return to previous screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error en _submitForm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el cliente: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Uint8List> _getImageBytes() async {
    if (kIsWeb) {
      return _selectedImageBytes!;
    } else {
      return await _selectedImage!.readAsBytes();
    }
  }

  Future<String?> _uploadImage() async {
    try {
      final cloudinaryService = CloudinaryService();
      final imageBytes = await _getImageBytes();
      return kIsWeb 
        ? await cloudinaryService.uploadImageFromBytes(imageBytes)
        : await cloudinaryService.uploadImage(_selectedImage!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen')),
        );
      }
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Reduce image quality for faster uploads
        maxWidth: 1200,   // Limit image dimensions
        maxHeight: 1200,
      );
      
      if (image == null || !mounted) return;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('La imagen seleccionada está vacía');
        }
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null; // Clear any previous file reference
        });
      } else {
        final file = File(image.path);
        if (!await file.exists()) {
          throw Exception('No se pudo acceder al archivo de la imagen');
        }
        setState(() {
          _selectedImage = file;
          _selectedImageBytes = null; // Clear any previous bytes
        });
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen seleccionada exitosamente')),
        );
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar la imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomInput(
        label: '$label${isRequired ? ' *' : ''}',
        hint: hint,
        controller: controller,
        keyboardType: keyboardType,
        errorText: validator?.call(controller.text) == null ? null : validator!(controller.text),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Direcciones del Cliente',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._direcciones.asMap().entries.map((entry) {
          final index = entry.key;
          final direccion = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF141A2F)),
              title: Text(
                direccion.direccionExacta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                direccion.observaciones ?? 'Sin observaciones',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeAddress(index),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        CustomButton(
          text: 'Agregar Dirección',
          onPressed: _agregarUbicacion,
          icon: const Icon(Icons.add_location, color: Colors.white),
        ),
        if (_direcciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No se han agregado direcciones',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Information Section
              const Text(
                'Información Básica',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Nombres
              _buildTextField(
                label: 'Nombres',
                controller: _nombresController,
                hint: 'Ingrese los nombres',
                isRequired: true,
              ),
              
              // Apellidos
              _buildTextField(
                label: 'Apellidos',
                controller: _apellidosController,
                hint: 'Ingrese los apellidos',
                isRequired: true,
              ),
              
              // Identidad
              _buildTextField(
                label: 'Identidad',
                controller: _dniController,
                hint: 'Ej: 0501-2009-2452',
                isRequired: true,
                keyboardType: TextInputType.number,
              ),
              
              // Nombre del Negocio
              _buildTextField(
                label: 'Nombre del Negocio',
                controller: _nombreNegocioController,
                hint: 'Ingrese el nombre del negocio',
                isRequired: true,
              ),
              
              const SizedBox(height: 16),
              
              // Image Picker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Imagen del Negocio',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImage != null || _selectedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Toca para seleccionar una imagen')
                              ],
                            ),
                    ),
                  ),
                  if (_selectedImage != null || _selectedImageBytes != null) ...[  
                    const SizedBox(height: 8),
                    Text(
                      'Imagen seleccionada: ${kIsWeb ? 'Imagen web' : _selectedImage!.path.split('/').last}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              
              // Agregar Ubicación Button
              _buildLocationButton(),
              
              // Submit Button
              const SizedBox(height: 24),
              CustomButton(
                text: 'Guardar Cliente',
                onPressed: _isSubmitting ? null : _submitForm,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }


}