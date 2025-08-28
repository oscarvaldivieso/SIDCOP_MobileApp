import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/models/ClientesVisitaHistorialModel.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.Dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';

class VisitaCreateScreen extends StatefulWidget {
  const VisitaCreateScreen({Key? key}) : super(key: key);

  @override
  _VisitaCreateScreenState createState() => _VisitaCreateScreenState();
}

class _VisitaCreateScreenState extends State<VisitaCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fechaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ClientesVisitaHistorialService _visitaService = ClientesVisitaHistorialService();
  
  DateTime? _selectedDate;
  List<File> _selectedImages = [];
  List<Uint8List> _selectedImagesBytes = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Datos para los dropdowns
  List<Map<String, dynamic>> _estadosVisita = [];
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _direcciones = [];
  
  // Valores seleccionados
  Map<String, dynamic>? _selectedCliente;
  Map<String, dynamic>? _selectedDireccion;
  Map<String, dynamic>? _selectedEstadoVisita;

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDate = DateTime.now();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar estados de visita
      _estadosVisita = await _visitaService.obtenerEstadosVisita();
      
      // Cargar clientes del vendedor actual
      _clientes = await _visitaService.obtenerClientesPorVendedor();
      
      // Si solo hay un cliente, seleccionarlo automáticamente
      if (_clientes.length == 1) {
        _selectedCliente = _clientes.first;
        await _cargarDireccionesCliente(_selectedCliente!['clie_Id']);
      }
    } catch (e) {
      _mostrarError('Error al cargar datos iniciales: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarDireccionesCliente(int clienteId) async {
    setState(() {
      _isLoading = true;
      _selectedDireccion = null;
    });

    try {
      _direcciones = await _visitaService.obtenerDireccionesPorCliente(clienteId);
      
      // Si solo hay una dirección, seleccionarla automáticamente
      if (_direcciones.length == 1) {
        _selectedDireccion = _direcciones.first;
      }
    } catch (e) {
      _mostrarError('Error al cargar direcciones: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await ImagePicker().pickMultiImage(
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImages.add(File(image.path));
            _selectedImagesBytes.add(bytes);
          });
        }
      }
    } catch (e) {
      _mostrarError('Error al seleccionar imágenes: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedImages.add(File(photo.path));
          _selectedImagesBytes.add(bytes);
        });
      }
    } catch (e) {
      _mostrarError('Error al tomar la foto: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImagesBytes.removeAt(index);
    });
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería de fotos'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) {
      return GestureDetector(
        onTap: _showImageSourceDialog,
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Agregar imágenes de la visita', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón para agregar más imágenes
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate, color: Colors.blue),
            label: const Text('Agregar más imágenes'),
          ),
        ),
        
        // Grid de imágenes
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _selectedImages.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: kIsWeb 
                          ? Image.memory(_selectedImagesBytes[index]).image 
                          : FileImage(_selectedImages[index]) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _fechaController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCliente == null || 
        _selectedDireccion == null || 
        _selectedEstadoVisita == null) {
      _mostrarError('Por favor complete todos los campos obligatorios');
      return;
    }

    if (_selectedImages.isEmpty) {
      _mostrarError('Debe subir al menos una imagen');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Preparar datos de la visita
      final now = DateTime.now();
      final visitaData = {
        'clVi_Id': 0,
        'diCl_Id': _selectedDireccion?['diCl_Id'] ?? 0,
        'diCl_Latitud': 0,
        'diCl_Longitud': 0,
        'vend_Id': 0,
        'vend_Codigo': '',
        'vend_DNI': '',
        'vend_Nombres': '',
        'vend_Apellidos': '',
        'vend_Telefono': '',
        'vend_Tipo': '',
        'vend_Imagen': '',
        'ruta_Id':0,
        'ruta_Descripcion': '',
        'veRu_Id': _selectedCliente?['veRu_Id'],
        'veRu_Dias': '',
        'clie_Id': _selectedCliente?['clie_Id'],
        'clie_Codigo': _selectedCliente?['clie_Codigo'],
        'clie_Nombres': _selectedCliente?['clie_Nombres'],
        'clie_Apellidos': _selectedCliente?['clie_Apellidos'],
        'clie_NombreNegocio': _selectedCliente?['clie_NombreNegocio'],
        'clie_Telefono': _selectedCliente?['clie_Telefono'],
        'imVi_Imagen': '',
        'esVi_Id': _selectedEstadoVisita?['esVi_Id'] ,
        'esVi_Descripcion': '',
        'clVi_Observaciones': _observacionesController.text,
        'clVi_Fecha': _selectedDate?.toIso8601String() ?? now.toIso8601String(),
        'usua_Creacion': 57,
        'clVi_FechaCreacion': now.toIso8601String(),
      };

      // 2. Insertar la visita
      await _visitaService.insertarVisita(visitaData);

      // 3. Obtener la última visita creada
      final ultimaVisita = await _visitaService.obtenerUltimaVisita();
      if (ultimaVisita == null || ultimaVisita['clVi_Id'] == null) {
        throw Exception('No se pudo obtener el ID de la visita creada');
      }

      final visitaId = ultimaVisita['clVi_Id'] as int;

      // 4. Subir imágenes a Cloudinary y asociarlas
      for (final image in _selectedImages) {
        try {
          // Subir a Cloudinary
          final cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dbt7mxrwk/upload';
          final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
          final bytes = await image.readAsBytes();
          
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'visita_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ));
          request.fields['upload_preset'] = 'empleados';

          final cloudinaryResponse = await request.send();
          if (cloudinaryResponse.statusCode == 200) {
            final responseData = await cloudinaryResponse.stream.bytesToString();
            final jsonResponse = jsonDecode(responseData);
            final imageUrl = jsonResponse['secure_url'] as String?;

            if (imageUrl != null) {
              await _visitaService.asociarImagenAVisita(
                visitaId: visitaId,
                imagenUrl: imageUrl,
                usuarioId: globalVendId!,
              );
            }
          }
        } catch (e) {
          debugPrint('Error al subir imagen: $e');
        }
      }

      // Éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _mostrarError('Error al guardar la visita: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<int> _getUserId() async {
    // Implementa la lógica para obtener el ID del usuario actual
    // Por ejemplo, desde SharedPreferences o tu servicio de autenticación
    return 1; // Reemplaza con la lógica real
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    try {
      final cloudinaryService = CloudinaryService();
      if (kIsWeb) {
        return await cloudinaryService.uploadImageFromBytes(imageBytes);
      } else {
        // Crear archivo temporal para subir
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(imageBytes);
        return await cloudinaryService.uploadImage(file);
      }
    } catch (e) {
      debugPrint('Error al subir imagen a Cloudinary: $e');
      return null;
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Visita'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown de Cliente
                    const Text('Cliente *', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedCliente,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _clientes.map((cliente) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: cliente,
                          child: Text(
                            '${cliente['clie_Nombres']} ${cliente['clie_Apellidos']} - ${cliente['clie_NombreNegocio']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _selectedCliente = value;
                            _selectedDireccion = null;
                          });
                          await _cargarDireccionesCliente(value['clie_Id']);
                        }
                      },
                      validator: (value) => value == null ? 'Seleccione un cliente' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dropdown de Dirección
                    const Text('Dirección *', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedDireccion,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _direcciones.map((direccion) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: direccion,
                          child: Text(
                            '${direccion['diCl_DireccionExacta']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDireccion = value;
                        });
                      },
                      validator: (value) => value == null ? 'Seleccione una dirección' : null,
                      isExpanded: true,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dropdown de Estado de Visita
                    const Text('Estado de la Visita *', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedEstadoVisita,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _estadosVisita.map((estado) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: estado,
                          child: Text(estado['esVi_Descripcion'] ?? 'Sin estado'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEstadoVisita = value;
                        });
                      },
                      validator: (value) => value == null ? 'Seleccione un estado' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Fecha de Visita
                    TextFormField(
                      controller: _fechaController,
                      decoration: InputDecoration(
                        labelText: 'Fecha de Visita *',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) => value?.isEmpty ?? true ? 'Seleccione una fecha' : null,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Observaciones
                    TextFormField(
                      controller: _observacionesController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sección de Imagen
                    const Text('Imagen de la Visita *', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildImageGrid(),
                    
                    const SizedBox(height: 24),
                    
                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('GUARDAR VISITA'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
}