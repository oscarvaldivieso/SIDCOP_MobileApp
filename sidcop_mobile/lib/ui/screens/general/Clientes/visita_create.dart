import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.Dart';
// Removed unused imports: provider, ClientesVisitaHistorialModel, cloudinary_service
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
import 'package:sidcop_mobile/services/GlobalService.Dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

final TextStyle _titleStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

// Text style constants for consistent typography
final TextStyle _labelStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

final TextStyle _hintStyle = const TextStyle(
  fontFamily: 'Satoshi',
  color: Colors.grey,
);

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
  final ClientesVisitaHistorialService _visitaService =
      ClientesVisitaHistorialService();

  DateTime? _selectedDate;
  List<File> _selectedImages = [];
  List<Uint8List> _selectedImagesBytes = [];
  bool _isLoading = false;
  // submission state handled inline; removed unused _isSubmitting
  // if the screen was opened with route arguments, store them to apply after data loads
  Map<String, dynamic>? _initialRouteArgs;

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
    // Capture any incoming route arguments after the first frame and then load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _initialRouteArgs = args;
      }
      // Now load initial data (clients/states/directions). This ensures
      // _initialRouteArgs is available for preselection inside _cargarDatosIniciales.
      _cargarDatosIniciales();
    });
  }

  /// Ping sencillo a Google para verificar conectividad de red.
  /// Devuelve true si Google responde en tiempo razonable.
  Future<bool> _verificarConexion() async {
    try {
      final resp = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar conectividad consultando Google. Si responde usamos endpoints remotos,
      // si no, caemos a los datos guardados por el Offline Service.
      final online = await _verificarConexion();

      if (online) {
        // Cargar estados de visita (remoto)
        _estadosVisita = await _visitaService.obtenerEstadosVisita();

        // Cargar clientes del vendedor actual (remoto)
        _clientes = await _visitaService.obtenerClientesPorVendedor();

        // Si solo hay un cliente, seleccionarlo automáticamente
        if (_clientes.length == 1) {
          _selectedCliente = _clientes.first;
          await _cargarDireccionesCliente(_selectedCliente!['clie_Id']);
        } else if (_initialRouteArgs != null &&
            _initialRouteArgs!['clienteId'] != null &&
            _initialRouteArgs!['rutaId'] != null) {
          // If the screen was opened with a clienteId, try to preselect it
          try {
            final cidNum = _initialRouteArgs!['clienteId'] as num?;
            final cid = cidNum?.toInt();
            if (cid != null) {
              _selectedCliente = _clientes.firstWhere(
                (c) => (c['clie_Id'] as num?)?.toInt() == cid,
              );
              // load addresses and try to preselect a direccion if provided
              await _cargarDireccionesCliente(
                _selectedCliente!['clie_Id'],
                selectDiclId: (_initialRouteArgs!['diclId'] as num?)?.toInt(),
              );
            }
          } catch (_) {
            // ignore failures and continue
          }
        }
      } else {
        // Offline: leer datos locales desde VisitasOffline
        final clientesLocal = await VisitasOffline.obtenerClientesLocal();
        final direccionesLocal = await VisitasOffline.obtenerDireccionesLocal();
        final estadosLocal = await VisitasOffline.obtenerEstadosVisitaLocal();

        _estadosVisita = estadosLocal;
        _clientes = clientesLocal;

        // Si sólo hay un cliente, seleccionar y buscar sus direcciones en el cache local
        if (_clientes.length == 1) {
          _selectedCliente = _clientes.first;
          _direcciones = direccionesLocal
              .where((d) {
                final cidA = d is Map ? (d['clie_Id'] ?? d['clie_id']) : null;
                return cidA != null && cidA == _selectedCliente!['clie_Id'];
              })
              .map(
                (e) => e is Map
                    ? e as Map<String, dynamic>
                    : Map<String, dynamic>.from(e as Map),
              )
              .toList();
          if (_direcciones.length == 1) _selectedDireccion = _direcciones.first;
        } else if (_initialRouteArgs != null &&
            _initialRouteArgs!['clienteId'] != null &&
            _initialRouteArgs!['rutaId'] != null) {
          try {
            final cidNum = _initialRouteArgs!['clienteId'] as num?;
            final cid = cidNum?.toInt();
            if (cid != null) {
              _selectedCliente = _clientes.firstWhere(
                (c) => (c['clie_Id'] as num?)?.toInt() == cid,
              );
              // filtrar direcciones locales
              _direcciones = direccionesLocal
                  .where((d) {
                    final cidA = d is Map
                        ? (d['clie_Id'] ?? d['clie_id'])
                        : null;
                    return cidA != null && cidA == _selectedCliente!['clie_Id'];
                  })
                  .map(
                    (e) => e is Map
                        ? e as Map<String, dynamic>
                        : Map<String, dynamic>.from(e as Map),
                  )
                  .toList();
              final selectDicl = (_initialRouteArgs!['diclId'] as num?)
                  ?.toInt();
              if (selectDicl != null) {
                try {
                  _selectedDireccion = _direcciones.firstWhere(
                    (d) => (d['diCl_Id'] as num?)?.toInt() == selectDicl,
                  );
                } catch (_) {
                  _selectedDireccion = null;
                }
              }
            }
          } catch (_) {}
        }
      }
      // Fallbacks: si por alguna razón la carga remota devolvió vacíos, intentar usar cache local
      if (_estadosVisita.isEmpty) {
        try {
          final estadosLocal = await VisitasOffline.obtenerEstadosVisitaLocal();
          if (estadosLocal.isNotEmpty) _estadosVisita = estadosLocal;
        } catch (_) {}
      }
      if (_clientes.isEmpty) {
        try {
          final clientesLocal = await VisitasOffline.obtenerClientesLocal();
          if (clientesLocal.isNotEmpty) _clientes = clientesLocal;
        } catch (_) {}
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

  Future<void> _cargarDireccionesCliente(
    int clienteId, {
    int? selectDiclId,
  }) async {
    setState(() {
      _isLoading = true;
      _selectedDireccion = null;
    });

    try {
      // Verificar conexión para decidir si usamos el servicio remoto o el cache local
      final online = await _verificarConexion();
      if (online) {
        _direcciones = await _visitaService.obtenerDireccionesPorCliente(
          clienteId,
        );
        // Guardar en cache local para uso offline
        try {
          await VisitasOffline.guardarDirecciones(_direcciones);
        } catch (_) {}
      } else {
        final todas = await VisitasOffline.obtenerDireccionesLocal();
        _direcciones = todas
            .where((d) {
              final cidA = d is Map ? (d['clie_Id'] ?? d['clie_id']) : null;
              return cidA != null && cidA == clienteId;
            })
            .map(
              (e) => e is Map
                  ? e as Map<String, dynamic>
                  : Map<String, dynamic>.from(e as Map),
            )
            .toList();
      }

      // If a specific direccion id was requested, try to select it
      if (selectDiclId != null) {
        try {
          _selectedDireccion = _direcciones.firstWhere(
            (d) => (d['diCl_Id'] as num?)?.toInt() == selectDiclId,
          );
        } catch (_) {
          _selectedDireccion = null;
        }
      }

      // Si solo hay una dirección, seleccionarla automáticamente
      if (_selectedDireccion == null && _direcciones.length == 1) {
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
      final List<XFile>? images = await _picker.pickMultiImage(
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
      final XFile? photo = await _picker.pickImage(
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

  Widget _buildImageField() {
    final hasImages = _selectedImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasImages
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(
                            _selectedImagesBytes.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.file(
                            _selectedImages.first,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Toca para seleccionar una imagen',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
          ),
        ),

        if (hasImages) ...[
          const SizedBox(height: 8),
          Text(
            'Imágenes seleccionadas (${_selectedImages.length}):',
            style: _hintStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),

          // Miniaturas de imágenes
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.memory(
                                _selectedImagesBytes[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                _selectedImages[index],
                                width: 80,
                                height: 80,
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
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.blue),
              label: const Text('Agregar más imágenes'),
            ),
          ),
        ],
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

    setState(() => _isLoading = true);

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
        'ruta_Id': 0,
        'ruta_Descripcion': '',
        'veRu_Id': _selectedCliente?['veRu_Id'] ?? 0,
        'veRu_Dias': '',
        'clie_Id': _selectedCliente?['clie_Id'] ?? 0,
        'clie_Codigo': _selectedCliente?['clie_Codigo'] ?? '',
        'clie_Nombres': _selectedCliente?['clie_Nombres'] ?? '',
        'clie_Apellidos': _selectedCliente?['clie_Apellidos'] ?? '',
        'clie_NombreNegocio': _selectedCliente?['clie_NombreNegocio'] ?? '',
        'clie_Telefono': _selectedCliente?['clie_Telefono'] ?? '',
        'imVi_Imagen': '',
        'esVi_Id': _selectedEstadoVisita?['esVi_Id'] ?? 0,
        'esVi_Descripcion': _selectedEstadoVisita?['esVi_Descripcion'] ?? '',
        'clVi_Observaciones': _observacionesController.text.isNotEmpty
            ? _observacionesController.text
            : '',
        'clVi_Fecha': _selectedDate?.toIso8601String() ?? now.toIso8601String(),
        'usua_Creacion': 57,
        'clVi_FechaCreacion': now.toIso8601String(),
      };

      // Verificar si estamos online
      final online = await _verificarConexion();
      if (!online) {
        // Guardar la visita localmente (incluyendo imágenes en base64) para sincronizar después
        final List<String> imagenesBase64 = [];
        for (final bytes in _selectedImagesBytes) {
          try {
            imagenesBase64.add(base64Encode(bytes));
          } catch (_) {}
        }

        final visitaLocal = {
          ...visitaData,
          'imagenesBase64': imagenesBase64,
          'offline': true,
        };

        final bool added = await VisitasOffline.agregarVisitaLocal(visitaLocal);

        if (mounted) {
          if (added) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Visita guardada en modo offline'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Visita duplicada detectada. No se guardó nuevamente.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          Navigator.of(context).pop(true);
        }

        return;
      }

      // Online: proceder a insertar en remoto
      // 2. Insertar la visita
      await _visitaService.insertarVisita(visitaData);

      // 3. Obtener la última visita creada
      final ultimaVisita = await _visitaService.obtenerUltimaVisita();
      if (ultimaVisita == null || ultimaVisita['clVi_Id'] == null) {
        throw Exception('No se pudo obtener el ID de la visita creada');
      }

      final visitaId = ultimaVisita['clVi_Id'] as int;

      // 4. Subir imágenes al servidor y asociarlas a la visita
      for (final image in _selectedImages) {
        try {
          // 4.1 Subir la imagen al endpoint /Imagen/Subir
          final uploadUrl = Uri.parse('$apiServer/Imagen/Subir');
          var request = http.MultipartRequest('POST', uploadUrl);

          // Agregar la imagen al request
          request.files.add(
            await http.MultipartFile.fromPath('imagen', image.path),
          );

          // Agregar headers
          request.headers['X-Api-Key'] = apikey;
          request.headers['accept'] = '*/*';

          // Enviar la solicitud
          final uploadResponse = await request.send();
          final responseData = await uploadResponse.stream.bytesToString();

          if (uploadResponse.statusCode == 200) {
            final uploadData = jsonDecode(responseData) as Map<String, dynamic>;
            final String rutaImagen = uploadData['ruta'];

            print('rutaImagen: $rutaImagen');
            // 4.2 Asociar la imagen a la visita usando /ImagenVisita/Insertar
            await _visitaService.asociarImagenAVisita(
              visitaId: visitaId,
              imagenUrl: rutaImagen,
              usuarioId: 57,
            );
          } else {
            throw Exception(
              'Error al subir imagen: ${uploadResponse.statusCode} - $responseData',
            );
          }
        } catch (e) {
          debugPrint('Error al procesar imagen: $e');
          // Continuar con las demás imágenes si hay un error
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
        setState(() => _isLoading = false);
      }
    }
  }

  // Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
  //   try {
  //     final cloudinaryService = CloudinaryService();
  //     if (kIsWeb) {
  //       return await cloudinaryService.uploadImageFromBytes(imageBytes);
  //     } else {
  //       // Crear archivo temporal para subir
  //       final tempDir = await getTemporaryDirectory();
  //       final file = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
  //       await file.writeAsBytes(imageBytes);
  //       return await cloudinaryService.uploadImage(file);
  //     }
  //   } catch (e) {
  //     debugPrint('Error al subir imagen a Cloudinary: $e');
  //     return null;
  //   }
  // }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Nueva Visita',
      icon: Icons.location_history,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          'Regresar',
                          style: _titleStyle.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                    // Dropdown de Cliente
                    Text(
                      'Cliente *',
                      style: _labelStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    RawAutocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _clientes;
                        }
                        final searchValue = textEditingValue.text.toLowerCase();
                        return _clientes.where((cliente) {
                          return (cliente['clie_Nombres']
                                      ?.toLowerCase()
                                      .contains(searchValue) ??
                                  false) ||
                              (cliente['clie_Apellidos']
                                      ?.toLowerCase()
                                      .contains(searchValue) ??
                                  false) ||
                              (cliente['clie_NombreNegocio']
                                      ?.toLowerCase()
                                      .contains(searchValue) ??
                                  false) ||
                              (cliente['clie_Codigo']?.toLowerCase().contains(
                                    searchValue,
                                  ) ??
                                  false);
                        });
                      },
                      displayStringForOption: (Map<String, dynamic> cliente) =>
                          '${cliente['clie_Nombres']} ${cliente['clie_Apellidos']}',
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            if (_selectedCliente == null) {
                              textEditingController.clear();
                            } else {
                              textEditingController.text =
                                  '${_selectedCliente!['clie_Nombres']} ${_selectedCliente!['clie_Apellidos']}';
                            }

                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                style: _labelStyle,
                                decoration: InputDecoration(
                                  hintText: 'Buscar cliente...',
                                  hintStyle: _hintStyle,
                                  border: InputBorder.none,
                                  suffixIcon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 24,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onTap: () {
                                  if (_selectedCliente != null) {
                                    setState(() {
                                      _selectedCliente = null;
                                      _selectedDireccion = null;
                                      _direcciones = [];
                                      textEditingController.clear();
                                    });
                                  }
                                },
                                validator: (value) => _selectedCliente == null
                                    ? 'Seleccione un cliente'
                                    : null,
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Map<String, dynamic>>
                            onSelected,
                            Iterable<Map<String, dynamic>> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () async {
                                          onSelected(option);
                                          setState(() {
                                            _selectedCliente = option;
                                            _selectedDireccion = null;
                                          });
                                          await _cargarDireccionesCliente(
                                            option['clie_Id'],
                                          );
                                        },
                                        child: ListTile(
                                          title: Text(
                                            '${option['clie_Nombres']} ${option['clie_Apellidos']}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            option['clie_NombreNegocio'] ??
                                                'Sin negocio',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                      onSelected: (Map<String, dynamic> selection) async {
                        setState(() {
                          _selectedCliente = selection;
                          _selectedDireccion = null;
                        });
                        await _cargarDireccionesCliente(selection['clie_Id']);
                      },
                    ),
                    if (_selectedCliente != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _selectedCliente!['clie_NombreNegocio']?.isNotEmpty ==
                                  true
                              ? _selectedCliente!['clie_NombreNegocio']
                              : 'Sin negocio registrado',
                          style: _hintStyle.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Dropdown de Dirección
                    const Text(
                      'Dirección *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Use the direccion id (int) as the dropdown value to avoid
                    // equality/assertion issues when using Map instances.
                    DropdownButtonFormField<int>(
                      value: _selectedDireccion == null
                          ? null
                          : (_selectedDireccion!['diCl_Id'] as num?)?.toInt(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _direcciones.map((direccion) {
                        final id = (direccion['diCl_Id'] as num?)?.toInt();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            '${direccion['diCl_DireccionExacta']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (selectedId) {
                        setState(() {
                          if (selectedId == null) {
                            _selectedDireccion = null;
                          } else {
                            try {
                              _selectedDireccion = _direcciones.firstWhere(
                                (d) =>
                                    (d['diCl_Id'] as num?)?.toInt() ==
                                    selectedId,
                              );
                            } catch (_) {
                              _selectedDireccion = null;
                            }
                          }
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione una dirección' : null,
                      isExpanded: true,
                    ),

                    const SizedBox(height: 16),

                    // Dropdown de Estado de Visita
                    const Text(
                      'Estado de la Visita *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedEstadoVisita,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _estadosVisita.map((estado) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: estado,
                          child: Text(
                            estado['esVi_Descripcion'] ?? 'Sin estado',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEstadoVisita = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Seleccione un estado' : null,
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
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Seleccione una fecha'
                          : null,
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
                    const Text(
                      'Imagen de la Visita *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    _buildImageField(),

                    const SizedBox(height: 24),

                    // Botón Guardar
                    CustomButton(
                      text: 'Guardar Visita',
                      onPressed: _submitForm,
                      height: 56,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
