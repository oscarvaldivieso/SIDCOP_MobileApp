import 'package:flutter/material.dart';
import '../../widgets/appBackground.dart';
import '../../../services/inventory_service.dart';
import '../../../services/PerfilUsuarioService.dart';
import '../../../services/printer_service.dart';

class InventoryScreen extends StatefulWidget {
  final int usuaIdPersona;

  const InventoryScreen({super.key, required this.usuaIdPersona});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final PrinterService _printerService = PrinterService();
  final InventoryService _inventoryService = InventoryService();
  Map<String, dynamic>? _facturaData;
  String? _error;
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sellerName = 'Cargando...';
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
    _loadSellerName();
  }

  Future<void> _handleCloseJornada() async {
  try {
    // Show modern loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cerrando jornada',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Por favor espera...',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Call the closeJornada method
    final result = await _inventoryService.closeJornada(widget.usuaIdPersona);
    
    // Close the loading dialog
    if (mounted) Navigator.of(context).pop();

    if (result != null) {
      // Show modern success dialog with workday summary
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with success icon
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Jornada Cerrada',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'Exitosamente',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Content with summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        // Time section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time, 
                                       color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Horario',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Inicio',
                                        style: TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${result['jorV_HoraInicio']}',
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Fin',
                                        style: TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        '${result['jorV_HoraFin']}',
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Products section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.inventory_2, 
                                       color: Colors.blue.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Resumen de Productos',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryItem(
                                      'Total Productos',
                                      '${result['totalProductos']}',
                                      Colors.blue.shade600,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildSummaryItem(
                                      'Inicial',
                                      '${result['totalInicial']}',
                                      Colors.orange.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryItem(
                                      'Final',
                                      '${result['totalFinal']}',
                                      Colors.purple.shade600,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildSummaryItem(
                                      'Vendido',
                                      '${result['totalVendido']}',
                                      Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Total amount
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade400, Colors.green.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Monto Total',
                                style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'L.${result['montoTotal']}',
                                style: const TextStyle(
                                  fontFamily: 'Satoshi',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
          ),
        );
      }
    }
  } catch (e) {
    // Close loading dialog if still mounted
    if (mounted) Navigator.of(context).pop();
    
    // Show modern error message
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error al cerrar jornada: $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// Helper widget for summary items
Widget _buildSummaryItem(String label, String value, Color color) {
  return Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontFamily: 'Satoshi',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}

  Future<void> _loadJornadaDetallada() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final jornadaData = await _inventoryService.getJornadaDetallada(widget.usuaIdPersona);
    
    setState(() {
      _facturaData = jornadaData;
      _isLoading = false;
    });

  } catch (e) {
    setState(() {
      _errorMessage = 'Error al cargar la jornada detallada: $e';
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _printInvoice() async {

    _loadJornadaDetallada();

    if (_facturaData == null) return;

    try {
      // Mostrar diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando impresión...'),
            ],
          ),
        ),
      );

      // Seleccionar impresora y conectar
      final selectedDevice = await _printerService.showPrinterSelectionDialog(context);
      
      // Cerrar diálogo de carga
      if (mounted) Navigator.of(context).pop();
      
      if (selectedDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impresión cancelada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mostrar diálogo de conexión
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Conectando a impresora...'),
              ],
            ),
          ),
        );
      }

      // Conectar a la impresora
      final connected = await _printerService.connect(selectedDevice);
      
      // Cerrar diálogo de conexión
      if (mounted) Navigator.of(context).pop();
      
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al conectar con la impresora'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Mostrar diálogo de impresión
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Imprimiendo factura...'),
              ],
            ),
          ),
        );
      }

      // Imprimir usando el PrinterService
      final printSuccess = await _printerService.printInventory(_facturaData!);
      
      // Cerrar diálogo de impresión
      if (mounted) Navigator.of(context).pop();
      
      // Desconectar automáticamente
      await _printerService.disconnect();
      
      if (mounted) {
        if (printSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Factura impresa exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Error al imprimir la factura'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      // Cerrar cualquier diálogo abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Desconectar en caso de error
      await _printerService.disconnect();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al imprimir: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadInventoryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final items = await InventoryService().getInventoryByVendor(
        widget.usuaIdPersona,
      );

      setState(() {
        _inventoryItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSellerName() async {
    try {
      // Try to get name from nombres and apellidos fields
      final userData = await _perfilUsuarioService.obtenerDatosUsuario();
      if (userData != null) {
        final nombres = userData['nombres'] ?? '';
        final apellidos = userData['apellidos'] ?? '';

        if (nombres.isNotEmpty && apellidos.isNotEmpty) {
          setState(() {
            _sellerName = '$nombres $apellidos';
          });
          return;
        } else if (nombres.isNotEmpty) {
          setState(() {
            _sellerName = nombres;
          });
          return;
        } else if (apellidos.isNotEmpty) {
          setState(() {
            _sellerName = apellidos;
          });
          return;
        }
      }

      // Fallback to existing method
      final name = await _perfilUsuarioService.obtenerNombreCompleto();
      setState(() {
        _sellerName = name;
      });
    } catch (e) {
      setState(() {
        _sellerName = 'Usuario';
      });
    }
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final weekday = weekdays[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];
    final year = now.year;

    return '$weekday, $day $month $year';
  }

  // Método para obtener el estado del producto basado en las cantidades
  Map<String, dynamic> _getProductStatus(Map<String, dynamic> item) {
    final int assigned = _getIntValue(item, 'cantidadAsignada');
    final int current = _getIntValue(item, 'currentQuantity');
    final int sold = _getIntValue(item, 'soldQuantity');

    double percentage = 0.0;
    if (assigned > 0) {
      percentage = sold / assigned;
    }

    Color statusColor;
    String statusText;

    if (current <= 0) {
      statusColor = Colors.red;
      statusText = 'Agotado';
    } else if (percentage >= 0.8) {
      statusColor = const Color(0xFFC2AF86);
      statusText = 'Casi agotado';
    } else if (percentage >= 0.5) {
      statusColor = Colors.orange;
      statusText = 'Media venta';
    } else {
      statusColor = Colors.green;
      statusText = 'Disponible';
    }

    return {
      'color': statusColor,
      'text': statusText,
      'percentage': percentage,
    };
  }

  // Método auxiliar para obtener valores enteros de forma segura
  int _getIntValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Método auxiliar para obtener valores double de forma segura
  double _getDoubleValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Método auxiliar para obtener valores string de forma segura
  String _getStringValue(Map<String, dynamic> map, String key, [String defaultValue = '']) {
    final value = map[key];
    if (value != null) return value.toString();
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Inventario',
      icon: Icons.inventory_2,
      onRefresh: () async {
        _loadInventoryData();
        _loadSellerName();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrintInventoryButton(),

            const SizedBox(height: 24),

            _buildCloseJornadaButton(),

            const SizedBox(height: 24), 

            // Encabezado de Jornada
            _buildDayHeader(),
            const SizedBox(height: 24),

            // Inventario Asignado del Día
            _buildAssignedInventory(),
            const SizedBox(height: 24),

          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2332).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E2A3D),
                Color(0xFF1A2332),
                Color(0xFF141A2F),
                Color(0xFF0F1419),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Efectos de fondo decorativos
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFC2AF86).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFC2AF86).withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Contenido principal
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header superior con fecha y estado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Información de fecha
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC2AF86).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFC2AF86).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatCurrentDate(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Satoshi',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF4CAF50),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'En línea • ${_getCurrentTime()}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontFamily: 'Satoshi',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Información del vendedor mejorada
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar mejorado del vendedor
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFC2AF86),
                                  Color(0xFFB8A47A),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFC2AF86).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          
                          const SizedBox(width: 18),

                          // Información del vendedor
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _sellerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Satoshi',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.badge_outlined,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'ID: ${widget.usuaIdPersona}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontFamily: 'Satoshi',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                  ],
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
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar para obtener la hora actual
  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFC2AF86), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Satoshi',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontFamily: 'Satoshi',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedInventory() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC2AF86)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Error al cargar inventario',
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'Satoshi',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'Satoshi',
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInventoryData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2AF86),
                foregroundColor: const Color(0xFF141A2F),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título y resumen
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Asignado',
              style: TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC2AF86).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC2AF86), width: 1),
              ),
              child: Text(
                '${_inventoryItems.length} productos',
                style: const TextStyle(
                  color: Color(0xFFC2AF86),
                  fontFamily: 'Satoshi',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de productos
        ..._inventoryItems.map((item) => _buildInventoryItemCard(item)),
      ],
    );
  }

  // Método auxiliar para obtener el icono del producto
  Widget _getProductIcon(String subcDescripcion) {
    IconData productIcon = Icons.inventory;
    final description = subcDescripcion.toLowerCase();
    
    if (description.contains('bebida') || description.contains('drink')) {
      productIcon = Icons.local_drink;
    } else if (description.contains('panaderia') || description.contains('pan')) {
      productIcon = Icons.bakery_dining;
    } else if (description.contains('snack') || description.contains('comida')) {
      productIcon = Icons.fastfood;
    } else if (description.contains('perro') || description.contains('mascota')) {
      productIcon = Icons.pets;
    } else if (description.contains('limpieza')) {
      productIcon = Icons.cleaning_services;
    }

    return Icon(productIcon, color: const Color(0xFF141A2F), size: 30);
  }

  Widget _buildInventoryItemCard(Map<String, dynamic> item) {
    // Obtener valores de forma segura
    final int assigned = _getIntValue(item, 'cantidadAsignada');
    final int current = _getIntValue(item, 'currentQuantity');
    final int sold = _getIntValue(item, 'soldQuantity');
    final double precio = _getDoubleValue(item, 'precio');
    final String nombreProducto = _getStringValue(item, 'nombreProducto', 'Producto sin nombre');
    final String codigoProducto = _getStringValue(item, 'codigoProducto', 'N/A');
    final String subcDescripcion = _getStringValue(item, 'subc_Descripcion', 'Sin categoría');
    final String prodImagen = _getStringValue(item, 'prod_Imagen');
    
    // Obtener el estado del producto
    final status = _getProductStatus(item);
    final Color statusColor = status['color'];
    final String statusText = status['text'];
    final double percentage = status['percentage'];

    // Widget para la imagen del producto
    Widget productImage = prodImagen.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              prodImagen,
              width: 55,
              height: 55,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _getProductIcon(subcDescripcion);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFFC2AF86),
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            ),
          )
        : Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            child: _getProductIcon(subcDescripcion),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              productImage,
              const SizedBox(width: 16),

              // Información del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreProducto,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontFamily: 'Satoshi',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: $codigoProducto',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subcDescripcion,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontFamily: 'Satoshi',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Estado y precio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: 'Satoshi',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'L.${precio.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[900],
                      fontFamily: 'Satoshi',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cantidades y estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatText('Asignado', assigned.toString(), Colors.grey[600]!),
              _buildStatText('Actual', current.toString(), Colors.black),
              _buildStatText('Vendido', sold.toString(), const Color(0xFFC2AF86)),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progreso mejorada
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso de ventas',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(percentage * 100).toInt()}%',
                    style: TextStyle(
                      color: statusColor,
                      fontFamily: 'Satoshi',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Validación adicional para evitar valores NaN
                    final double validWidth = constraints.maxWidth;
                    final double progressWidth = validWidth * percentage;
                    
                    // Asegurar que el ancho calculado sea válido
                    final double finalWidth = progressWidth.isNaN || 
                                            progressWidth.isInfinite || 
                                            progressWidth < 0
                        ? 0.0 
                        : progressWidth.clamp(0.0, validWidth);

                    return Stack(
                      children: [
                        Container(
                          width: finalWidth,
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor,
                                statusColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget auxiliar mejorado para textos de estadísticas
  Widget _buildStatText(String label, String value, Color color) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'Satoshi',
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Satoshi',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsManagement() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestión de Movimientos',
            style: TextStyle(
              color: Colors.grey[800],
              fontFamily: 'Satoshi',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMovementButton(
                  icon: Icons.add_circle_outline,
                  title: 'Entrada',
                  subtitle: 'Registrar entrada',
                  color: Colors.green,
                  onTap: () {
                    // Implementar funcionalidad de entrada
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMovementButton(
                  icon: Icons.remove_circle_outline,
                  title: 'Salida',
                  subtitle: 'Registrar salida',
                  color: Colors.red,
                  onTap: () {
                    // Implementar funcionalidad de salida
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Satoshi',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'Satoshi',
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    // Calcular estadísticas del día
    int totalAssigned = 0;
    int totalSold = 0;
    int totalCurrent = 0;
    double totalValue = 0.0;

    for (var item in _inventoryItems) {
      totalAssigned += _getIntValue(item, 'cantidadAsignada');
      totalSold += _getIntValue(item, 'soldQuantity');
      totalCurrent += _getIntValue(item, 'currentQuantity');
      totalValue += _getDoubleValue(item, 'precio') * _getIntValue(item, 'soldQuantity');
    }

    double salesPercentage = totalAssigned > 0 ? (totalSold / totalAssigned) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC2AF86).withOpacity(0.1),
            const Color(0xFFC2AF86).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC2AF86).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del Día',
            style: TextStyle(
              color: Colors.grey[800],
              fontFamily: 'Satoshi',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          
          // Estadísticas en grid
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Asignado',
                  value: totalAssigned.toString(),
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Vendido',
                  value: totalSold.toString(),
                  icon: Icons.shopping_cart,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Disponible',
                  value: totalCurrent.toString(),
                  icon: Icons.store,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Ventas (L.)',
                  value: totalValue.toStringAsFixed(2),
                  icon: Icons.attach_money,
                  color: const Color(0xFFC2AF86),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Porcentaje de ventas
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Eficiencia de Ventas',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${salesPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFFC2AF86),
                    fontFamily: 'Satoshi',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Satoshi',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'Satoshi',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseJornadaButton() {
    return ElevatedButton.icon(
      onPressed: _handleCloseJornada,
      icon: const Icon(Icons.lock_clock, color: Colors.white),
      label: const Text('Cerrar Jornada', style: TextStyle(fontFamily: 'Satoshi', fontSize: 13, fontWeight: FontWeight.w500)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 148, 18, 8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }


  Widget _buildPrintInventoryButton() {
  return ElevatedButton.icon(
    onPressed:  _printInvoice ,
    icon: const Icon(Icons.print),
    label: const Text('Imprimir Inventario', style: TextStyle(fontFamily: 'Satoshi', fontSize: 13, fontWeight: FontWeight.w500)),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 17, 22, 48),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );
}


  
}





