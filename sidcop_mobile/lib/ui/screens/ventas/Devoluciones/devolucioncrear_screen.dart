import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/services/DevolucionesService.dart';
import 'package:sidcop_mobile/ui/screens/ventas/Devoluciones/devolucioneslist_screen.dart';
import 'package:sidcop_mobile/ui/screens/venta/invoice_detail_screen.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show showModalBottomSheet;

// Text style constants for consistent typography
final TextStyle _labelStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

final TextStyle _titleStyle = const TextStyle(
  fontFamily: 'Satoshi',
  fontSize: 18,
  fontWeight: FontWeight.bold,
);


final TextStyle _hintStyle = const TextStyle(
  fontFamily: 'Satoshi',
  color: Colors.grey,
);

class DevolucioncrearScreen extends StatefulWidget {
  const DevolucioncrearScreen({super.key});

  @override
  State<DevolucioncrearScreen> createState() => _DevolucioncrearScreenState();
}

class _DevolucioncrearScreenState extends State<DevolucioncrearScreen> {
  // Simple counter variable
  int _counter = 0;

  // Simple counter update function
  void _updateCounter(int change) {
    // This method is no longer used but kept for compatibility
    // The counter is now managed directly in the TextFormField
  }
  final _formKey = GlobalKey<FormState>();
  final ClientesService _clientesService = ClientesService();

  // Services
  final FacturaService _facturaService = FacturaService();
  final ProductosService _productosService = ProductosService();
  final DevolucionesService _devolucionesService = DevolucionesService();

  // Form controllers
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  // Form values
  int? _selectedClienteId;
  int? _selectedFacturaId;

  // Services are already declared above

  // Productos de la factura seleccionada
  List<Map<String, dynamic>> _productosFactura = [];
  bool _isLoadingProducts = false;
  String? _productosError;

  // Dropdown data
  List<Cliente> _clientes = [];
  Cliente? _selectedCliente;
  List<dynamic> _facturas = [];
  List<dynamic> _filteredFacturas = [];

  // Controllers
  final TextEditingController _clienteController = TextEditingController();

