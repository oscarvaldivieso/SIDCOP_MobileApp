import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/general/clientes/client_screen.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/ui/widgets/drawer.dart';
import 'package:sidcop_mobile/models/ventas/VentaInsertarViewModel.dart';
import 'package:sidcop_mobile/services/ProductosService.dart';
import 'package:sidcop_mobile/models/ventas/ProductosDescuentoViewModel.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/utils/error_handler.dart';
import 'dart:math';
import 'package:sidcop_mobile/ui/screens/venta/invoice_detail_screen.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/Offline_Services/Ventas_OfflineService.dart';

// Modelo centralizado para los datos
class FormData {
  String metodoPago = '';
  String datosCliente = '';
  String productos = '';
  bool confirmacion = false;
}

class VentaScreen extends StatefulWidget {
  final int? clienteId;
  final int? vendedorId;
  
  const VentaScreen({super.key, this.clienteId, this.vendedorId});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final PageController _pageController = PageController();
  final FormData formData = FormData();
  final VentaService _ventaService = VentaService();
  final ProductosService _productosService = ProductosService();
  final ClientesService _clientesService = ClientesService();
final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();
  final CuentasXCobrarService _cuentasService = CuentasXCobrarService();
  late VentaInsertarViewModel _ventaModel;
  
  // Variables para control de crédito
  bool _verificandoCredito = false;
  bool _tieneCredito = true; // Asumimos que tiene crédito por defecto hasta que se verifique lo contrario
  double _creditoDisponible = 0.0;
  double _limiteCredito = 0.0;
  double _saldoActual = 0.0;
  
