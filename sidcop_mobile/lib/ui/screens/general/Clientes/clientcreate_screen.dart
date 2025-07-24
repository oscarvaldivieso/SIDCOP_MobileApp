import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/ui/widgets/custom_input.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';

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
  
  // Form controllers
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _dniController = TextEditingController();
  final _nombreNegocioController = TextEditingController();
  
  void _agregarUbicacion() {
    // Placeholder for location functionality
    // Will be implemented later
  }

  Future<void> _submitForm() async {
    // Log form data to browser console
    print('=== CLIENT CREATION STARTED ===');
    print('Form data:');
    print('Nombres: ${_nombresController.text}');
    print('Apellidos: ${_apellidosController.text}');
    print('Identidad: ${_dniController.text}');
    print('Negocio: ${_nombreNegocioController.text}');
    
    if (!_formKey.currentState!.validate()) {
      final error = 'Form validation failed';
      print('❌ $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    if (_isSubmitting) {
      print('⚠️ Form submission already in progress');
      return;
    }
    
    setState(() => _isSubmitting = true);
    print('🔄 Submitting form...');

    try {
      final now = DateTime.now().toIso8601String();
      final clienteData = {
        'clie_Codigo': 'CLIE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 10)}${DateTime.now().second % 10}',  // Last 3 digits of timestamp + random digit
        'clie_DNI': _dniController.text.trim(),
        'clie_RTN': 'Pendiente',
        'clie_Nombres': _nombresController.text.trim(),
        'clie_Apellidos': _apellidosController.text.trim(),
        'clie_NombreNegocio': _nombreNegocioController.text.trim(),
        'clie_ImagenDelNegocio': '',
        'clie_Telefono': 'Pendiente',
        'clie_Correo': 'Pendiente@gmail.com',
        'clie_Sexo': 'M',
        'clie_FechaNacimiento': now,
        'cana_Id': 1,
        'esCv_Id': 1,
        'ruta_Id': 3,
        'clie_LimiteCredito': 0,
        'clie_DiasCredito': 0,
        'clie_Saldo': 0,
        'clie_Vencido': false,
        'clie_Observaciones': 'Pendiente',
        'clie_ObservacionRetiro': 'Pendiente',
        'clie_Confirmacion': false,
        'TiVi_Id': 1,  // Default value as requested
        'Clie_Nacionalidad': 'pdt',  // Default value as requested
        'usua_Creacion': 1,
        'clie_FechaCreacion': now,
        'clie_Estado': true,
      };

      Map<String, dynamic> finalClienteData = Map<String, dynamic>.from(clienteData);
      
      try {
        // Upload image to Cloudinary if one was selected
        if (_selectedImage != null || _selectedImageBytes != null) {
          final cloudinaryService = CloudinaryService();
          final imageUrl = kIsWeb 
              ? await cloudinaryService.uploadImageFromBytes(_selectedImageBytes!)
              : await cloudinaryService.uploadImage(_selectedImage!);
          if (imageUrl != null) {
            finalClienteData['clie_ImagenDelNegocio'] = imageUrl;
            print('✅ Imagen subida correctamente a Cloudinary: $imageUrl');
          } else {
            print('⚠️ No se pudo subir la imagen a Cloudinary');
          }
        }
        
        // Log the complete request payload
        print('📤 Sending request to API:');
        print('URL: https://localhost:7071/Cliente/Insertar');
        print('Headers: {accept: */*, X-Api-Key: bdccf3f3-d486-4e1e-ab44-74081aefcdbc, Content-Type: application/json}');
        print('Body:');
        final jsonBody = JsonEncoder.withIndent('  ').convert(finalClienteData);
        print(jsonBody);

        final response = await _dropdownService.insertCliente(finalClienteData);
        
        // Debug: Print the complete response
        print('📥 API Response:');
        print(response.toString());
        
        if (response['success'] == true) {
          final responseData = response['data'];
          if (responseData != null && responseData['code_Status'] == 1) {
            print('✅ Cliente creado exitosamente');
            if (mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(responseData['message_Status'] ?? 'Cliente creado exitosamente')),
              );
            }
          } else {
            throw Exception(responseData?['message_Status'] ?? 'Error al crear el cliente');
          }
        } else {
          throw Exception(response['message'] ?? 'Error en la respuesta del servidor');
        }
      } catch (e, stackTrace) {
        print('❌ Error en _submitForm:');
        print('🔴 Error: $e');
        print('🔍 Stack trace: $stackTrace');
        
        if (mounted) {
          final errorMessage = 'Error al crear el cliente: ${e.toString()}';
          print('💬 Mostrando error al usuario: $errorMessage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      print('🏁 Form submission completed');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, String? hint, {bool isRequired = false, TextInputType keyboardType = TextInputType.text}) {
    return CustomInput(
      label: '$label${isRequired ? ' *' : ''}',
      hint: hint,
      controller: controller,
      keyboardType: keyboardType,
      errorText: isRequired && controller.text.isEmpty && (_formKey.currentState?.validate() ?? false)
          ? 'Este campo es requerido' 
          : null,
    );
  }

  Widget _buildLocationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: InkWell(
        onTap: _agregarUbicacion,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_location_alt, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                'Agregar Ubicación',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al seleccionar la imagen')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Nuevo Cliente',
      icon: Icons.person_add,
      child: SingleChildScrollView(
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
              _buildTextField('Nombres', _nombresController, 'Ingrese los nombres', isRequired: true),
              
              // Apellidos
              _buildTextField('Apellidos', _apellidosController, 'Ingrese los apellidos', isRequired: true),
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
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
              const SizedBox(height: 16),  
              // Identidad
              _buildTextField('Identidad', _dniController, 'Ej: 0501-2009-2452', isRequired: true, keyboardType: TextInputType.number),
              
              // Nombre del Negocio
              _buildTextField('Nombre del Negocio', _nombreNegocioController, 'Ingrese el nombre del negocio', isRequired: true),
              
              // Agregar Ubicación Button
              _buildLocationButton(),
              
              // Submit Button
              const SizedBox(height: 24),
              CustomButton(
                text: 'Guardar Cliente',
                onPressed: _isSubmitting ? null : _submitForm,
                width: double.infinity,
              ),
              if (_isSubmitting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dniController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _nombreNegocioController.dispose();
    super.dispose();
  }
}