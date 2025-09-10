import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/add_address_screen.dart';
import 'package:sidcop_mobile/services/cloudinary_service.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/DropdownDataService.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/ui/widgets/custom_input.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';

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

final TextStyle _buttonTextStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontWeight: FontWeight.w600,
);

final TextStyle _hintStyle = const TextStyle(
  fontFamily: 'Satoshi',
  color: Colors.grey,
);

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
  final DireccionClienteService _direccionClienteService =
      DireccionClienteService();
  final ClientesOfflineService _clientesOfflineService = ClientesOfflineService();

  // Gender selection
  String _selectedGender = 'M';

  // Form controllers
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _dniController = TextEditingController();
  final _nombreNegocioController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _rtnController = TextEditingController();
  final List<DireccionCliente> _direcciones = [];
  int? usuaIdPersona;
  int? rutaId;
  bool? esAdmin;
  int? usuaId;

  var MKTelefono = new MaskTextInputFormatter(
    mask: '####-####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  var MKIdentidad = new MaskTextInputFormatter(
    mask: '####-####-#####', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  var MKRTN = new MaskTextInputFormatter(
    mask: '####-####-######', 
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy
  );

  // Error text states
  String? _nombresError;
  String? _apellidosError;
  String? _dniError;
  String? _rtnError;
  String? _nombreNegocioError;
  String? _telefonoError;

  @override
  void initState() {
    super.initState();
    _loadAllClientData();
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _dniController.dispose();
    _nombreNegocioController.dispose();
    super.dispose();
  }

  Future<void> _loadAllClientData() async {

    // Obtener el usua_IdPersona del usuario logueado
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();

    print('DEBUG: userData completo = $userData');
    print('DEBUG: userData keys = ${userData?.keys}');
    
    // Extraer rutasDelDiaJson y Ruta_Id
    final rutasDelDiaJson = userData?['rutasDelDiaJson'] as String?;
    
    if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty) {
      try {
        final rutasList = jsonDecode(rutasDelDiaJson) as List<dynamic>;
        print('DEBUG: rutasDelDiaJson parseado = $rutasList');
        
        // Obtener el primer elemento de la lista de rutas y extraer Ruta_Id
        if (rutasList.isNotEmpty) {
          rutaId = rutasList[0]['Ruta_Id'] as int?;
        }
      } catch (e) {
        print('ERROR al parsear rutasDelDiaJson: $e');
      }
    }
    
    print('DEBUG: rutaId = $rutaId');

    usuaIdPersona = userData?['usua_IdPersona'] as int?;
    final esVendedor = userData?['usua_EsVendedor'] as bool? ?? false;
    final esAdmin = userData?['usua_EsAdmin'] as bool? ?? false;
    usuaId = userData?['usua_Id'] as int?;
    // Cargar clientes por ruta usando el usua_IdPersona del usuario logueado
    List<dynamic> clientes = [];

    if (esVendedor && usuaIdPersona != null) {
      print(
        'DEBUG: Usuario es VENDEDOR - Usando getClientesPorRuta con ID: $usuaIdPersona',
      );
    } else if (esAdmin) {
      print('DEBUG: Usuario es ADMINISTRADOR - Mostrando todos los clientes');
      try {
        clientes = await SyncService.getClients();
        print('DEBUG: Clientes obtenidos para administrador: ${clientes.length}');
      } catch (e) {
        print('DEBUG: Error obteniendo clientes para admin: $e');
        clientes = [];
      }
    } else if (esVendedor && usuaIdPersona == null) {
      print(
        'DEBUG: Usuario vendedor sin usua_IdPersona válido - no se mostrarán clientes',
      );
      clientes = [];
      print('DEBUG: Lista de clientes vacía por seguridad (vendedor sin ID)');
    } else {
      print(
        'DEBUG: Usuario sin permisos (no es vendedor ni admin) - no se mostrarán clientes',
      );
      clientes = await SyncService.getClients();
      print('DEBUG: Lista de clientes vacía por seguridad (sin permisos)');
    }
  }

  bool _validateFields() {
    setState(() {
      _nombresError = _nombresController.text.trim().isEmpty
          ? 'Este campo es requerido'
          : null;
      _apellidosError = _apellidosController.text.trim().isEmpty
          ? 'Este campo es requerido'
          : null;
      _dniError = null; // Identity field is now optional
      _rtnError = null; // RTN field is now optional
      _nombreNegocioError = _nombreNegocioController.text.trim().isEmpty
          ? 'Este campo es requerido'
          : null;
      _telefonoError = _telefonoController.text.trim().isEmpty ? 'Este campo es requerido' : null;
    });
    return _nombresError == null && _apellidosError == null && _nombreNegocioError == null && _telefonoError == null;
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
        SnackBar(
          content: Text('Dirección agregada exitosamente', style: _labelStyle),
        ),
      );
    }
  }

  void _removeAddress(int index) {
    setState(() {
      _direcciones.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_validateFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor complete todos los campos requeridos',
            style: _labelStyle,
          ),
        ),
      );
      return;
    }

    if (_direcciones.isEmpty) {
      print('Error: No se han agregado direcciones.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe agregar al menos una dirección.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final isConnected = await _checkConnectivity();
      Uint8List? imageBytes;

      // Obtener los bytes de la imagen si existe
      if (_selectedImageBytes != null) {
        imageBytes = _selectedImageBytes;
      } else if (_selectedImage != null) {
        imageBytes = await _selectedImage!.readAsBytes();
      }

      // Preparar los datos del cliente
      final clienteData = {
        'clie_Codigo': 'CLI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'clie_Nacionalidad': 'HND',
        'clie_DNI': _dniController.text.trim(),
        'clie_RTN': _rtnController.text.trim(),
        'clie_Nombres': _nombresController.text.trim(),
        'clie_Apellidos': _apellidosController.text.trim(),
        'clie_NombreNegocio': _nombreNegocioController.text.trim(),
        'clie_ImagenDelNegocio': '', // Se actualizará con la URL de la imagen si se sube
        'clie_Telefono': _telefonoController.text.trim(),
        'clie_Correo': '',
        'clie_Sexo': _selectedGender,
        'clie_FechaNacimiento': DateTime(1990, 1, 1).toIso8601String(),
        'tiVi_Id': 1,
        'cana_Id': 1,
        'esCv_Id': 1,
        'ruta_Id': rutaId,
        'clie_LimiteCredito': 0,
        'clie_DiasCredito': 0,
        'clie_Saldo': 0,
        'clie_Vencido': false,
        'clie_Observaciones': 'Cliente creado desde la app móvil',
        'clie_ObservacionRetiro': 'Ninguna',
        'clie_Confirmacion': false,
        'usua_Creacion': usuaId,
        'clie_FechaCreacion': DateTime.now().toIso8601String(),
      };

      print('Datos del cliente a enviar: ${jsonEncode(clienteData)}');

      if (isConnected) {
        // Subir imagen primero
        if (imageBytes != null) {
          final imageUrl = await _uploadImage();
          if (imageUrl != null) {
            clienteData['clie_ImagenDelNegocio'] = imageUrl; // Asignar la URL de la imagen
          }
        }

        // Enviar datos del cliente
        final response = await _dropdownService.insertCliente(clienteData);

        if (response['success'] == true) {
          // Extraer el clientId de la respuesta
          final clientData = response['data'];
          if (clientData == null || clientData['data'] == null) {
            throw Exception('No se recibió un ID de cliente válido del servidor');
          }

          final clientId = clientData['data'] is String
              ? int.tryParse(clientData['data'])
              : (clientData['data'] as num?)?.toInt();

          if (clientId == null) {
            throw Exception(
              'Formato de ID de cliente inválido: ${clientData['data']}',
            );
          }

          print('Client ID extraído: $clientId (${clientId.runtimeType})');

          // Enviar direcciones al servidor
          int successfulAddresses = 0;

          for (var direccion in _direcciones) {
            try {
              // Actualizar el ID del cliente en cada dirección
              final direccionData = direccion.copyWith(clie_id: clientId);

              // Validar y completar los datos de la dirección
              final direccionJson = direccionData.toJson();
              direccionJson['colo_Descripcion'] ??= 'Sin descripción'; // Valor predeterminado
              direccionJson['muni_Descripcion'] ??= 'Sin descripción'; // Valor predeterminado
              direccionJson['depa_Descripcion'] ??= 'Sin descripción'; // Valor predeterminado

              print('=== Enviando dirección para cliente $clientId ===');
              print('Datos completos: ${jsonEncode(direccionJson)}');

              final direccionClienteObj = DireccionCliente.fromJson(direccionJson);
              final result = await _direccionClienteService.insertDireccionCliente(direccionClienteObj);

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
            print(
              'Advertencia: No todas las direcciones se guardaron correctamente ($successfulAddresses/${_direcciones.length} guardadas)',
            );
          }

          // Mostrar mensaje de éxito
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successfulAddresses == _direcciones.length
                      ? 'Cliente y direcciones creados exitosamente'
                      : 'Cliente creado, pero algunas direcciones no se guardaron correctamente ($successfulAddresses/${_direcciones.length} guardadas)',
                ),
                backgroundColor: successfulAddresses == _direcciones.length
                    ? Colors.green
                    : Colors.orange,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception(response['message'] ?? 'Error al crear el cliente');
        }
      } else {
        // Flujo offline: guardar datos localmente
        await ClientesOfflineService.saveClienteOffline(
          clienteData,
          _direcciones.map((d) => d.toJson()).toList(),
          imageBytes: imageBytes,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente guardado localmente. Se sincronizará cuando haya conexión.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
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

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
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
      final imageUploadService = ImageUploadService();
      final imageBytes = await _getImageBytes();
      return kIsWeb
          ? await imageUploadService.uploadImageFromBytes(imageBytes)
          : await imageUploadService.uploadImage(_selectedImage!);
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
                  _handleImageSelection(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleImageSelection(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Reduce image quality for faster uploads
        maxWidth: 1200, // Limit image dimensions
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
          _selectedImage = null; // Clear any previous file
        });
      } else {
        final file = File(image.path);
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
            content: Text('Error al procesar la imagen: ${e.toString()}'),
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
    String? errorText,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomInput(
        label: '$label${isRequired ? ' *' : ''}',
        hint: hint,
        controller: controller,
        keyboardType: keyboardType,
        errorText: errorText,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget _buildLocationButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Direcciones del Cliente',
          style: _titleStyle.copyWith(fontSize: 16),
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
                direccion.dicl_direccionexacta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle,
              ),
              subtitle: Text(
                direccion.dicl_observaciones,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle,
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
          text: 'Agregar Ubicacion',
          onPressed: _agregarUbicacion,
          icon: const Icon(Icons.add_location, color: Colors.white),
        ),
        if (_direcciones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No se han agregado direcciones',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'Satoshi',
              ),
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
      body: AppBackground(
        title: 'Agregar Cliente',
        icon: Icons.person_add,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Basic Information Section with Back Button
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
                      'Información del Cliente',
                      style: _titleStyle.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Nombre del Negocio
                _buildTextField(
                  label: 'Nombre del Negocio',
                  controller: _nombreNegocioController,
                  hint: 'Ingrese el nombre del negocio',
                  isRequired: true,
                  errorText: _nombreNegocioError,
                  onChanged: (value) {
                    if (_nombreNegocioError != null) {
                      setState(() {
                        _nombreNegocioError = null;
                      });
                    }
                  },
                ),
                // Nombres
                _buildTextField(
                  label: 'Nombres',
                  controller: _nombresController,
                  hint: 'Ingrese los nombres',
                  isRequired: true,
                  errorText: _nombresError,
                  onChanged: (value) {
                    if (_nombresError != null) {
                      setState(() {
                        _nombresError = null;
                      });
                    }
                  },
                ),
                // Apellidos
                _buildTextField(
                  label: 'Apellidos',
                  controller: _apellidosController,
                  hint: 'Ingrese los apellidos',
                  isRequired: true,
                  errorText: _apellidosError,
                  onChanged: (value) {
                    if (_apellidosError != null) {
                      setState(() {
                        _apellidosError = null;
                      });
                    }
                  },
                ),
                _buildTextField(
                  label: 'Numero De Telefono',
                  controller: _telefonoController,
                  hint: '0000-0000',
                  inputFormatters: [MKTelefono],
                  isRequired: true,
                  errorText: _telefonoError,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (_telefonoError != null) {
                      setState(() {
                        _telefonoError = null;
                      });
                    }
                  },
                ),
                // Identidad
                _buildTextField(
                  label: 'Identidad',
                  controller: _dniController,
                  hint: '0000-0000-00000 ',
                  isRequired: false,
                  inputFormatters: [MKIdentidad],
                  keyboardType: TextInputType.number,
                  errorText: _dniError,
                  onChanged: (value) {
                    if (_dniError != null) {
                      setState(() {
                        _dniError = null;
                      });
                    }
                  },
                ),
                _buildTextField(
                  label: 'RTN',
                  controller: _rtnController,
                  hint: '0000-0000-000000 ',
                  isRequired: false,
                  inputFormatters: [MKRTN],
                  keyboardType: TextInputType.number,
                  errorText: _rtnError,
                  onChanged: (value) {
                    if (_rtnError != null) {
                      setState(() {
                        _rtnError = null;
                      });
                    }
                  },
                ),
                // Gender selection
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Género',
                        style: _labelStyle,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: _selectedGender == 'M' 
                                    ? const Color(0xFF0D47A1) // Darker blue color
                                    : Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedGender = 'M';
                                    });
                                  },
                                  child: Container(
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.male,
                                          color: _selectedGender == 'M' 
                                              ? Colors.white 
                                              : const Color(0xFF0D47A1),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Masculino',
                                          style: TextStyle(
                                            color: _selectedGender == 'M' 
                                                ? Colors.white 
                                                : Colors.black,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                            Expanded(
                              child: Material(
                                color: _selectedGender == 'F' 
                                    ? const Color(0xFFF06292) // Pink color
                                    : Colors.white,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedGender = 'F';
                                    });
                                  },
                                  child: Container(
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.female,
                                          color: _selectedGender == 'F' 
                                              ? Colors.white 
                                              : const Color(0xFFF06292),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Femenino',
                                          style: TextStyle(
                                            color: _selectedGender == 'F' 
                                                ? Colors.white 
                                                : Colors.black,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationButton(),
                const SizedBox(height: 8),
                // Image Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Imagen del Negocio',
                      style: _titleStyle.copyWith(fontSize: 16),
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
                        child:
                            _selectedImage != null ||
                                _selectedImageBytes != null
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
                                children: [
                                  const Icon(
                                    Icons.add_a_photo,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toca para seleccionar una imagen',
                                    style: _hintStyle,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_selectedImage != null ||
                        _selectedImageBytes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Imagen seleccionada: ${kIsWeb ? 'Imagen web' : _selectedImage!.path.split('/').last}',
                        style: _hintStyle.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Enviar Solicitud',
                  onPressed: _isSubmitting ? null : _submitForm,
                  height: 50,
                  fontSize: 14,
                  icon: const Icon(Icons.send, size: 20, color: Colors.white),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
