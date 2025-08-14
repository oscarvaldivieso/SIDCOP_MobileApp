import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ClientesViewModel.Dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/FacturaService.dart';
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
  final _formKey = GlobalKey<FormState>();
  final ClientesService _clientesService = ClientesService();
  final FacturaService _facturaService = FacturaService();
  
  // Form controllers
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();
  
  // Form values
  int? _selectedClienteId;
  int? _selectedFacturaId;
  
  // Mock products data - Replace with actual API call later
  final List<Map<String, dynamic>> _productosFactura = [
    {
      'prod_Id': 80,
      'prod_Codigo': 'GEA-0001',
      'prod_CodigoBarra': 'EAGM-01081051',
      'prod_Descripcion': 'Espresso Americano, Graniccino Sabor a Mocha de 280ml',
      'prod_DescripcionCorta': 'Graniccino Mocha 220ml',
      'prod_Imagen': 'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1754671875/cpxd6mqcbpo6xotx62pz.webp',
      'subc_Descripcion': 'Bebidas',
      'marc_Descripcion': 'Espresso Americano',
      'fade_Cantidad': 5,
      'fade_Precio': 40.00,
      'fade_Descuento': 0.00,
      'fade_ISV': 6.00, // 15% de 40
      'cantidadDevolver': 0,
      'prod_PagaImpuesto': 'Si',
    },
    {
      'prod_Id': 79,
      'prod_Codigo': 'GBO-0001',
      'prod_CodigoBarra': 'BO-0106409',
      'prod_Descripcion': 'Galleta Black Out Clasica Sabor Vainilla y Chocolate',
      'prod_DescripcionCorta': 'Galleta Black Out Clasica',
      'prod_Imagen': 'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1754671708/ysurfreiip6g4de8c2qp.webp',
      'subc_Descripcion': 'Galletas',
      'marc_Descripcion': 'BlackOut',
      'fade_Cantidad': 10,
      'fade_Precio': 5.00,
      'fade_Descuento': 0.50,
      'fade_ISV': 0.00, // No paga impuesto
      'cantidadDevolver': 0,
      'prod_PagaImpuesto': 'No',
    },
    {
      'prod_Id': 78,
      'prod_Codigo': 'PMM-0001',
      'prod_CodigoBarra': 'LMPM-01140650',
      'prod_Descripcion': 'Pasta Moño La Moderna de 200 g',
      'prod_DescripcionCorta': 'Pasta Moño La Moderna',
      'prod_Imagen': 'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1754671496/me7dn3wphn6gtubde6mh.png',
      'subc_Descripcion': 'Pastas',
      'marc_Descripcion': 'La Moderna',
      'fade_Cantidad': 8,
      'fade_Precio': 15.00,
      'fade_Descuento': 1.00,
      'fade_ISV': 0.00, // No paga impuesto
      'cantidadDevolver': 0,
      'prod_PagaImpuesto': 'No',
    },
    {
      'prod_Id': 77,
      'prod_Codigo': 'DCV-001',
      'prod_CodigoBarra': '475822',
      'prod_Descripcion': 'Alimento Para Perros Dogui de Carne y Vegetales para perros adultos',
      'prod_DescripcionCorta': 'Dogui Adulto Carne y Vegetales',
      'prod_Imagen': 'https://res.cloudinary.com/dbt7mxrwk/image/upload/v1754670582/lnxcedxwnq9mgogywsoq.png',
      'subc_Descripcion': 'Perros',
      'marc_Descripcion': 'Dogui',
      'fade_Cantidad': 3,
      'fade_Precio': 30.00,
      'fade_Descuento': 0.00,
      'fade_ISV': 4.50, // 15% de 30
      'cantidadDevolver': 0,
      'prod_PagaImpuesto': 'Si',
    },
  ];
  
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
          ? _facturas.where((factura) => factura['clie_Id'] == _selectedClienteId).toList()
          : [];
    });
  }

  void _onFacturaChanged(int? facturaId) {
    setState(() {
      _selectedFacturaId = facturaId;
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implementar la lógica de envío
      final devolucion = {
        'clie_Id': _selectedClienteId,
        'fact_Id': _selectedFacturaId,
        'devo_Fecha': _fechaController.text,
        'devo_Motivo': _motivoController.text,
      };
      
      print('Devolución a enviar: $devolucion');
      // Aquí iría la lógica para guardar la devolución
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
                        // Cliente Dropdown
                        Text(
                          'Cliente *',
                          style: _labelStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
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
                                final searchValue = textEditingValue.text.toLowerCase();
                                return 
                                    (cliente.clie_Nombres?.toLowerCase().contains(searchValue) ?? false) ||
                                    (cliente.clie_Apellidos?.toLowerCase().contains(searchValue) ?? false) ||
                                    (cliente.clie_NombreNegocio?.toLowerCase().contains(searchValue) ?? false) ||
                                    (cliente.clie_Codigo?.toLowerCase().contains(searchValue) ?? false);
                              });
                            },
                            displayStringForOption: (Cliente cliente) => 
                                '${cliente.clie_Nombres} ${cliente.clie_Apellidos}',
                            fieldViewBuilder: (
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
                            optionsViewBuilder: (
                              BuildContext context,
                              AutocompleteOnSelected<Cliente> onSelected,
                              Iterable<Cliente> options,
                            ) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.9,
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final Cliente option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () {
                                            onSelected(option);
                                            _onClienteChanged(option);
                                          },
                                          child: _buildClienteOption(context, option),
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
                              _selectedCliente!.clie_NombreNegocio?.isNotEmpty == true 
                                  ? _selectedCliente!.clie_NombreNegocio! 
                                  : 'Sin negocio registrado',
                              style: _hintStyle.copyWith(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        
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
                                      vertical: 0, // Remove vertical padding from container
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: 56, // Set minimum height to match clientes dropdown
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        value: _selectedFacturaId,
                                        hint: const Text(
                                          'Seleccione una factura',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        items: _filteredFacturas.isEmpty && _selectedClienteId != null
                                            ? [
                                                const DropdownMenuItem<int>(
                                                  value: null,
                                                  child: Text(
                                                    'No hay facturas para este cliente',
                                                    style: TextStyle(color: Colors.grey),
                                                  ),
                                                )
                                              ]
                                            : _filteredFacturas.map<DropdownMenuItem<int>>((factura) {
                                                final facturaNumero = factura['fact_Numero']?.toString() ?? '';
                                                final facturaTotal = NumberFormat.currency(symbol: 'L ').format(factura['fact_Total']);
                                                
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
                                          height: 1.5, // Adjust line height for better vertical alignment
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          size: 24,
                                        ),
                                        isDense: true,
                                        itemHeight: 48, // Set item height to match clientes dropdown
                                        iconSize: 24, // Set icon size to match clientes dropdown
                                        dropdownColor: Colors.white, // Ensure dropdown background is white
                                        elevation: 1, // Add slight elevation to match clientes dropdown
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
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              constraints: const BoxConstraints(
                                minHeight: 56,
                              ),
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
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _fechaController.text = DateFormat('yyyy-MM-dd').format(picked);
                                          });
                                        }
                                      },
                                      validator: (value) => value?.isEmpty ?? true ? 'Ingrese una fecha' : null,
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
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                ),
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
                                validator: (value) => value?.isEmpty ?? true ? 'Ingrese el motivo de la devolución' : null,
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
  
  // Show productos modal
  void _showProductosModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productos de la factura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _productosFactura.length,
                  itemBuilder: (context, index) {
                    final producto = _productosFactura[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (producto['prod_Imagen'] != null) ...[
                                  Image.network(
                                    producto['prod_Imagen'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => 
                                        const Icon(Icons.image_not_supported, size: 60),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        producto['prod_DescripcionCorta'] ?? producto['prod_Descripcion'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (producto['marc_Descripcion'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Marca: ${producto['marc_Descripcion']}',
                                          style: _hintStyle.copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Código: ${producto['prod_Codigo']}',
                                  style: _hintStyle,
                                ),
                                Text(
                                  '${producto['fade_Cantidad']} disponibles',
                                  style: _hintStyle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cantidad a devolver:'),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: producto['cantidadDevolver'] > 0
                                          ? () => _updateCantidad(index, -1)
                                          : null,
                                    ),
                                    Text('${producto['cantidadDevolver']}'),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: producto['cantidadDevolver'] < producto['fade_Cantidad']
                                          ? () => _updateCantidad(index, 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (producto['cantidadDevolver'] > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total a devolver:'),
                                  Text(
                                    'L ${NumberFormat('#,##0.00').format(producto['fade_Precio'] * producto['cantidadDevolver'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Aceptar',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  height: 56,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateCantidad(int index, int change) {
    setState(() {
      _productosFactura[index]['cantidadDevolver'] += change;
    });
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _motivoController.dispose();
    _clienteController.dispose();
    super.dispose();
  }
}