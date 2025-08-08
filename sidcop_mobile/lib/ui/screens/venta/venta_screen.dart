import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/utils/invoice_utils.dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';

// Modelo centralizado para los datos
class FormData {
  String metodoPago = '';
  String datosCliente = '';
  String productos = '';
  bool confirmacion = false;
}

class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final PageController _pageController = PageController();
  final FormData formData = FormData();
  final VentaService _ventaService = VentaService();
  final ProductosService _productosService = ProductosService();
  VentaInsertarViewModel _ventaModel = VentaInsertarViewModel.empty();

  // Variables para productos
  List<Productos> _allProducts = [];
  List<Productos> _filteredProducts = [];
  final Map<int, double> _selectedProducts = {}; // prod_Id -> cantidad
  bool _isLoadingProducts = false;
  final TextEditingController _searchController = TextEditingController();

  int currentStep = 0;
  final int totalSteps = 4;
  
  final List<String> stepTitles = [
    'Método de Pago',
    'Productos disponibles',
    'Selección de Productos',
    'Confirmación de venta'
  ];
  
  final List<String> stepDescriptions = [
    'Selecciona el método de pago con el cual el cliente cancelará la venta',
    'Selecciona los productos que tienes disponibles en tu inventario',
    'Confirma los productos que deseas vender',
    'Revisa y confirma la información'
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_applyProductFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      _allProducts = await _productosService.getProductos();
      _filteredProducts = List.from(_allProducts);
    } catch (e) {
      debugPrint('Error cargando productos: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _applyProductFilter() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesSearch = searchTerm.isEmpty ||
            (product.prod_Descripcion?.toLowerCase().contains(searchTerm) ?? false) ||
            (product.prod_Codigo?.toLowerCase().contains(searchTerm) ?? false);
        return matchesSearch;
      }).toList();
    });
  }

  void _updateProductQuantity(int prodId, double quantity) {
    setState(() {
      if (quantity > 0) {
        _selectedProducts[prodId] = quantity;
      } else {
        _selectedProducts.remove(prodId);
      }
      // Actualizar el modelo de venta
      _updateVentaModel();
    });
  }

  void _updateVentaModel() {
    _ventaModel.detallesFacturaInput.clear();
    _selectedProducts.forEach((prodId, cantidad) {
      _ventaModel.agregarProducto(prodId, cantidad);
    });
    
    // Actualizar el formData para mostrar en el resumen
    final productNames = _selectedProducts.entries.map((entry) {
      final product = _allProducts.firstWhere((p) => p.prod_Id == entry.key);
      return '${product.prod_DescripcionCorta ?? 'Producto'} (${entry.value})';
    }).join(', ');
    formData.productos = productNames;
  }

  void nextStep() {
    if (validarPaso()) {
      if (currentStep < totalSteps - 1) {
        setState(() => currentStep++);
        _pageController.animateToPage(
          currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        mostrarResumen();
      }
    }
  }

  void prevStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool validarPaso() {
    switch (currentStep) {
      case 0:
        if (formData.metodoPago.trim().isEmpty) {
          mostrarError("Por favor selecciona un método de pago");
          return false;
        }
        break;
      case 1:
        // Validación de datos del cliente removida
        break;
      case 2:
        if (formData.productos.trim().isEmpty) {
          mostrarError("Por favor selecciona al menos un producto");
          return false;
        }
        break;
      case 3:
        if (!formData.confirmacion) {
          mostrarError("Debes confirmar la venta");
          return false;
        }
        break;
    }
    return true;
  }

  void mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  void mostrarResumen() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar Venta", style: TextStyle(fontFamily: 'Satoshi')),
        content: Text(
          "Método de Pago: ${formData.metodoPago}\n"
          "Cliente: ${formData.datosCliente}\n"
          "Productos: ${formData.productos}\n"
          "¿Deseas procesar esta venta?",
          style: const TextStyle(fontFamily: 'Satoshi'),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(fontFamily: 'Satoshi')),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF98BF4A),
              foregroundColor: Colors.white,
            ),
            child: const Text("Procesar Venta", style: TextStyle(fontFamily: 'Satoshi')),
            onPressed: () {
              Navigator.pop(context);
              _procesarVenta();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _procesarVenta() async {
    // Mostrar indicador de carga
    final loadingContext = Navigator.of(context, rootNavigator: true).overlay!.context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Procesando venta...", style: TextStyle(fontFamily: 'Satoshi')),
          ],
        ),
      ),
    );

    try {
      print('Iniciando procesamiento de venta...');
      
      // Obtener el último número de factura (deberías obtenerlo de tu base de datos o API)
      // Por ahora, usaremos un valor por defecto
      final lastInvoiceNumber = "F001-000003411"; // Esto debería venir de tu base de datos
      
      // Generar el nuevo número de factura
      final newInvoiceNumber = InvoiceUtils.getNextInvoiceNumber(lastInvoiceNumber);
      print('Nuevo número de factura generado: $newInvoiceNumber');
      
      // Asignar el número de factura al modelo
      _ventaModel.factNumero = newInvoiceNumber;
      _ventaModel.factTipoDeDocumento = "FAC";
      _ventaModel.regCId = 19;
      _ventaModel.factFechaEmision = DateTime.now();
      _ventaModel.factFechaLimiteEmision = DateTime.now().add(const Duration(days: 30));
      _ventaModel.factRangoInicialAutorizado = "F001-00000001";
      _ventaModel.factRangoFinalAutorizado = "F001-00099999";
      _ventaModel.factReferencia = "Venta desde app móvil";
      _ventaModel.factLatitud = 14.072245;
      _ventaModel.factLongitud = -88.212665;
      _ventaModel.factAutorizadoPor = "Sistema";
      
      // TODO: Estos valores deberían venir de la sesión del usuario y selección de cliente
      _ventaModel.clieId = 111; // Temporal - debe venir de la selección de cliente
      _ventaModel.vendId = 12; // Temporal - debe venir de la sesión del usuario
      _ventaModel.usuaCreacion = 1; // Temporal - debe venir de la sesión del usuario
      
      // Validar el modelo antes de enviar
      print('Validando modelo de venta...');
      print('Cliente ID: ${_ventaModel.clieId}');
      print('Vendedor ID: ${_ventaModel.vendId}');
      print('Productos: ${_ventaModel.detallesFacturaInput.length}');
      print('Detalles de productos:');
      for (var detalle in _ventaModel.detallesFacturaInput) {
        print('  - Producto ID: ${detalle.prodId}, Cantidad: ${detalle.faDeCantidad}');
      }
      
      // Enviar venta al backend
      print('Enviando datos al servidor...');
      final resultado = await _ventaService.insertarFacturaConValidacion(_ventaModel);
      
      // Cerrar indicador de carga
      if (Navigator.canPop(loadingContext)) {
        Navigator.of(loadingContext, rootNavigator: true).pop();
      }
      
      print('Respuesta del servidor: $resultado');
      
      if (resultado?['success'] == true) {
        // Venta exitosa
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("¡Venta Exitosa!", style: TextStyle(fontFamily: 'Satoshi', color: Color(0xFF98BF4A))),
            content: Text(
              "La venta ha sido procesada correctamente.\n\n"
              "Método de Pago: ${formData.metodoPago}\n"
              "Número de Factura: ${_ventaModel.factNumero}",
              style: const TextStyle(fontFamily: 'Satoshi'),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    child: const Text("Aceptar", style: TextStyle(fontFamily: 'Satoshi')),
                    onPressed: () {
                      Navigator.pop(context);
                      _resetearFormulario();
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF98BF4A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Ver Factura", style: TextStyle(fontFamily: 'Satoshi')),
                    onPressed: () {
                      Navigator.pop(context);
                      _mostrarFactura(resultado!['data']);
                      _resetearFormulario();
                    },
                  ),
                ],
              )
            ],
          ),
        );
      } else {
        // Error en la venta
      String errorMessage = 'Error desconocido';
      if (resultado != null) {
        errorMessage = resultado['message'] ?? 
                     resultado['details'] ?? 
                     'Error al procesar la venta (${resultado['statusCode'] ?? 'sin código'})';
      }
      
      print('Error al procesar venta: $errorMessage');
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error en la Venta", style: TextStyle(fontFamily: 'Satoshi', color: Colors.red)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("No se pudo procesar la venta:", style: TextStyle(fontFamily: 'Satoshi')),
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: const TextStyle(fontFamily: 'Satoshi', color: Colors.red),
                ),
                const SizedBox(height: 10),
                if (resultado?['details'] != null)
                  Text(
                    'Detalles: ${resultado!['details']}',
                    style: const TextStyle(fontFamily: 'Satoshi', fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cerrar", style: TextStyle(fontFamily: 'Satoshi')),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      }
    } catch (e, stackTrace) {
      print('Excepción al procesar venta: $e');
      print('Stack trace: $stackTrace');
      
      // Cerrar indicador de carga si está abierto
      if (Navigator.canPop(loadingContext)) {
        Navigator.of(loadingContext, rootNavigator: true).pop();
      }
      
      // Mostrar error al usuario
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error", style: TextStyle(fontFamily: 'Satoshi', color: Colors.red)),
          content: Text(
            'Error al procesar la venta: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Satoshi'),
          ),
          actions: [
            TextButton(
              child: const Text("Cerrar", style: TextStyle(fontFamily: 'Satoshi')),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      
      // Mostrar error
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error", style: TextStyle(fontFamily: 'Satoshi', color: Colors.red)),
          content: Text(
            "Ocurrió un error inesperado:\n\n$e",
            style: const TextStyle(fontFamily: 'Satoshi'),
          ),
          actions: [
            TextButton(
              child: const Text("Cerrar", style: TextStyle(fontFamily: 'Satoshi')),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _resetearFormulario() {
    setState(() {
      currentStep = 0;
      formData.metodoPago = '';
      formData.datosCliente = '';
      formData.productos = '';
      formData.confirmacion = false;
      _selectedProducts.clear();
      _ventaModel = VentaInsertarViewModel.empty();
      _pageController.jumpToPage(0);
    });
  }

  void _mostrarFactura(Map<String, dynamic> facturaData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Factura de Venta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'N° ${facturaData['fact_Numero'] ?? _ventaModel.factNumero}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Satoshi',
                ),
              ),
              const Divider(thickness: 1, height: 30),
              
              // Información de la factura
              _buildFacturaInfoRow('Fecha', _ventaModel.factFechaEmision.toString().substring(0, 10)),
              _buildFacturaInfoRow('Cliente', facturaData['clie_Nombres'] ?? 'Consumidor Final'),
              _buildFacturaInfoRow('Vendedor', facturaData['vend_Nombres'] ?? 'Sistema'),
              
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detalles de la compra',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Lista de productos
              if (_ventaModel.detallesFacturaInput.isNotEmpty)
                ..._ventaModel.detallesFacturaInput.map((detalle) {
                  final producto = _allProducts.firstWhere(
                    (p) => p.prod_Id == detalle.prodId,
                    orElse: () => Productos(
                      prod_Id: 0,
                      prod_Descripcion: 'Producto no encontrado',
                      marc_Id: 0,
                      cate_Id: 0,
                      subc_Id: 0,
                      prov_Id: 0,
                      impu_Id: 0,
                      prod_PrecioUnitario: 0,
                      prod_CostoTotal: 0,
                      prod_PromODesc: 0,
                      usua_Creacion: 0,
                      prod_FechaCreacion: DateTime.now(),
                      usua_Modificacion: 0,
                      prod_FechaModificacion: DateTime.now(),
                      prod_Estado: true,
                    ),
                  );
                  return _buildProductoItem(
                    producto.prod_Descripcion ?? 'Producto',
                    detalle.faDeCantidad,
                    producto.prod_PrecioUnitario ?? 0.0, // Default to 0.0 if null
                  );
                }).toList(),
              
              const Divider(thickness: 1, height: 30),
              
              // Totales
              // Calculate and show totals
              Builder(
                builder: (context) {
                  final subtotal = _calculateSubtotal();
                  final impuestos = _calculateTaxes(subtotal);
                  final total = subtotal + impuestos;
                  
                  return Column(
                    children: [
                      _buildTotalRow('Subtotal', subtotal.toStringAsFixed(2)),
                      _buildTotalRow('Impuestos', impuestos.toStringAsFixed(2)),
                      _buildTotalRow(
                        'Total',
                        total.toStringAsFixed(2),
                        isTotal: true,
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Aquí podrías implementar la generación de PDF o compartir
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF98BF4A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Compartir o Guardar PDF',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacturaInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  // Calculate subtotal from selected products
  double _calculateSubtotal() {
    return _ventaModel.detallesFacturaInput.fold(
      0.0, 
      (sum, detalle) {
        final producto = _allProducts.firstWhere(
          (p) => p.prod_Id == detalle.prodId,
          orElse: () => Productos(
            prod_Id: 0,
            prod_Descripcion: 'Producto no encontrado',
            marc_Id: 0,
            cate_Id: 0,
            subc_Id: 0,
            prov_Id: 0,
            impu_Id: 0,
            prod_PrecioUnitario: 0,
            prod_CostoTotal: 0,
            prod_PromODesc: 0,
            usua_Creacion: 0,
            prod_FechaCreacion: DateTime.now(),
            usua_Modificacion: 0,
            prod_FechaModificacion: DateTime.now(),
            prod_Estado: true,
          ),
        );
        return sum + (detalle.faDeCantidad * (producto.prod_PrecioUnitario ?? 0));
      },
    );
  }
  
  // Calculate taxes (15%)
  double _calculateTaxes(double subtotal) {
    return subtotal * 0.15;
  }

  // Método para construir un ítem de producto en la factura
  Widget _buildProductoItem(String nombre, double cantidad, double precioUnitario) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              nombre,
              style: const TextStyle(
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              cantidad.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              'L. ${precioUnitario.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
            ),
          ),
          Text(
            'L. $value',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? const Color(0xFF98BF4A) : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = (currentStep + 1) / totalSteps;

    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(permisos: []),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F6F6), Color(0xFFF6F6F6)],
          ),
        ),
        child: Column(
          children: [
            // Header con título y chip de paso
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Título
                  Expanded(
                    child: Text(
                      stepTitles[currentStep],
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF141A2F),
                      ),
                    ),
                  ),
                  // Chip de paso
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color.fromARGB(255, 4, 4, 27), Color.fromARGB(255, 18, 18, 53)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${currentStep + 1}/$totalSteps',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Barra de progreso moderna
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: MediaQuery.of(context).size.width * 0.85 * progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF262B40), Color.fromARGB(255, 21, 25, 39)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF262B40).withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Descripción del paso
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              alignment: Alignment.centerLeft,
              child: Text(
                stepDescriptions[currentStep],
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 16,
                  color: Color.fromARGB(255, 17, 19, 29)
                ),
                textAlign: TextAlign.left,
              ),
            ),
            
            // Contenido del paso
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  paso1(),
                  paso2(),
                  paso3(),
                  paso4(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ElevatedButton(
                    onPressed: prevStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF374151),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Atrás",
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: currentStep > 0 ? 1 : 2,
              child: Container(
                margin: EdgeInsets.only(left: currentStep > 0 ? 12 : 0),
                child: ElevatedButton(
                  onPressed: nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141A2F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    currentStep == totalSteps - 1 ? "Finalizar Venta" : "Siguiente",
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Paso 1: Método de Pago
  Widget paso1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Selecciona el método de pago:',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 24),
          _buildPaymentOption('Efectivo', Icons.money, 'EFECTIVO'),
          const SizedBox(height: 16),
          _buildPaymentOption('Crédito', Icons.credit_card, 'CREDITO')
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String title, IconData icon, String value) {
    bool isSelected = formData.metodoPago == value;
    return GestureDetector(
      onTap: () => setState(() {
        formData.metodoPago = value;
        _ventaModel.factTipoVenta = value;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF141A2F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF141A2F) : const Color(0xFFE5E7EB),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? const Color(0xFF141A2F).withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF98BF4A),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // Paso 2: Selección de Productos
  Widget paso2() {
    return Column(
      children: [
        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: const TextStyle(
                fontFamily: 'Satoshi',
                color: Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF141A2F), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontFamily: 'Satoshi'),
          ),
        ),
        // Contador de productos seleccionados
        if (_selectedProducts.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF98BF4A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF98BF4A).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Color(0xFF98BF4A), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_selectedProducts.length} productos seleccionados',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    color: Color(0xFF98BF4A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        // Lista de productos
        Expanded(
          child: _isLoadingProducts
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF141A2F)),
                )
              : _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron productos',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Productos product) {
    final currentQuantity = _selectedProducts[product.prod_Id] ?? 0;
    final isSelected = currentQuantity > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFD6B68A).withOpacity(0.1),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF98774A) : const Color(0xFF262B40).withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? const Color(0xFF98774A).withOpacity(0.2)
                : const Color(0xFF262B40).withOpacity(0.08),
            blurRadius: isSelected ? 12 : 8,
            offset: Offset(0, isSelected ? 4 : 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen del producto con mejor diseño
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF262B40).withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF262B40).withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: product.prod_Imagen != null && product.prod_Imagen!.isNotEmpty
                              ? Image.network(
                                  product.prod_Imagen!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFFD6B68A).withOpacity(0.2),
                                              const Color(0xFF98774A).withOpacity(0.1),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Color(0xFF98774A),
                                          size: 28,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFD6B68A).withOpacity(0.2),
                                        const Color(0xFF98774A).withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Color(0xFF98774A),
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Información del producto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.prod_DescripcionCorta ?? 'Sin descripción',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? const Color(0xFF262B40) : const Color(0xFF262B40),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (product.prod_Codigo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262B40).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'COD: ${product.prod_Codigo}',
                                  style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF262B40),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            // Precio limpio y simple
                            Row(
                              children: [
                                Text(
                                  'L ',
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF262B40).withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  product.prod_PrecioUnitario.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF98774A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Controles de cantidad mejorados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón de deseleccionar cuando está seleccionado
                      if (isSelected)
                        GestureDetector(
                          onTap: () => _updateProductQuantity(product.prod_Id, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE74C3C).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.remove_circle_outline,
                                  color: Color(0xFFE74C3C),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Quitar',
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 12,
                                    color: const Color(0xFFE74C3C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
                      // Controles de cantidad con mejor diseño
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF262B40).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFF262B40).withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: currentQuantity > 0 
                                    ? const Color(0xFF262B40) 
                                    : const Color(0xFF262B40).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: currentQuantity > 0
                                    ? () => _updateProductQuantity(product.prod_Id, currentQuantity - 1)
                                    : null,
                                icon: const Icon(Icons.remove, size: 18),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final TextEditingController controller = TextEditingController(
                                  text: currentQuantity.toInt().toString(),
                                );
                                
                                final result = await showDialog<double>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Cantidad', style: TextStyle(fontFamily: 'Satoshi')),
                                    content: TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        hintText: 'Ingrese la cantidad',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) {
                                        final value = double.tryParse(controller.text) ?? 0;
                                        Navigator.of(context).pop(value);
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancelar', style: TextStyle(fontFamily: 'Satoshi')),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final value = double.tryParse(controller.text) ?? 0;
                                          Navigator.of(context).pop(value);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF98774A),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Aceptar', style: TextStyle(fontFamily: 'Satoshi')),
                                      ),
                                    ],
                                  ),
                                );

                                if (result != null && result >= 0) {
                                  _updateProductQuantity(product.prod_Id, result);
                                }
                              },
                              child: Container(
                                width: 50,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFFD6B68A).withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    currentQuantity.toInt().toString(),
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFF262B40) : const Color(0xFF262B40).withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF98774A),
                                    const Color(0xFFD6B68A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF98774A).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => _updateProductQuantity(product.prod_Id, currentQuantity + 1),
                                icon: const Icon(Icons.add, size: 18),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Indicador visual de selección en la esquina
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF98774A),
                        const Color(0xFFD6B68A),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Paso 3: Carrito de Compras
  Widget paso3() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Título del carrito
          const Text(
            'Carrito de Compras',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF141A2F),
            ),
          ),
          const SizedBox(height: 16),
          
          // Lista de productos seleccionados
          Expanded(
            child: _selectedProducts.isEmpty
                ? _buildEmptyCart()
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: _selectedProducts.length,
                          itemBuilder: (context, index) {
                            final prodId = _selectedProducts.keys.elementAt(index);
                            final cantidad = _selectedProducts[prodId]!;
                            final product = _allProducts.firstWhere(
                              (p) => p.prod_Id == prodId,
                            );
                            return _buildCartItem(product, cantidad);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCartSummary(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Widget para carrito vacío
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Regresa al paso anterior para seleccionar productos',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget para cada item del carrito
  Widget _buildCartItem(Productos product, double cantidad) {
    final precio = product.prod_PrecioUnitario;
    final subtotal = precio * cantidad;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen del producto (placeholder)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF6B7280),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Información del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.prod_DescripcionCorta ?? 'Producto sin nombre',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141A2F),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: ${product.prod_Codigo ?? 'N/A'}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'L. ${precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const Text(
                      ' × ',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      cantidad.toString(),
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Controles de cantidad y subtotal
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'L. ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A2F),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón disminuir cantidad
                  GestureDetector(
                    onTap: () {
                      if (cantidad > 1) {
                        _updateProductQuantity(product.prod_Id, cantidad - 1);
                      } else {
                        _updateProductQuantity(product.prod_Id, 0);
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.remove,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        cantidad.toInt().toString(),
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón aumentar cantidad
                  GestureDetector(
                    onTap: () {
                      _updateProductQuantity(product.prod_Id, cantidad + 1);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A2F),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para el resumen del carrito
  Widget _buildCartSummary() {
    double subtotal = 0.0;
    int totalItems = 0;
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere((p) => p.prod_Id == prodId);
      final precio = product.prod_PrecioUnitario;
      subtotal += precio * cantidad;
      totalItems += cantidad.toInt();
    });

    // TODO: Aquí se agregarán descuentos y promociones en el futuro
    final double descuentos = 0.0; // Placeholder para descuentos futuros
    final double impuestos = subtotal * 0.15; // ISV 15% (ejemplo)
    final double total = subtotal - descuentos + impuestos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resumen del Pedido',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A2F),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF98BF4A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalItems items',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF98BF4A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Subtotal
          _buildSummaryRowCart('Subtotal:', 'L. ${subtotal.toStringAsFixed(2)}'),
          
          // Descuentos (placeholder para futuro)
          if (descuentos > 0)
            _buildSummaryRowCart('Descuentos:', '- L. ${descuentos.toStringAsFixed(2)}', isDiscount: true),
          
          // Impuestos
          _buildSummaryRowCart('ISV (15%):', 'L. ${impuestos.toStringAsFixed(2)}'),
          
          const Divider(height: 24, thickness: 1, color: Color(0xFFE5E7EB)),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A2F),
                ),
              ),
              Text(
                'L. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF98BF4A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper para las filas del resumen
  Widget _buildSummaryRowCart(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDiscount ? const Color(0xFF10B981) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  // Paso 4: Confirmación de Venta
  Widget paso4() {
    // Calcular totales para mostrar en la confirmación
    double subtotal = 0.0;
    int totalItems = 0;
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere((p) => p.prod_Id == prodId);
      final precio = product.prod_PrecioUnitario;
      subtotal += precio * cantidad;
      totalItems += cantidad.toInt();
    });

    final double impuestos = subtotal * 0.15; // ISV 15%
    final double total = subtotal + impuestos;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Título de confirmación
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF98BF4A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF98BF4A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Confirmar Venta',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Información de pago
                  _buildConfirmationSection(
                    'Método de Pago',
                    Icons.payment,
                    [
                      _buildConfirmationRow('Forma de pago:', formData.metodoPago.isEmpty ? 'No especificado' : formData.metodoPago),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Información del cliente
                  _buildConfirmationSection(
                    'Información del Cliente',
                    Icons.person_outline,
                    [
                      _buildConfirmationRow('Cliente:', formData.datosCliente.isEmpty ? 'Cliente general' : formData.datosCliente),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Resumen de productos
                  _buildProductsConfirmationSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Resumen financiero
                  _buildFinancialSummary(subtotal, impuestos, total, totalItems),
                  
                  const SizedBox(height: 24),
                  
                  // Checkbox de confirmación
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF98BF4A).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF98BF4A).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: formData.confirmacion,
                          onChanged: (value) => setState(() => formData.confirmacion = value ?? false),
                          activeColor: const Color(0xFF98BF4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'He revisado toda la información y confirmo que es correcta. Proceder con la venta.',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para secciones de confirmación
  Widget _buildConfirmationSection(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF141A2F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Widget para productos en confirmación
  Widget _buildProductsConfirmationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFF141A2F),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Productos Seleccionados',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF141A2F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF98BF4A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedProducts.length} productos',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF98BF4A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Lista de productos
          ..._selectedProducts.entries.map((entry) {
            final prodId = entry.key;
            final cantidad = entry.value;
            final product = _allProducts.firstWhere((p) => p.prod_Id == prodId);
            final precio = product.prod_PrecioUnitario;
            final subtotal = precio * cantidad;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.prod_DescripcionCorta ?? 'Producto sin nombre',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Código: ${product.prod_Codigo ?? 'N/A'}',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'L. ${precio.toStringAsFixed(2)} × ${cantidad.toInt()}',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'L. ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF141A2F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Widget para resumen financiero
  Widget _buildFinancialSummary(double subtotal, double impuestos, double total, int totalItems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF141A2F),
            const Color(0xFF141A2F).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141A2F).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Resumen de Facturación',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF98BF4A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalItems items',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildFinancialRow('Subtotal:', 'L. ${subtotal.toStringAsFixed(2)}'),
          _buildFinancialRow('ISV (15%):', 'L. ${impuestos.toStringAsFixed(2)}'),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24, thickness: 1),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total a Pagar:',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'L. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF98BF4A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper para filas financieras
  Widget _buildFinancialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Helper para filas de confirmación
  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
