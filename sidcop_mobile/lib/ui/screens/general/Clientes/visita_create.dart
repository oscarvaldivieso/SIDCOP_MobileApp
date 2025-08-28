import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.Dart';
import 'package:sidcop_mobile/models/ClientesVisitaHistorialModel.dart';

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
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
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

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageBytes = _selectedImage!.readAsBytesSync();
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar la imagen: $e');
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _selectedImageBytes = _selectedImage!.readAsBytesSync();
        });
      }
    } catch (e) {
      _mostrarError('Error al tomar la foto: $e');
    }
  }

  void _eliminarImagen() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCliente == null ||
        _selectedDireccion == null ||
        _selectedEstadoVisita == null) {
      _mostrarError('Por favor complete todos los campos obligatorios');
      return;
    }

    if (_selectedImage == null) {
      _mostrarError('Debe subir al menos una imagen de la visita');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Convertir la imagen a base64
      final imagenBytes = await _selectedImage!.readAsBytes();
      final imagenBase64 = base64Encode(imagenBytes);

      // Crear la visita
      final resultado = await _visitaService.crearVisitaConImagenes(
        diClId: _selectedDireccion!['diCl_Id'],
        veRuId: _selectedCliente!['veRu_Id'],
        clieId: _selectedCliente!['clie_Id'],
        esViId: _selectedEstadoVisita!['esVi_Id'],
        clViObservaciones: _observacionesController.text,
        clViFecha: _selectedDate!,
        imagenesBase64: [imagenBase64],
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Retornar éxito
      }
    } catch (e) {
      _mostrarError('Error al guardar la visita: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                    _selectedImage == null
                        ? Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _seleccionarImagen,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galería'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _tomarFoto,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Cámara'),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                  image: DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                    onPressed: _eliminarImagen,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    
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