  // Genera un número de factura aleatorio
  String _generateInvoiceNumber() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomDigits = 100000 + random.nextInt(900000); // Número de 6 dígitos
    return 'FACT-${timestamp}_$randomDigits';
  }
  
  // Método para construir una fila de información de crédito
  Widget _buildCreditInfoRow(String label, double amount, {bool isAvailable = false, bool isBalance = false}) {
    final bool isNegative = amount < 0;
    final bool isHighlight = isAvailable || isBalance;
    
    Color textColor = const Color(0xFF262B40);
    if (isAvailable) {
      textColor = const Color.fromARGB(255, 237, 211, 175); // Color dorado para crédito disponible
    } else if (isBalance && amount > 0) {
      textColor = const Color(0xFFE53E3E); // Rojo para saldo a favor
    } else if (isBalance && isNegative) {
      textColor = const Color(0xFF98BF4A); // Verde para saldo negativo (a favor del cliente)
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isHighlight ? const Color.fromARGB(255, 46, 60, 92) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'L. ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 15,
                color: textColor,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Variables para control de venta
  bool _isProcessingSale = false;

  // Variables para direcciones del cliente
  List<dynamic> _clientAddresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddresses = false;
  
  // Variables para productos
  List<ProductoConDescuento> _allProducts = [];
  List<ProductoConDescuento> _filteredProducts = [];
  Map<int, ProductoConDescuento> _productosConDescuento = {};
  final Map<int, double> _selectedProducts = {}; // prod_Id -> cantidad
  bool _isLoadingProducts = false;
  bool _isCartSummaryExpanded = false;
  final TextEditingController _searchController = TextEditingController();



  int currentStep = 0;
  final int totalSteps = 4;
  
  final List<String> stepTitles = [
    'Método de Pago',
    'Productos disponibles',
    'Carrito de compras',
    'Confirmación de venta'
  ];
  
  final List<String> stepDescriptions = [
    'Selecciona el método de pago con el cual el cliente cancelará la venta',
    'Selecciona los productos que tienes disponibles en tu inventario',
    'Confirma los productos que deseas vender',
    'Revisa y confirma la información'
  ];

  // Cargar direcciones del cliente
  Future<void> _loadClientAddresses() async {
    if (widget.clienteId == null) return;
    
    setState(() => _isLoadingAddresses = true);
    try {
      _clientAddresses = await _clientesService.getDireccionesCliente(widget.clienteId!);
      
      // Seleccionar la primera dirección por defecto si hay direcciones disponibles
      if (_clientAddresses.isNotEmpty) {
        _selectedAddress = _clientAddresses.first;
        _ventaModel.diClId = _selectedAddress!['diCl_Id'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error cargando direcciones: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }
  
  @override
  void initState() {
    super.initState();
    _ventaModel = VentaInsertarViewModel.empty()
      ..factNumero = _generateInvoiceNumber()
      ..vendId = widget.vendedorId ?? 0;
      
    _loadProducts();
    _verificarCreditoCliente();
    _loadClientAddresses();
    _searchController.addListener(_applyProductFilter);
    
    // Debug print to verify the values
    debugPrint('VentaScreen initialized with clieId: ${widget.clienteId}, vendId: ${widget.vendedorId}');

    // Verificar crédito al iniciar si ya hay un cliente seleccionado
    if (widget.clienteId != null) {
      _verificarCreditoCliente();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (widget.clienteId == null || widget.vendedorId == null) {
      ErrorHandler.showErrorToast('No se pudo cargar los productos: Faltan datos del cliente o vendedor');
      setState(() => _isLoadingProducts = false);
      return;
    }

    setState(() => _isLoadingProducts = true);

    try {
      final hasConnection = await SyncService.hasInternetConnection();

      if (hasConnection) {
        _allProducts = await _productosService.getProductosConDescuentoPorClienteVendedor(
          widget.clienteId!,
          widget.vendedorId!,
        );
      } else {
        _allProducts = await VentasOfflineService.cargarProductosConDescuentoOffline(
          1158,
          13,
        );
        if (_allProducts.isEmpty) {
          ErrorHandler.showErrorToast('No hay productos disponibles offline');
        }
      }

      _allProducts.sort((a, b) {
        if (a.prod_Impulsado == b.prod_Impulsado) return 0;
        return a.prod_Impulsado ? -1 : 1;
      });

      _filteredProducts = List.from(_allProducts);

      _productosConDescuento.clear();
      for (var producto in _allProducts) {
        _productosConDescuento[producto.prodId] = producto;
      }

      debugPrint('Productos cargados con descuentos: ${_allProducts.length}');
    } catch (e) {
      debugPrint('Error cargando productos con descuento: $e');
      ErrorHandler.showErrorToast('Error al cargar productos con descuentos');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _applyProductFilter() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesSearch = searchTerm.isEmpty ||
            (product.prodDescripcionCorta?.toLowerCase().contains(searchTerm) ?? false) ||
            (product.prodId.toString().toLowerCase().contains(searchTerm) ?? false);
        return matchesSearch;
      }).toList();
    });
  }

  void _updateProductQuantity(int prodId, double quantity) {
    final product = _allProducts.firstWhere(
      (p) => p.prodId == prodId,
      orElse: () => throw Exception('Producto no encontrado'),
    );

    // Verificar si la cantidad solicitada excede el stock disponible
    if (quantity > 0 && product.cantidadDisponible != null && quantity > product.cantidadDisponible!) {
      // Mostrar mensaje de error al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay suficiente stock. Disponible: ${product.cantidadDisponible}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

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
      final product = _allProducts.firstWhere((p) => p.prodId == entry.key);
      return '${product.prodDescripcionCorta ?? 'Producto'} (${entry.value})';
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
    ErrorHandler.showErrorToast(mensaje);
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

  // Formatear moneda
  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount);
  }

  Future<void> _procesarVenta() async {
    // Validar crédito si el método de pago es CRÉDITO
    if (formData.metodoPago == 'CREDITO' && widget.clienteId != null) {
      final totalVenta = _calculateTotal();
      if (totalVenta > _creditoDisponible) {
        if (mounted) {
          ErrorHandler.showErrorToast(
            'El monto total de la venta (${_formatCurrency(totalVenta)}) excede el crédito disponible (${_formatCurrency(_creditoDisponible)})'
          );
        }
        return;
      }
    }

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
      
      // Generar un nuevo número de factura único
      final newInvoiceNumber = _generateInvoiceNumber();
      print('Nuevo número de factura generado: $newInvoiceNumber');
      
      // Asignar el número de factura al modelo
      _ventaModel.factNumero = newInvoiceNumber;
      _ventaModel.factTipoDeDocumento = "01";
      _ventaModel.regCId = 21;
      _ventaModel.factFechaEmision = DateTime.now();
      _ventaModel.factReferencia = "Venta desde app móvil";
      _ventaModel.factLatitud = 14.072245;
      _ventaModel.factLongitud = -88.212665;
      _ventaModel.factAutorizadoPor = "Sistema";
      
      // Obtener datos del usuario actual
      final userData = await _perfilUsuarioService.obtenerDatosUsuario();
      final personaId = userData?['personaId'] ?? userData?['usua_IdPersona'];
      
      if (personaId == null) {
        throw Exception('No se pudo obtener el ID del vendedor de la sesión');
      }
      
      
      _ventaModel.vendId = personaId is int ? personaId : int.tryParse(personaId.toString()) ?? 12;
      //_ventaModel.vendId = 12;
      _ventaModel.usuaCreacion = 1; // Usar el mismo ID para el usuario que crea la venta
      
      // Validar el modelo antes de enviar
      print('Validando modelo de venta...');
      print('Direccion por cliente ID: ${_ventaModel.diClId}');
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
        // Venta exitosa - mostrar toast y dialog
        ErrorHandler.showSuccessToast('¡Venta procesada exitosamente!');
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildModernSuccessDialog(context, resultado!['data']),
        );
      } else {
        // Error en la venta - usar toast en lugar de dialog
        ErrorHandler.handleBackendError(resultado, fallbackMessage: 'Error al procesar la venta');
        print('Error al procesar venta: $resultado');
      }
    } catch (e, stackTrace) {
      print('Excepción al procesar venta: $e');
      print('Stack trace: $stackTrace');
      
      // Cerrar indicador de carga si está abierto
      if (Navigator.canPop(loadingContext)) {
        Navigator.of(loadingContext, rootNavigator: true).pop();
      }
      
      // Mostrar error al usuario con toast
      ErrorHandler.showErrorToast('Error inesperado al procesar la venta. Intenta nuevamente.');
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

  Widget _buildModernSuccessDialog(BuildContext context, Map<String, dynamic> facturaData) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500), // Limitar altura máxima
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
            // Header compacto
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
                  // Icono más pequeño
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
                    '¡Venta Exitosa!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Venta procesada correctamente',
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
            
            // Contenido compacto
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
                          _buildCompactDetailRow('Pago', formData.metodoPago.isNotEmpty ? formData.metodoPago : 'Efectivo'),
                          _buildCompactDetailRow('Productos', '${_selectedProducts.length} artículos'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Botones compactos
                    Row(
                      children: [
                        // Botón Aceptar
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => clientScreen()));
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF141A2F)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Aceptar',
                                style: TextStyle(
                                  fontSize: 14,
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
                                _navigateToInvoiceDetail(facturaData);
                                _resetearFormulario();
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
                                      fontSize: 14,
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

  void _navigateToInvoiceDetail(Map<String, dynamic> facturaData) {
    // Extract invoice ID from the backend response
    int? facturaId;
    
    // Intentar extraer el ID del message_Status
    if (facturaData['message_Status'] != null) {
      facturaId = _extractInvoiceIdFromMessage(facturaData['message_Status']);
      print('ID extraído del message_Status: $facturaId');
    }
    
    // Fallback: intentar obtener de otros campos
    // Fallback: intentar obtener de otros campos
    if (facturaId == null) {
      facturaId = facturaData['fact_Id'] ?? facturaData['id'];
    }
    
    final facturaNumero = _ventaModel.factNumero ?? 'N/A';
    
    print('Navegando a InvoiceDetailScreen con ID: $facturaId, Número: $facturaNumero');
    
    // Navigate to InvoiceDetailScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(
          facturaId: facturaId ?? 0,
          facturaNumero: facturaNumero,
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
  // Obtiene el precio basado en la cantidad y las listas de precios
  double _getPrecioPorCantidad(ProductoConDescuento product, double cantidad, {bool isCredito = false}) {
    // Si no hay listas de precios, retornar el precio unitario
    if (product.listasPrecio.isEmpty) {
      return product.prodPrecioUnitario;
    }
    
    // Buscar la lista de precios que aplique a la cantidad
    for (var lista in product.listasPrecio) {
      if (cantidad >= lista.prePInicioEscala && 
          cantidad <= lista.prePFinEscala) {
        return isCredito ? lista.prePPrecioCredito : lista.prePPrecioContado;
      }
    }
    
    // Si no se encuentra en ninguna escala, retornar el precio unitario
    return product.prodPrecioUnitario;
  }

  double _calculateSubtotal() {
    return _ventaModel.detallesFacturaInput.fold(
      0.0, 
      (sum, detalle) {
        final producto = _productosConDescuento[detalle.prodId];
        if (producto != null) {
          final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
          return sum + (detalle.faDeCantidad * _getPrecioPorCantidad(producto, detalle.faDeCantidad, isCredito: isCredito));
        }
        return sum;
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Título
                  Expanded(
                    child: Text(
                      stepTitles[currentStep],
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF141A2F),
                      ),
                    ),
                  ),
                  // Chip de paso
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical:6),
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
                        fontSize: 14,
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
              padding: const EdgeInsets.all(3),
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
                  fontSize: 14,
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
                  onPressed: _isProcessingSale ? null : (currentStep == totalSteps - 1 ? _procesarVentaConImpresion : nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF141A2F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessingSale && currentStep == totalSteps - 1
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Procesando...",
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
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
  return SingleChildScrollView(
    child: Padding(
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
          _buildPaymentOption('Contado', Icons.money, 'EFECTIVO'),
          const SizedBox(height: 16),
          Opacity(
            opacity: _tieneCredito ? 1.0 : 0.6,
            child: AbsorbPointer(
              absorbing: !_tieneCredito,
              child: _buildPaymentOption('Crédito', Icons.credit_card, 'CREDITO'),
            ),
          ),
          if (!_tieneCredito && widget.clienteId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0),
              child: Text(
                'Crédito no disponible para este cliente',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 13,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          if (_verificandoCredito) 
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: CircularProgressIndicator(),
            )
          else if (formData.metodoPago == 'CREDITO' && widget.clienteId != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF262B40).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF262B40).withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262B40).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.credit_card_rounded,
                            color: Color(0xFF262B40),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Información de Crédito',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF262B40),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCreditInfoRow('Límite de Crédito', _limiteCredito),
                        const SizedBox(height: 4),
                        _buildCreditInfoRow('Saldo Actual', _saldoActual, isBalance: true),
                        const SizedBox(height: 12),
                        _buildCreditInfoRow(
                          'Crédito Disponible', 
                          _creditoDisponible,
                          isAvailable: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

  Future<void> _verificarCreditoCliente() async {
    if (widget.clienteId == null) return;
    
    setState(() => _verificandoCredito = true);
    
    try {
      final creditInfo = await _cuentasService.getClienteCreditInfo(widget.clienteId!);
      
      final limiteCredito = (creditInfo['limiteCredito'] as num?)?.toDouble() ?? 0.0;
      final saldoActual = (creditInfo['saldoActual'] as num?)?.toDouble() ?? 0.0;
      final creditoDisponible = (creditInfo['creditoDisponible'] as num?)?.toDouble() ?? 0.0;
      
      setState(() {
        _limiteCredito = limiteCredito;
        _saldoActual = saldoActual;
        _creditoDisponible = creditoDisponible;
        _tieneCredito = creditoDisponible > 0;
      });
      
      // Si no hay crédito disponible, volver a efectivo
      if (!_tieneCredito) {
        setState(() {
          formData.metodoPago = 'EFECTIVO';
          _ventaModel.factTipoVenta = 'CO'; // CO for Efectivo
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar crédito: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // En caso de error, asumimos que no tiene crédito
      setState(() {
        _tieneCredito = false;
        formData.metodoPago = 'EFECTIVO';
        _ventaModel.factTipoVenta = 'CO'; // CO for Efectivo
      });
    } finally {
      if (mounted) {
        setState(() => _verificandoCredito = false);
      }
    }
  }
  

  Widget _buildPaymentOption(String title, IconData icon, String value) {
    bool isSelected = formData.metodoPago == value;
    bool isCredit = value == 'CREDITO';
    
    return GestureDetector(
      onTap: () async {
        setState(() {
          formData.metodoPago = value;
          // Convert to the correct format for the API
          _ventaModel.factTipoVenta = value == 'CREDITO' ? 'CR' : 'CO';
        });
        
        if (isCredit && widget.clienteId != null) {
          await _verificarCreditoCliente();
        }
      },
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
          padding: const EdgeInsets.all(13),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: const TextStyle(
                fontSize: 14,
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
            margin: const EdgeInsets.symmetric(horizontal: 14),
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
                    fontSize: 14,
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

  Widget _buildProductCard(ProductoConDescuento product) {
    final currentQuantity = _selectedProducts[product.prodId] ?? 0;
    final isSelected = currentQuantity > 0;
    final productoConDescuento = _productosConDescuento[product.prodId];
    final isImpulsado = product.prod_Impulsado ?? false;
    
    // Obtener el mejor descuento disponible
    double? mejorDescuento;
    if (productoConDescuento?.descuentosEscala.isNotEmpty ?? false) {
      mejorDescuento = productoConDescuento!.descuentosEscala
          .map((d) => d.deEsValor)
          .reduce((a, b) => a > b ? a : b);
    }

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF98774A) : const Color(0xFF262B40).withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? const Color(0xFF98774A).withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 12 : 10,
            offset: Offset(0, isSelected ? 4 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (isImpulsado)
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(171, 75, 212, 86),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer, size: 14, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        '¡IMPULSADO!',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                          )
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: product.prodImagen != null && product.prodImagen!.isNotEmpty
                              ? Image.network(
                                  product.prodImagen!,
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    product.prodDescripcionCorta,
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Color(0xFF262B40) : Color(0xFF262B40),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mejorDescuento != null && mejorDescuento > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF98BF4A).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '% OFF',
                                      style: const TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F4B3F),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Stock disponible
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: product.cantidadDisponible > 0 
                                    ? const Color(0xFFE8F5E9) 
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: product.cantidadDisponible > 0 
                                      ? const Color(0xFF98BF4A).withOpacity(0.3) 
                                      : const Color(0xFFEF5350).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    product.cantidadDisponible > 0 
                                        ? Icons.inventory_2_outlined 
                                        : Icons.error_outline,
                                    size: 14,
                                    color: product.cantidadDisponible > 0 
                                        ? const Color(0xFF2E7D32) 
                                        : const Color(0xFFD32F2F),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.cantidadDisponible > 0 
                                        ? '${product.cantidadDisponible.toInt()} disponibles' 
                                        : 'Sin existencias',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: product.cantidadDisponible > 0 
                                          ? const Color(0xFF2E7D32) 
                                          : const Color(0xFFD32F2F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Mostrar precio con descuento si aplica
                                if (mejorDescuento != null && mejorDescuento > 0) ...[
                                  // Precio tachado (precio base)
                                  Text(
                                    'L. ${product.prodPrecioUnitario.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFEF4444),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Color(0xFFEF4444),
                                      decorationThickness: 2.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Precio con descuento aplicado
                                  Text(
                                    'L. ${(product.prodPrecioUnitario * (1 - (mejorDescuento / 100))).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A2F),
                                    ),
                                  ),
                                ] else ...[
                                  // Mostrar precio según la cantidad seleccionada (si hay cantidad)
                                  Builder(
                                    builder: (context) {
                                      final cantidad = _selectedProducts[product.prodId] ?? 1.0;
                                      final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
                                      final precio = _getPrecioPorCantidad(product, cantidad, isCredito: isCredito);
                                      
                                      // Si el precio es diferente al precio unitario, mostramos ambos
                                      if (precio != product.prodPrecioUnitario) {
                                        return Row(
                                          children: [
                                            Text(
                                              'L. ${product.prodPrecioUnitario.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF6B7280),
                                                decoration: TextDecoration.lineThrough,
                                                decorationColor: Color(0xFF6B7280),
                                                decorationThickness: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'L. ${precio.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF141A2F),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      
                                      // Si el precio es igual al unitario, mostramos solo uno
                                      return Text(
                                        'L. ${precio.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF141A2F),
                                        ),
                                      );
                                    },
                                  ),
                                ]
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
                          onTap: () => _updateProductQuantity(product.prodId, 0),
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
                            color: isSelected ? const Color(0xFF98774A) : const Color(0xFF262B40).withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: currentQuantity > 0 
                                    ? const Color(0xFF262B40) 
                                    : const Color(0xFF262B40).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                onPressed: currentQuantity > 0
                                    ? () => _updateProductQuantity(product.prodId, currentQuantity - 1)
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
                                  _updateProductQuantity(product.prodId, result);
                                }
                              },
                              child: Container(
                                width: 50,
                                height: 30,
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
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF98774A),
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
                                onPressed: () => _updateProductQuantity(product.prodId, currentQuantity + 1),
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
    final double total = _calculateTotal();
    
    return Stack(
      children: [
        // Contenido principal con padding inferior para el resumen colapsado
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // Lista de productos seleccionados
              Expanded(
                child: _selectedProducts.isEmpty
                    ? _buildEmptyCart()
                    : ListView.builder(
                        itemCount: _selectedProducts.length,
                        itemBuilder: (context, index) {
                          final prodId = _selectedProducts.keys.elementAt(index);
                          final cantidad = _selectedProducts[prodId]!;
                          final product = _allProducts.firstWhere(
                            (p) => p.prodId == prodId,
                          );
                          return _buildCartItem(product, cantidad);
                        },
                      ),
              ),
            ],
          ),
        ),
        
        // Resumen del carrito (fijo en la parte inferior)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            children: [
              // Línea decorativa superior
              Container(
                width: 60,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Contenedor del resumen
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCartSummaryExpanded = !_isCartSummaryExpanded;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Encabezado del resumen (siempre visible)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Resumen del pedido',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF141A2F),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'L. ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF141A2F),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isCartSummaryExpanded 
                                    ? Icons.keyboard_arrow_down 
                                    : Icons.keyboard_arrow_up,
                                color: const Color(0xFF98BF4A),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Contenido expandible
                      AnimatedCrossFade(
                        firstChild: const SizedBox(height: 16),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildCartSummary(),
                          ],
                        ),
                        crossFadeState: _isCartSummaryExpanded 
                            ? CrossFadeState.showSecond 
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
Widget _buildCartItem(ProductoConDescuento product, double cantidad) {
  // Obtener el precio según la cantidad y tipo de venta (crédito/contado)
  final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
  final precio = _getPrecioPorCantidad(product, cantidad, isCredito: isCredito);
  final subtotal = precio * cantidad;
  
  // Calcular descuentos para este producto
  double descuento = 0.0;
  double porcentajeDescuento = 0.0;
  if (product.descuentosEscala.isNotEmpty) {
    for (var desc in product.descuentosEscala) {
      if (cantidad >= desc.deEsInicioEscala && 
          (desc.deEsFinEscala == -1 || cantidad <= desc.deEsFinEscala)) {
        descuento = subtotal * (desc.deEsValor / 100);
        porcentajeDescuento = desc.deEsValor;
        break;
      }
    }
  }
  
  final subtotalConDescuento = subtotal - descuento;
  // Calcular impuesto solo si el producto paga impuesto (prodPagaImpuesto == 'S')
  final impuesto = product.prodPagaImpuesto == 'S' ? subtotalConDescuento * 0.15 : 0.0; // 15% ISV solo si paga impuesto
  final totalProducto = subtotalConDescuento + impuesto;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
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
      border: Border.all(
        color: const Color(0xFFF0F0F0),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con información del producto
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.prodDescripcionCorta ?? 'Producto sin nombre',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Código: ${product.prodId ?? 'N/A'}',
                      style: const TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Precio unitario y cantidad
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1),
                        ),
                        child: Text(
                          'L. ${precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '× ${cantidad.toStringAsFixed(cantidad.truncateToDouble() == cantidad ? 0 : 1)}',
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
            
            // Controles de cantidad
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón disminuir cantidad
                    GestureDetector(
                      onTap: () {
                        if (cantidad > 1) {
                          _updateProductQuantity(product.prodId, cantidad - 1);
                        } else {
                          _updateProductQuantity(product.prodId, 0);
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF141A2F), width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          cantidad.toInt().toString(),
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón aumentar cantidad
                    GestureDetector(
                      onTap: () {
                        _updateProductQuantity(product.prodId, cantidad + 1);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141A2F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 18,
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
        
        const SizedBox(height: 16), //WARD
        
        // Separador
        Container(
          height: 1,
          color: const Color(0xFFF0F0F0),
        ),
        
        const SizedBox(height: 16),
        
        // Sección de cálculos
        Column(
          children: [
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                Text(
                  'L. ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            
            // Descuento (si aplica)
            if (descuento > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Descuento (${porcentajeDescuento.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '-L. ${descuento.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 8),
            
            // ISV
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color(0xFF374151),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ISV (15%)',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                Text(
                  '+L. ${impuesto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Separador para el total
            Container(
              height: 1,
              color: const Color(0xFFE5E7EB),
            ),
            
            const SizedBox(height: 12),
            
            // Total del producto
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A2F),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Total producto',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF141A2F),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'L. ${totalProducto.toStringAsFixed(2)}',
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
          ],
        ),
      ], //WARD FINAL
    ),
  );
}

  // Método para calcular descuentos por escalas de cantidad
  Map<String, dynamic> _calculateDiscounts() {
    double totalDescuentos = 0.0;
    List<Map<String, dynamic>> detalleDescuentos = [];
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere(
        (p) => p.prodId == prodId,
      );
      
      // Buscar descuento aplicable según la cantidad
      DescuentoEscala? descuentoAplicable;
      for (var descuento in product.descuentosEscala) {
        if (cantidad >= descuento.deEsInicioEscala && 
            (descuento.deEsFinEscala == -1 || cantidad <= descuento.deEsFinEscala)) {
          descuentoAplicable = descuento;
          break;
        }
      }
      
      if (descuentoAplicable != null) {
        final precioOriginal = product.prodPrecioUnitario * cantidad;
        final descuentoValor = precioOriginal * (descuentoAplicable.deEsValor / 100);
        totalDescuentos += descuentoValor;
        
        detalleDescuentos.add({
          'producto': product.prodDescripcionCorta,
          'cantidad': cantidad,
          'porcentaje': descuentoAplicable.deEsValor,
          'valor': descuentoValor,
        });
      }
    });
    
    return {
      'total': totalDescuentos,
      'detalles': detalleDescuentos,
    };
  }

  // Calcular el total del carrito
  double _calculateTotal() {
    double subtotal = 0.0;
    double subtotalConImpuesto = 0.0;
    final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere(
        (p) => p.prodId == prodId,
      );
      final precio = _getPrecioPorCantidad(product, cantidad, isCredito: isCredito);
      final subtotalProducto = precio * cantidad;
      subtotal += subtotalProducto;
      
      // Calcular impuesto solo para productos que pagan impuesto
      if (product.prodPagaImpuesto == 'S') {
        subtotalConImpuesto += subtotalProducto;
      }
    });
    
    final descuentosInfo = _calculateDiscounts();
    final double descuentos = descuentosInfo['total'];
    final double subtotalConDescuento = subtotal - descuentos;
    
    // Aplicar impuesto solo a los productos que pagan impuesto
    final double impuestos = subtotalConImpuesto * 0.15;
    
    return subtotalConDescuento + impuestos;
  }

  // Widget para el resumen del carrito
  Widget _buildCartSummary() {
    double subtotal = 0.0;
    double subtotalConImpuesto = 0.0;
    int totalItems = 0;
    final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere(
        (p) => p.prodId == prodId,
      );
      final precio = _getPrecioPorCantidad(product, cantidad, isCredito: isCredito);
      final subtotalProducto = precio * cantidad;
      subtotal += subtotalProducto;
      totalItems += cantidad.toInt();
      
      // Calcular subtotal solo para productos que pagan impuesto
      if (product.prodPagaImpuesto == 'S') {
        subtotalConImpuesto += subtotalProducto;
      }
    });

    // Calcular descuentos reales
    final descuentosInfo = _calculateDiscounts();
    final double descuentos = descuentosInfo['total'];
    final List<Map<String, dynamic>> detalleDescuentos = descuentosInfo['detalles'];
    
    final double subtotalConDescuento = subtotal - descuentos;
    
    // Calcular impuesto solo sobre los productos que pagan impuesto
    final double porcentajeImpuesto = 0.15; // 15% ISV
    final double baseImponible = subtotalConImpuesto > 0 ? 
        (subtotalConImpuesto / subtotal) * subtotalConDescuento : 0.0;
    final double impuestos = baseImponible * porcentajeImpuesto;
    
    final double total = subtotalConDescuento + impuestos;

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
          
          // Descuentos aplicados
          if (descuentos > 0) ...[
            const SizedBox(height: 8),
            _buildDiscountSection(detalleDescuentos, descuentos),
            const SizedBox(height: 8),
          ],
          
          // Subtotal después de descuentos
          if (descuentos > 0)
            _buildSummaryRowCart('Subtotal c/descuento:', 'L. ${subtotalConDescuento.toStringAsFixed(2)}', isBold: true),
          
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

  // Widget para mostrar la sección de descuentos
  Widget _buildDiscountSection(List<Map<String, dynamic>> detalleDescuentos, double totalDescuentos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer,
                size: 16,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              const Text(
                'Descuentos Aplicados',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...detalleDescuentos.map((descuento) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${descuento['producto']} (${descuento['cantidad'].toInt()}x) - ${descuento['porcentaje']}%',
                    style: const TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '- L. ${descuento['valor'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          )).toList(),
          const Divider(height: 16, thickness: 1, color: Color(0xFFE5E7EB)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Descuentos:',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
              Text(
                '- L. ${totalDescuentos.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper para las filas del resumen
  Widget _buildSummaryRowCart(String label, String value, {bool isDiscount = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
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
    double subtotalConImpuesto = 0.0;
    int totalItems = 0;
    final isCredito = _ventaModel.factTipoVenta == 'CR' || _ventaModel.factTipoVenta == 'CREDITO';
    
    _selectedProducts.forEach((prodId, cantidad) {
      final product = _allProducts.firstWhere(
        (p) => p.prodId == prodId,
      );
      final precio = _getPrecioPorCantidad(product, cantidad, isCredito: isCredito);
      final subtotalProducto = precio * cantidad;
      subtotal += subtotalProducto;
      totalItems += cantidad.toInt();
      
      // Calcular subtotal solo para productos que pagan impuesto
      if (product.prodPagaImpuesto == 'S') {
        subtotalConImpuesto += subtotalProducto;
      }
    });

    // Calcular descuentos para la confirmación
    final descuentosInfo = _calculateDiscounts();
    final double descuentos = descuentosInfo['total'];
    
    final double subtotalConDescuento = subtotal - descuentos;
    
    // Calcular impuesto solo sobre los productos que pagan impuesto
    final double porcentajeImpuesto = 0.15; // 15% ISV
    final double baseImponible = subtotalConImpuesto > 0 ? 
        (subtotalConImpuesto / subtotal) * subtotalConDescuento : 0.0;
    final double impuestos = baseImponible * porcentajeImpuesto;
    
    final double total = subtotalConDescuento + impuestos;

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
                  
                  // Client Information Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF98BF4A).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: Color(0xFF98BF4A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Cliente',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Client Name
                        Text(
                          formData.datosCliente.isEmpty ? 'Cliente general' : formData.datosCliente,
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Delivery Address
                        const Text(
                          'Dirección de entrega',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        _isLoadingAddresses
                            ? const Center(child: CircularProgressIndicator())
                            : _clientAddresses.isEmpty
                                ? const Text(
                                    'No hay direcciones registradas',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      color: Colors.grey,
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<Map<String, dynamic>>(
                                        isExpanded: true,
                                        value: _selectedAddress,
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF98BF4A)),
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                        items: _clientAddresses.map<DropdownMenuItem<Map<String, dynamic>>>((address) {
                                          return DropdownMenuItem(
                                            value: address,
                                            child: Text(
                                              '${address['diCl_DireccionExacta']} - ${address['muni_Descripcion']}',
                                              style: const TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedAddress = newValue;
                                              _ventaModel.diClId = newValue['diCl_Id'] ?? 0;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Resumen de productos
                  _buildProductsConfirmationSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Resumen financiero
                  _buildFinancialSummary(subtotal, descuentos, subtotalConDescuento, impuestos, total, totalItems),
                  
              
                  const SizedBox(height: 24)
                  
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo de confirmación
  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to close
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '¿Confirmar venta?',
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.bold,
              color: Color(0xFF141A2F),
            ),
          ),
          content: const Text(
            '¿Estás seguro de que deseas confirmar esta venta?',
            style: TextStyle(
              fontFamily: 'Satoshi',
              color: Color(0xFF64748B),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
              },
            ),
            TextButton(
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF98BF4A),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                _procesarVentaConImpresion(); // Proceder con la venta
              },
            ),
          ],
        );
      },
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
                'Seleccionados',
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
                  color: const Color.fromARGB(255, 29, 34, 63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedProducts.length} productos',
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 26, 35, 72),
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
            final product = _allProducts.firstWhere((p) => p.prodId == prodId);
            final precio = product.prodPrecioUnitario;
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
                          product.prodDescripcionCorta ?? 'Producto sin nombre',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF141A2F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Código: ${product.prodId ?? 'N/A'}',
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
  Widget _buildFinancialSummary(double subtotal, double descuentos, double subtotalConDescuento, double impuestos, double total, int totalItems) {
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
                'Resumen',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 15,
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
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildFinancialRow('Subtotal:', 'L. ${subtotal.toStringAsFixed(2)}'),
          
          // Mostrar descuentos si existen
          if (descuentos > 0) ...[
            _buildFinancialRow('Descuentos:', '- L. ${descuentos.toStringAsFixed(2)}', isDiscount: true),
            _buildFinancialRow('Subtotal c/descuento:', 'L. ${subtotalConDescuento.toStringAsFixed(2)}', isBold: true),
          ],
          
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

  // Helper para las filas financieras
  Widget _buildFinancialRow(String label, String value, {bool isDiscount = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? const Color(0xFF10B981) : Colors.white,
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

  // Método para procesar la venta con impresión
  Future<void> _procesarVentaConImpresion() async {
    if (_isProcessingSale) return;

    setState(() {
      _isProcessingSale = true;
    });

    try {
      // 1. Validar que hay productos seleccionados
      if (_selectedProducts.isEmpty) {
        throw Exception('Debe seleccionar al menos un producto');
      }

      // 2. Usar el método existente _procesarVenta para guardar la venta
      await _procesarVenta();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSale = false;
        });
      }
    }
  }

  // Mostrar diálogo de éxito
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 30),
            const SizedBox(width: 10),
            const Text('¡Venta Exitosa!'),
          ],
        ),
        content: const Text('Venta procesada correctamente'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetearFormulario();
            },
            child: const Text('Aceptar'),
          )
        ],
      ),
    );
  }

}
