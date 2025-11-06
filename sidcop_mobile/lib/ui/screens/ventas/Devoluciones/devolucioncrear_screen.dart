// Importaciones necesarias para la pantalla de crear devoluciones
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/direccion_cliente_model.dart';
import 'package:sidcop_mobile/services/DireccionClienteService.dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/Offline_Services/VerificarService.dart';
import 'package:sidcop_mobile/Offline_Services/Devoluciones_OfflineServices.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucioneslist_screen.dart';
import 'package:sidcop_mobile/ui/screens/venta/invoice_detail_screen.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

// Constantes de estilo de texto para tipografía consistente
final TextStyle _titleStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

// Estilo para etiquetas de campos
final TextStyle _labelStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

// Estilo para texto de ayuda (hints)
final TextStyle _hintStyle = const TextStyle(
  fontFamily: 'Satoshi',
  color: Colors.grey,
);

/// Pantalla para crear una nueva devolución
/// Permite seleccionar cliente, factura, productos y motivo de devolución
class DevolucioncrearScreen extends StatefulWidget {
  const DevolucioncrearScreen({super.key});

  @override
  State<DevolucioncrearScreen> createState() => _DevolucioncrearScreenState();
}

/// Estado que maneja la lógica y la interfaz de la pantalla de crear devoluciones
class _DevolucioncrearScreenState extends State<DevolucioncrearScreen> {
  // Clave del formulario para validación
  final _formKey = GlobalKey<FormState>();
  final DireccionClienteService _direccionClienteService =
      DireccionClienteService();

  // Servicios necesarios
  final FacturaService _facturaService = FacturaService();
  final ProductosService _productosService = ProductosService();
  final DevolucionesService _devolucionesService = DevolucionesService();

  // Controladores de los campos del formulario
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  // Valores del formulario
  int? _selectedClienteId;
  int? _selectedFacturaId;
  int? usuaIdPersona;
  bool? esAdmin;
  int? usuaId;
  int? rutaId;

  // Services are already declared above

  // Productos de la factura seleccionada
  List<Map<String, dynamic>> _productosFactura = [];
  bool _isLoadingProducts = false;
  String? _productosError;

  // Datos para los dropdowns
  List<DireccionCliente> _direcciones = [];
  DireccionCliente? _selectedDireccion;
  List<Map<String, dynamic>> _facturas = [];
  List<dynamic> _filteredFacturas = [];

  // Controlador para el campo de cliente
  final TextEditingController _clienteController = TextEditingController();