  // Loading states
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadData();
  }

  Widget _buildClienteOption(BuildContext context, Cliente cliente) {
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
            '${cliente.clie_Nombres} ${cliente.clie_Apellidos}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (cliente.clie_NombreNegocio?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              cliente.clie_NombreNegocio!,
              style: _hintStyle.copyWith(fontSize: 12),
            ),
          ],
          if (cliente.clie_Codigo?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              'Código: ${cliente.clie_Codigo}',
              style: _hintStyle.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final clientesData = await _clientesService.getClientes();
      final facturas = await _facturaService.getFacturas();

      setState(() {
        _clientes = clientesData.map((json) => Cliente.fromJson(json)).toList();
        _facturas = facturas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los datos: $e';
        _isLoading = false;
      });
    }
  }

  void _onClienteChanged(Cliente? cliente) {
    // Dismiss the keyboard when a client is selected
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _selectedCliente = cliente;
      _selectedClienteId = cliente?.clie_Id;
      _selectedFacturaId = null;
      _filteredFacturas = _selectedClienteId != null
          ? _facturas
                .where((factura) => factura['clie_Id'] == _selectedClienteId)
                .toList()
          : [];
    });
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
        final productos = await _productosService.getProductosPorFactura(
          facturaId,
        );

        // Mapear los productos al formato esperado por la UI
        final productosMapeados = productos
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

      // Crear la devolución con factura ajustada
      try {
        final response = await _devolucionesService.insertarDevolucionConFacturaAjustada(
          clieId: _selectedClienteId!,
          factId: _selectedFacturaId!,
          devoMotivo: _motivoController.text,
          usuaCreacion: 1, // TODO: Reemplazar con el ID del usuario autenticado
          detalles: productosADevolver,
          devoFecha: DateTime.tryParse(_fechaController.text),
          crearNuevaFactura: true,
        );

        // Cerrar el diálogo de carga
        if (!mounted) return;
        Navigator.pop(context);

        // Cerrar todas las pantallas y volver a la raíz
        Navigator.popUntil(context, (route) => route.isFirst);

        // Navegar a la pantalla de lista de devoluciones
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DevolucioneslistScreen(),
          ),
        );

        // Mostrar mensaje de éxito
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Devolución registrada exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Extraer datos de la respuesta
        final devoId = response['devolucion']?['data']?['devo_Id'] ?? 'N/A';
        final facturaAjustada = response['facturaAjustada'];
        final facturaCreada = facturaAjustada?['facturaCreada'] == true;
        final facturaNumero = facturaAjustada?['facturaNumero'];
        final nuevaFacturaId = facturaAjustada?['facturaId']; // ID de la nueva factura
        
        print('Datos extraídos - devoId: $devoId, facturaCreada: $facturaCreada');
        print('facturaNumero: $facturaNumero, nuevaFacturaId: $nuevaFacturaId');
        
        // Mostrar modal de éxito
        if (!mounted) return;
        if (facturaCreada && nuevaFacturaId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _buildReturnSuccessDialog(context, {
              'devoId': devoId,
              'facturaNumero': facturaNumero,
              'facturaId': nuevaFacturaId, // Pasar el ID correcto
              'productosDevueltos': productosADevolver.length,
            }),
          );
        } else {
          // Fallback: mostrar mensaje simple y navegar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Devolución #$devoId registrada exitosamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          _navigateToReturnsList();
        }
      } catch (e) {
        // Cerrar diálogo de carga
        if (!mounted) return;
        Navigator.pop(context);

        // Mostrar error
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear devolución: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
                      'Devolucion',
                      style: _titleStyle.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                    // Cliente Dropdown
                    Text(
                      'Cliente *',
                      style: _labelStyle.copyWith(fontWeight: FontWeight.bold),
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
                        vertical: 4,
                      ),
                      child: RawAutocomplete<Cliente>(
                        textEditingController: _clienteController,
                        focusNode: FocusNode(),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _clientes.take(10);
                          }
                          return _clientes.where((cliente) {
                            final searchValue = textEditingValue.text
                                .toLowerCase();
                            return (cliente.clie_Nombres
                                        ?.toLowerCase()
                                        .contains(searchValue) ??
                                    false) ||
                                (cliente.clie_Apellidos?.toLowerCase().contains(
                                      searchValue,
                                    ) ??
                                    false) ||
                                (cliente.clie_NombreNegocio
                                        ?.toLowerCase()
                                        .contains(searchValue) ??
                                    false) ||
                                (cliente.clie_Codigo?.toLowerCase().contains(
                                      searchValue,
                                    ) ??
                                    false);
                          });
                        },
                        displayStringForOption: (Cliente cliente) =>
                            '${cliente.clie_Nombres} ${cliente.clie_Apellidos}',
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // Clear the controller and let the hint text show when no cliente is selected
                              if (_selectedCliente == null) {
                                textEditingController.clear();
                              } else {
                                textEditingController.text =
                                    '${_selectedCliente!.clie_Nombres} ${_selectedCliente!.clie_Apellidos}';
                              }

                              return TextFormField(
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
                                      _selectedClienteId = null;
                                      _selectedFacturaId = null;
                                      _filteredFacturas = [];
                                      textEditingController.clear();
                                    });
                                  }
                                },
                              );
                            },
                        optionsViewBuilder:
                            (
                              BuildContext context,
                              AutocompleteOnSelected<Cliente> onSelected,
                              Iterable<Cliente> options,
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
                                            final Cliente option = options
                                                .elementAt(index);
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
                    ),
                    if (_selectedCliente != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _selectedCliente!.clie_NombreNegocio?.isNotEmpty ==
                                  true
                              ? _selectedCliente!.clie_NombreNegocio!
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
      MaterialPageRoute(
        builder: (context) => const DevolucioneslistScreen(),
      ),
    );
  }

  /// Resetea el formulario para una nueva devolución
  void _resetForm() {
    setState(() {
      _selectedCliente = null;
      _selectedClienteId = null;
      _selectedFacturaId = null;
      _filteredFacturas = [];
      _productosFactura = [];
      _fechaController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _motivoController.clear();
      _clienteController.clear();
    });
  }


  /// Navega a la pantalla de detalle de factura
  void _navigateToInvoiceDetail(Map<String, dynamic> data) {
    // Usar el ID que viene directamente en data (pasado desde el modal)
    final facturaId = data['facturaId'];
    final facturaNumero = data['facturaNumero'] ?? 'N/A';
    
    print('Navegando a nueva factura - ID: $facturaId, Número: $facturaNumero');
    
    if (facturaId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceDetailScreen(
            facturaId: facturaId,
            facturaNumero: facturaNumero,
          ),
        ),
      );
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
  Widget _buildReturnSuccessDialog(BuildContext context, Map<String, dynamic> data) {
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
                  const Text(
                    'Devolución procesada y factura ajustada creada',
                    style: TextStyle(
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
                          _buildCompactDetailRow('Devolución', '#${data['devoId']}'),
                          _buildCompactDetailRow('Nueva Factura', data['facturaNumero'] ?? 'N/A'),
                          _buildCompactDetailRow('Productos', '${data['productosDevueltos']} devueltos'),
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
                                Navigator.pop(context);
                                _resetForm();
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF141A2F)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Nueva Devolución',
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
                        
                        // Botón Ver Factura
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
              child: _productosFactura.isEmpty
                  ? const Center(child: Text('No hay productos disponibles'))
                  : ListView.builder(
                      key: const PageStorageKey('productos-list'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      itemCount: _productosFactura.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFactura[index];
                        // Parse quantities once and cache them
                        final cantidadVendida =
                            producto['cantidadVendida'] is int
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

                        final cantidadDevolver = _counter;

                        final precio = (producto['fade_Precio'] ?? 0.0)
                            .toDouble();

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
                                        child: Image.network(
                                          producto['prod_Imagen'],
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 70,
                                                    height: 70,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    color: Colors.grey[100],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      size: 24,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              keyboardType:
                                                  TextInputType.number,
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
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            Colors.grey[300]!,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
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
                                                  final controller =
                                                      TextEditingController(
                                                        text: maxCantidad
                                                            .toString(),
                                                      );
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
                                                // Ensure the value is saved when done editing
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
                                if (cantidadDevolver > 0) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total a devolver:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'L ${NumberFormat('#,##0.00').format(precio * cantidadDevolver)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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

  void _updateCantidad(int index, int change) {
    _updateCounter(change);
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _motivoController.dispose();
    _clienteController.dispose();
    super.dispose();
  }
}