  // Estados de carga
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicializar la fecha con la fecha actual
    _fechaController.text = DateFormat(
      'yyyy-MM-dd-HH:mm:ss',
    ).format(DateTime.now());
    // Cargar datos necesarios al iniciar
    _loadData();
    _loadAllClientData();
  }

  /// Construye la opción de cliente en el dropdown
  /// Muestra nombre, negocio y dirección del cliente

  Widget _buildClienteOption(BuildContext context, DireccionCliente direccion) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatClienteName(direccion),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (direccion.clie_NombreNegocio?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              direccion.clie_NombreNegocio!,
              style: _hintStyle.copyWith(fontSize: 12),
            ),
          ],
          if (direccion.dicl_direccionexacta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              direccion.dicl_direccionexacta,
              style: _hintStyle.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// Formatea el nombre del cliente para mostrarlo
  /// Prioriza nombre completo, luego negocio, luego código
  String _formatClienteName(DireccionCliente direccion) {
    final nombre = (direccion.clie_Nombres ?? '').trim();
    final apellido = (direccion.clie_Apellidos ?? '').trim();
    final negocio = (direccion.clie_NombreNegocio ?? '').trim();
    final codigo = (direccion.clie_Codigo ?? '').trim();

    // Prioridad 1: Nombre completo
    if (nombre.isNotEmpty || apellido.isNotEmpty) {
      final parts = [
        if (nombre.isNotEmpty) nombre,
        if (apellido.isNotEmpty) apellido,
      ];
      return parts.join(' ');
    }

    // Prioridad 2: Nombre del negocio
    if (negocio.isNotEmpty) return negocio;
    // Prioridad 3: Código del cliente
    if (codigo.isNotEmpty) return codigo;
    return 'Cliente sin nombre';
  }

  /// Carga los datos del usuario actual (ID, permisos, ruta)
  /// Extrae el rutaId desde rutasDelDiaJson
  Future<void> _loadAllClientData() async {
    // Obtener datos del usuario logueado
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();

    print('DEBUG: userData completo = $userData');
    print('DEBUG: userData keys = ${userData?.keys}');

    // Extraer y parsear el JSON de rutas del día
    final rutasDelDiaJson = userData?['rutasDelDiaJson'] as String?;

    if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty) {
      try {
        // Decodificar el JSON de rutas
        final rutasList = jsonDecode(rutasDelDiaJson) as List<dynamic>;
        print('DEBUG: rutasDelDiaJson parseado = $rutasList');

        // Obtener el ID de la primera ruta asignada
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
    esAdmin = userData?['usua_EsAdmin'] as bool? ?? false;
    usuaId = userData?['usua_Id'] as int?;

    // Cargar clientes por ruta usando el usua_IdPersona del usuario logueado
    // lista de clientes se obtiene según permisos; variable local removida si no se usa

    if (esVendedor && usuaIdPersona != null) {
      print(
        'DEBUG: Usuario es VENDEDOR - Usando getClientesPorRuta con ID: $usuaIdPersona',
      );
    } else if (esVendedor && usuaIdPersona == null) {
      print(
        'DEBUG: Usuario vendedor sin usua_IdPersona válido - no se mostrarán clientes',
      );
      print('DEBUG: No se cargaron clientes (vendedor sin usua_IdPersona)');
    } else {
      print(
        'DEBUG: Usuario sin permisos (no es vendedor ni admin) - no se mostrarán clientes',
      );
      print('DEBUG: Solicitando lista de clientes por permisos');
    }
  }

  /// Verifica si un cliente pertenece a la ruta del usuario
  bool _clienteBelongsToRuta(String? clieCode) {
    if (rutaId == null || clieCode == null) return true;

    // Aquí puedes implementar la lógica específica para verificar
    // si el cliente pertenece a la ruta. Por ahora, retornamos true
    // para permitir todos los clientes hasta que se implemente la lógica específica
    return true;
  }

  void _onClienteChanged(DireccionCliente? direccion) {
    // Dismiss the keyboard when a client is selected
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _selectedDireccion = direccion;
      _selectedClienteId = direccion?.clie_id;
      _selectedFacturaId = null;
      _filteredFacturas = direccion != null
          ? _facturas
                .where((factura) => factura['diCl_Id'] == direccion.dicl_id)
                .where(
                  (factura) =>
                      esAdmin == true || factura['vend_Id'] == usuaIdPersona,
                )
                .toList()
          : [];
      // Actualizar el texto del controlador para reflejar la selección
      if (direccion != null) {
        //a
        // Usar el formateador seguro para evitar 'null null' cuando falten campos
        _clienteController.text = _formatClienteName(direccion);
      } else {
        _clienteController.clear();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final isOnline = await VerificarService.verificarConexion();

      if (!isOnline) {
        // Cargar desde almacenamiento local si existe
        try {
          final localFacturas =
              await DevolucionesOffline.obtenerFacturasCreateLocal();
          final localDirecciones =
              await DevolucionesOffline.obtenerDireccionesCreateLocal();

          final direccionesList = localDirecciones
              .map<DireccionCliente>((m) => DireccionCliente.fromJson(m))
              .toList();

          if (!mounted) return;
          setState(() {
            // Filtrar direcciones por rutaId si el usuario no es admin
            _direcciones = direccionesList.where((direccion) {
              // Si es admin, mostrar todas las direcciones
              if (esAdmin == true) return true;

              // Si no es admin, filtrar solo por rutaId
              bool matchesRuta =
                  rutaId == null ||
                  _clienteBelongsToRuta(direccion.clie_Codigo);

              return matchesRuta;
            }).toList();
            _facturas = List<Map<String, dynamic>>.from(localFacturas);
            _isLoading = false;
          });
          return;
        } catch (localErr) {
          print('Error cargando datos locales para create: $localErr');
          // Continuar y tratar de cargar online a continuación
        }
      }

      // Si estamos online, intentar cargar desde servicios remotos
      final direccionesData = await _direccionClienteService
          .getDireccionesPorCliente();
      final facturasData = await _facturaService
          .getFacturasDevolucionesLimite();

      // Guardar versiones offline de facturas y direcciones para permitir crear devoluciones offline
      try {
        await DevolucionesOffline.guardarFacturasCreate(
          List<Map<String, dynamic>>.from(facturasData),
        );

        final direccionesMap = direccionesData
            .map<Map<String, dynamic>>((d) => d.toJson())
            .toList();
        await DevolucionesOffline.guardarDireccionesCreate(direccionesMap);
      } catch (e) {
        print('Error guardando datos create en offline: $e');
      }

      if (!mounted) return;

      setState(() {
        // Filtrar direcciones por rutaId si el usuario no es admin
        _direcciones = direccionesData.where((direccion) {
          // Si es admin, mostrar todas las direcciones
          if (esAdmin == true) return true;

          // Si no es admin, filtrar solo por rutaId
          bool matchesRuta =
              rutaId == null || _clienteBelongsToRuta(direccion.clie_Codigo);

          return matchesRuta;
        }).toList();
        _facturas = List<Map<String, dynamic>>.from(facturasData);
        _isLoading = false;
      });
    } catch (e) {
      // En caso de fallo online, intentar cargar desde almacenamiento local
      print('Error al cargar datos online, intentando fallback local: $e');
      try {
        final localFacturas =
            await DevolucionesOffline.obtenerFacturasCreateLocal();
        final localDirecciones =
            await DevolucionesOffline.obtenerDireccionesCreateLocal();

        final direccionesList = localDirecciones
            .map<DireccionCliente>((m) => DireccionCliente.fromJson(m))
            .toList();

        if (!mounted) return;
        setState(() {
          // Filtrar direcciones por rutaId si el usuario no es admin
          _direcciones = direccionesList.where((direccion) {
            // Si es admin, mostrar todas las direcciones
            if (esAdmin == true) return true;

            // Si no es admin, filtrar solo por rutaId
            bool matchesRuta =
                rutaId == null || _clienteBelongsToRuta(direccion.clie_Codigo);

            return matchesRuta;
          }).toList();
          _facturas = List<Map<String, dynamic>>.from(localFacturas);
          _isLoading = false;
        });
      } catch (localErr) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error al cargar los datos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onFacturaChanged(int? facturaId) async {
    setState(() {
      _selectedFacturaId = facturaId;
      _productosFactura = []; // Reset productos al cambiar factura
      _isLoadingProducts = facturaId != null;
      _productosError = null;
    });

    if (facturaId != null) {
      try {
        // Intentar leer productos prefetcheados primero
        final cachedProductos =
            await DevolucionesOffline.obtenerProductosPorFacturaLocal(
              facturaId,
            );
        List<dynamic> productos;
        if (cachedProductos.isNotEmpty) {
          productos = cachedProductos;
          print(
            'Usando productos prefetcheados locales para factura $facturaId',
          );
        } else {
          productos = await _productosService.getProductosPorFactura(facturaId);
        }

        // Guardar productos offline para que estén disponibles sin conexión
        try {
          await DevolucionesOffline.guardarProductosPorFactura(
            facturaId,
            productos,
          );
        } catch (e) {
          print(
            'Error guardando productos offline para factura $facturaId: $e',
          );
        }

        // Mapear los productos al formato esperado por la UI
        final productosMapeados = productos
            .map(
              (producto) => {
                'prod_Id': producto['prod_Id'],
                'prod_Codigo': producto['prod_Codigo'],
                'prod_Descripcion': producto['prod_Descripcion'],
                'prod_DescripcionCorta': producto['prod_DescripcionCorta'],
                'prod_Imagen':
                    producto['prod_Imagen'], // puede ser URL o ruta local
                'subc_Descripcion': producto['subc_Descripcion'],
                'marc_Descripcion': producto['marc_Descripcion'],
                'cantidadVendida':
                    producto['cantidadVendida'] ??
                    producto['fade_Cantidad'], // Mantener compatibilidad hacia atrás
                'fade_Precio': producto['fade_Precio'],
                'fade_Descuento': producto['fade_Descuento'] ?? 0.0,
                'fade_ISV': producto['fade_ISV'] ?? 0.0,
                'cantidadDevolver':
                    0, // Inicializar la cantidad a devolver en 0
                'prod_PagaImpuesto': producto['prod_PagaImpuesto'] ?? 'No',
              },
            )
            .toList();

        setState(() {
          _productosFactura = productosMapeados;
          _isLoadingProducts = false;
        });
      } catch (e) {
        // Intentar cargar productos desde cache local si falla la petición online
        print('Error al cargar los productos online: $e');
        try {
          final cached =
              await DevolucionesOffline.obtenerProductosPorFacturaLocal(
                facturaId,
              );
          if (cached.isNotEmpty) {
            final productosMapeados = cached
                .map(
                  (producto) => {
                    'prod_Id': producto['prod_Id'],
                    'prod_Codigo': producto['prod_Codigo'],
                    'prod_Descripcion': producto['prod_Descripcion'],
                    'prod_DescripcionCorta': producto['prod_DescripcionCorta'],
                    'prod_Imagen': producto['prod_Imagen'],
                    'subc_Descripcion': producto['subc_Descripcion'],
                    'marc_Descripcion': producto['marc_Descripcion'],
                    'cantidadVendida':
                        producto['cantidadVendida'] ??
                        producto['fade_Cantidad'],
                    'fade_Precio': producto['fade_Precio'],
                    'fade_Descuento': producto['fade_Descuento'] ?? 0.0,
                    'fade_ISV': producto['fade_ISV'] ?? 0.0,
                    'cantidadDevolver': 0,
                    'prod_PagaImpuesto': producto['prod_PagaImpuesto'] ?? 'No',
                  },
                )
                .toList();

            setState(() {
              _productosFactura = productosMapeados;
              _isLoadingProducts = false;
            });
            return;
          }
        } catch (localErr) {
          print('Error cargando productos desde cache local: $localErr');
        }

        setState(() {
          _productosError = 'Error al cargar los productos: $e';
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() &&
        _selectedClienteId != null &&
        _selectedFacturaId != null) {
      // Filtrar solo los productos con cantidad a devolver > 0
      final productosADevolver = _productosFactura
          .where((p) => (p['cantidadDevolver'] as int) > 0)
          .map(
            (p) => {
              'prod_Id': p['prod_Id'],
              'cantidadDevolver': p['cantidadDevolver'],
            },
          )
          .toList();

      if (productosADevolver.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleccione al menos un producto para devolver'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Mostrar diálogo de confirmación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar devolución'),
          content: const Text('¿Está seguro de realizar esta devolución?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mostrar indicador de carga
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final isOnline = await VerificarService.verificarConexion();

        if (isOnline) {
          // Enviar devolución online
          final response = await _devolucionesService
              .insertarDevolucionConFacturaAjustada(
                clieId: _selectedClienteId!,
                factId: _selectedFacturaId!,
                devoMotivo: _motivoController.text,
                usuaCreacion: usuaId!,
                detalles: productosADevolver,
                devoFecha: DateTime.tryParse(_fechaController.text),
                crearNuevaFactura: true,
              );

          Navigator.pop(context); // Cerrar el diálogo de carga

          // Print para verificar la respuesta del endpoint
          print('Respuesta del endpoint:');
          print(response);

          if (response['success'] == true) {
            // Mostrar éxito
            final modalData = {
              'devoId': response['devolucion']?['data']?['devo_Id'] ?? 'N/A',
              'facturaNumero': response['facturaAjustada']?['facturaNumero'],
              'productosDevueltos': productosADevolver.length,
              'facturaCreada':
                  response['facturaAjustada']?['facturaCreada'] == true,
              'facturaData':
                  response['facturaAjustada']?['ventaServiceResponse']?['data'],
            };
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => _buildReturnSuccessDialog(context, modalData),
            );
          } else {
            // Mostrar error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Error desconocido'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Guardar devolución offline
          final clienteNombre = _selectedDireccion != null
              ? _formatClienteName(_selectedDireccion!)
              : '';

          final pending = {
            'clie_Id': _selectedClienteId,
            'clie_Nombre': clienteNombre,
            // También incluir claves alternativas que el ViewModel busca
            'clie_NombreNegocio': clienteNombre,
            'clieNombreNegocio': clienteNombre,
            'fact_Id': _selectedFacturaId,
            'devo_Motivo': _motivoController.text,
            'usua_Creacion': usuaId ?? 0,
            'devo_Fecha': _fechaController.text,
            'detalles': productosADevolver,
            'pendiente_Creacion': DateTime.now().toIso8601String(),
          };

          // Print para verificar la devolución guardada offline
          print('Devolución guardada offline:');
          print(pending);

          final added =
              await DevolucionesOffline.agregarDevolucionPendienteLocal(
                pending,
              );

          Navigator.pop(context); // Cerrar el diálogo de carga

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added
                    ? 'Sin conexión: devolución guardada como pendiente'
                    : 'Sin conexión: ya existe una devolución pendiente similar',
              ),
              backgroundColor: Colors.orange,
            ),
          );

          _navigateToReturnsList();
        }
      } catch (e) {
        Navigator.pop(context); // Cerrar el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la devolución: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Nueva Devolución',
      icon: Icons.restart_alt,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          'Devoluciones',
                          style: _titleStyle.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Cliente Dropdown
                    Text(
                      'Cliente *',
                      style: _labelStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    RawAutocomplete<DireccionCliente>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          final sortedDirecciones = List<DireccionCliente>.from(
                            _direcciones,
                          );
                          sortedDirecciones.sort(
                            (a, b) => b.dicl_fechacreacion.compareTo(
                              a.dicl_fechacreacion,
                            ),
                          );
                          return sortedDirecciones;
                        }
                        return _direcciones.where((DireccionCliente direccion) {
                          final searchValue = textEditingValue.text
                              .toLowerCase();
                          return (direccion.clie_Nombres
                                      ?.toLowerCase()
                                      .contains(searchValue) ??
                                  false) ||
                              (direccion.clie_Apellidos?.toLowerCase().contains(
                                    searchValue,
                                  ) ??
                                  false) ||
                              (direccion.clie_NombreNegocio
                                      ?.toLowerCase()
                                      .contains(searchValue) ??
                                  false) ||
                              (direccion.clie_Codigo?.toLowerCase().contains(
                                    searchValue,
                                  ) ??
                                  false);
                        });
                      },
                      displayStringForOption: (DireccionCliente direccion) =>
                          _formatClienteName(direccion),
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            // Clear the controller and let the hint text show when no cliente is selected
                            if (_selectedDireccion == null) {
                              textEditingController.clear();
                            } else {
                              textEditingController.text = _formatClienteName(
                                _selectedDireccion!,
                              );
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
                                  if (_selectedDireccion != null) {
                                    setState(() {
                                      _selectedDireccion = null;
                                      _selectedClienteId = null;
                                      _selectedFacturaId = null;
                                      _filteredFacturas = [];
                                      textEditingController.clear();
                                    });
                                  }
                                },
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<DireccionCliente> onSelected,
                            Iterable<DireccionCliente> options,
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
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final DireccionCliente option =
                                              options.elementAt(index);
                                          return InkWell(
                                            onTap: () {
                                              onSelected(option);
                                              _onClienteChanged(option);
                                            },
                                            child: _buildClienteOption(
                                              context,
                                              option,
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ),
                            );
                          },
                      onSelected: _onClienteChanged,
                    ),
                    if (_selectedDireccion != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _selectedDireccion!.muni_descripcion.isNotEmpty
                              ? _selectedDireccion!.muni_descripcion
                              : 'Sin negocio registrado',
                          style: _hintStyle.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Productos de la factura
                    const SizedBox(height: 16),

                    // Factura Dropdown with Productos Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical:
                                      0, // Remove vertical padding from container
                                ),
                                constraints: const BoxConstraints(
                                  minHeight:
                                      56, // Set minimum height to match clientes dropdown
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value: _selectedFacturaId,
                                    hint: const Text(
                                      'Seleccione una factura',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    items:
                                        _filteredFacturas.isEmpty &&
                                            _selectedClienteId != null
                                        ? [
                                            const DropdownMenuItem<int>(
                                              value: null,
                                              child: Text(
                                                'No hay facturas para este cliente',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ]
                                        : _filteredFacturas.map<
                                            DropdownMenuItem<int>
                                          >((factura) {
                                            final facturaNumero =
                                                factura['fact_Numero']
                                                    ?.toString() ??
                                                '';
                                            final facturaTotal =
                                                NumberFormat.currency(
                                                  symbol: 'L ',
                                                ).format(factura['fact_Total']);

                                            return DropdownMenuItem<int>(
                                              value: factura['fact_Id'],
                                              child: Text(
                                                '#$facturaNumero • $facturaTotal',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    onChanged: _onFacturaChanged,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height:
                                          1.5, // Adjust line height for better vertical alignment
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 24,
                                    ),
                                    isDense: true,
                                    itemHeight:
                                        48, // Set item height to match clientes dropdown
                                    iconSize:
                                        24, // Set icon size to match clientes dropdown
                                    dropdownColor: Colors
                                        .white, // Ensure dropdown background is white
                                    elevation:
                                        1, // Add slight elevation to match clientes dropdown
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedFacturaId != null) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 56, // Match the height of the dropdown
                                child: CustomButton(
                                  text: 'Productos',
                                  onPressed: _showProductosModal,
                                  width: 120, // Fixed width for the button
                                  height: 40, // Slightly smaller height
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedFacturaId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Seleccione los productos a devolver',
                            style: _hintStyle.copyWith(fontSize: 12),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Fecha
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha *',
                          style: _labelStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _fechaController,
                                  style: _labelStyle,
                                  decoration: const InputDecoration(
                                    hintText: 'Seleccione una fecha',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        _fechaController.text = DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(picked);
                                      });
                                    }
                                  },
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Ingrese una fecha'
                                      : null,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Motivo
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motivo de la devolución *',
                          style: _labelStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: TextFormField(
                            controller: _motivoController,
                            style: _labelStyle,
                            decoration: const InputDecoration(
                              hintText: 'Ingrese el motivo de la devolución',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            maxLines: 3,
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Ingrese el motivo de la devolución'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Botón de guardar
                    CustomButton(
                      text: 'Guardar Devolución',
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

  /// Navega a la lista de devoluciones
  void _navigateToReturnsList() {
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DevolucioneslistScreen()),
    );
  }

  // _resetForm removed (unused)

  /// Extrae el ID de la factura del mensaje de respuesta del backend
  /// El mensaje tiene formato: "Venta insertada correctamente. ID: 62. Factura creada exitosamente. Total: -4880.00"
  int? _extractInvoiceIdFromMessage(String message) {
    try {
      // Buscar el patrón "ID: [número]"
      final regex = RegExp(r'ID:\s*(\d+)');
      final match = regex.firstMatch(message);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      print('Error al extraer ID de factura del mensaje: $e');
    }
    return null;
  }

  /// Navega a la pantalla de detalle de factura
  void _navigateToInvoiceDetail(Map<String, dynamic> data) async {
    final facturaNumero = data['facturaNumero'] ?? 'N/A';
    final facturaData = data['facturaData'];

    print('Navegando a nueva factura - Número: $facturaNumero');
    print('Datos de factura disponibles: $facturaData');

    // Extraer ID usando la misma lógica que VentaScreen
    int? facturaId;

    // 1. PRIORIDAD: Extraer del message_Status usando regex
    if (facturaData != null && facturaData['message_Status'] != null) {
      facturaId = _extractInvoiceIdFromMessage(facturaData['message_Status']);
      print('ID extraído del message_Status: $facturaId');
    }

    // 2. FALLBACK: Buscar en campos directos
    if (facturaId == null && facturaData != null) {
      facturaId =
          facturaData['fact_Id'] ??
          facturaData['id'] ??
          facturaData['facturaId'];
      print('ID extraído de campos directos: $facturaId');
    }

    print('ID de factura final: $facturaId');

    if (facturaId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceDetailScreen(
            facturaId: facturaId!,
            facturaNumero: facturaNumero,
            fromVentasList: true,
          ),
        ),
      );
      // Después de regresar de ver la factura, ir a la lista de devoluciones
      if (mounted) {
        _navigateToReturnsList();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el ID de la nueva factura'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Construye el diálogo de éxito para devoluciones
  Widget _buildReturnSuccessDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF98BF4A),
                    const Color(0xFF98BF4A).withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF98BF4A),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '¡Devolución Exitosa!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['facturaCreada'] == true
                        ? 'Devolución procesada y factura ajustada creada'
                        : 'Devolución procesada - Factura original anulada',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Información básica
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detalles',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF141A2F),
                              fontFamily: 'Satoshi',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildCompactDetailRow(
                            'Devolución',
                            '#${data['devoId']}',
                          ),
                          if (data['facturaCreada'] == true)
                            _buildCompactDetailRow(
                              'Nueva Factura',
                              data['facturaNumero'] ?? 'N/A',
                            ),
                          _buildCompactDetailRow(
                            'Productos',
                            '${data['productosDevueltos']} devueltos',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botones
                    Row(
                      children: [
                        // Botón Nueva Devolución
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context); // Cerrar modal
                                Navigator.pop(context); // Regresar al inicio
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF141A2F),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Regresar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Satoshi',
                                  color: Color(0xFF141A2F),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Botón Ver Factura (solo si se creó nueva factura)
                        if (data['facturaCreada'] == true)
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToInvoiceDetail(data);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF98BF4A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.visibility, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ver Factura',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye una fila de detalle compacta
  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C757D),
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Show productos modal
  void _showProductosModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header with drag handle and title
            Container(
              padding: const EdgeInsets.only(
                top: 8,
                left: 16,
                right: 8,
                bottom: 8,
              ),
              child: Column(
                children: [
                  // Drag handle
                  GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta! > 5) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Productos de la factura',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Products list with fixed height to prevent overflow
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoadingProducts) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_productosError != null) {
                    return Center(child: Text(_productosError!));
                  }
                  if (_productosFactura.isEmpty) {
                    return const Center(
                      child: Text('No hay productos disponibles'),
                    );
                  }

                  return ListView.builder(
                    key: const PageStorageKey('productos-list'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    itemCount: _productosFactura.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFactura[index];
                      // Parse quantities once and cache them
                      final cantidadVendida = producto['cantidadVendida'] is int
                          ? producto['cantidadVendida']
                          : (producto['cantidadVendida'] is double
                                ? (producto['cantidadVendida'] as double)
                                      .toInt()
                                : int.tryParse(
                                        producto['cantidadVendida']
                                                ?.toString() ??
                                            '0',
                                      ) ??
                                      0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product info row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product image
                                  if (producto['prod_Imagen'] != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Builder(
                                        builder: (context) {
                                          final imgRef =
                                              producto['prod_Imagen']
                                                  ?.toString() ??
                                              '';
                                          // Si parece una ruta local a archivo, intentar Image.file
                                          if (imgRef.isNotEmpty &&
                                              (imgRef.startsWith('/') ||
                                                  imgRef.startsWith('C:') ||
                                                  imgRef.startsWith('\\'))) {
                                            final file = File(imgRef);
                                            return FutureBuilder<bool>(
                                              future: file.exists(),
                                              builder: (context, snap) {
                                                if (snap.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return Container(
                                                    width: 70,
                                                    height: 70,
                                                    color: Colors.grey[100],
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  );
                                                }
                                                if (snap.hasData &&
                                                    snap.data == true) {
                                                  return Image.file(
                                                    file,
                                                    width: 70,
                                                    height: 70,
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                                // Fallback a network si el archivo no existe
                                                return Image.network(
                                                  imgRef,
                                                  width: 70,
                                                  height: 70,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        width: 70,
                                                        height: 70,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        color: Colors.grey[100],
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 24,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                );
                                              },
                                            );
                                          }

                                          // Si no es ruta local, usar directamente Image.network
                                          return Image.network(
                                            imgRef,
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
                                                  width: 70,
                                                  height: 70,
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 24,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  // Product details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          producto['prod_DescripcionCorta'] ??
                                              producto['prod_Descripcion'] ??
                                              'Producto sin nombre',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (producto['marc_Descripcion'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Marca: ${producto['marc_Descripcion']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Código: ${producto['prod_Codigo'] ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$cantidadVendida disponibles',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Quantity controls with better spacing
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cantidad disponible: $cantidadVendida',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Cantidad a devolver:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Container(
                                          width: 120,
                                          child: TextFormField(
                                            controller: TextEditingController(
                                              text:
                                                  (_productosFactura[index]['cantidadDevolver'] ??
                                                          0)
                                                      .toString(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.grey[300]!,
                                                  width: 1.5,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.grey[300]!,
                                                  width: 1.5,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  width: 1.5,
                                                ),
                                              ),
                                              hintText: '0',
                                              isDense: true,
                                              suffix: Text(
                                                'de $cantidadVendida',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              if (value.isEmpty) {
                                                setState(
                                                  () =>
                                                      _productosFactura[index]['cantidadDevolver'] =
                                                          0,
                                                );
                                                return;
                                              }

                                              final cantidad =
                                                  int.tryParse(value) ?? 0;
                                              final maxCantidad =
                                                  _productosFactura[index]['cantidadVendida']
                                                      is int
                                                  ? _productosFactura[index]['cantidadVendida']
                                                  : (_productosFactura[index]['cantidadVendida']
                                                            as double)
                                                        .toInt();

                                              if (cantidad > maxCantidad) {
                                                setState(
                                                  () =>
                                                      _productosFactura[index]['cantidadDevolver'] =
                                                          maxCantidad,
                                                );
                                              } else if (cantidad >= 0) {
                                                setState(
                                                  () =>
                                                      _productosFactura[index]['cantidadDevolver'] =
                                                          cantidad,
                                                );
                                              }
                                            },
                                            onEditingComplete: () {
                                              final currentValue =
                                                  _productosFactura[index]['cantidadDevolver'] ??
                                                  0;
                                              setState(() {
                                                _productosFactura[index]['cantidadDevolver'] =
                                                    currentValue;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Total to return
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Cerrar el modal
                          await _submitForm(); // Procesar el formulario
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // Cerrar el modal
                          await _submitForm(); // Procesar el formulario
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Aceptar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _motivoController.dispose();
    _clienteController.dispose();
    super.dispose();
  }
}
