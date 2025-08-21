import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/printer_service.dart';
import 'generateInvoicePdf.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final int facturaId;
  final String facturaNumero;

  const InvoiceDetailScreen({
    Key? key,
    required this.facturaId,
    required this.facturaNumero,
  }) : super(key: key);

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final VentaService _ventaService = VentaService();
  final PrinterService _printerService = PrinterService();
  
  Map<String, dynamic>? _facturaData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _ventaService.obtenerFacturaCompleta(widget.facturaId);
      
      if (response != null && response['success'] == true) {
        setState(() {
          _facturaData = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response?['message'] ?? 'Error al cargar los detalles de la factura';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _printInvoice() async {
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
      final printSuccess = await _printerService.printInvoice(_facturaData!);
      
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Factura ${widget.facturaNumero}'),
        backgroundColor: const Color(0xFF141A2F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _printInvoice,
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir',
          ),
          Builder(
            builder: (context) => IconButton(
              onPressed: () => _showFloatingShareMenu(context),
              icon: const Icon(Icons.share),
              tooltip: 'Compartir',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF98BF4A),
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildInvoiceContent(),
    );
  }

  void _showFloatingShareMenu(BuildContext context) async {
    if (_facturaData == null) return;

    final pdfFile = await generateInvoicePdf(_facturaData!, widget.facturaNumero);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  overlayEntry.remove();
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              left: buttonPosition.dx + button.size.width - 180,
              top: buttonPosition.dy + 60,
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: FontAwesomeIcons.whatsapp,
                      color: Colors.green,
                      onPressed: () async {
                        await Share.shareXFiles([XFile(pdfFile.path)], text: "Factura SIDCOP");
                        overlayEntry.remove();
                      },
                    ),
                    _buildIconButton(
                      icon: FontAwesomeIcons.filePdf,
                      color: const Color.fromARGB(255, 117, 19, 12),
                      onPressed: () {
                        overlayEntry.remove();
                        _showDownloadProgress(pdfFile);
                      },
                    ),
                    _buildIconButton(
                      icon: Icons.more_horiz,
                      color: Colors.grey,
                      onPressed: () async {
                        await Share.shareXFiles([XFile(pdfFile.path)], text: "Factura SIDCOP");
                        overlayEntry.remove();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 248, 248, 248),
          radius: 24,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }

  void _showDownloadProgress(File pdfFile) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona la carpeta para guardar el PDF',
    );

    if (selectedDirectory == null) {
      return;
    }

    final fileName = pdfFile.path.split(Platform.pathSeparator).last;
    final newPath = '$selectedDirectory${Platform.pathSeparator}$fileName';
    await pdfFile.copy(newPath);

    double progress = 0.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (progress < 1.0) {
                setState(() => progress += 0.25);
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Factura descargada en: $newPath")),
                );
              }
            });

            return AlertDialog(
              title: const Text("Descargando..."),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text("${(progress * 100).toInt()}%"),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar la factura',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInvoiceDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF98BF4A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    if (_facturaData == null) return const SizedBox();

    final factura = _facturaData!;
    
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header de la empresa (CENTRADO)
            _buildCompanyHeader(factura),
            
            // Encabezado de la factura (FILAS)
            _buildInvoiceHeader(factura),
            
            // Tabla de productos (ADAPTADA PARA MÓVIL)
            _buildProductsTable(factura),
            
            // Totales (FILAS)
            _buildTotalsSection(factura),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader(Map<String, dynamic> factura) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Logo centrado
          if (factura['coFa_Logo'] != null && factura['coFa_Logo'].toString().isNotEmpty)
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(factura['coFa_Logo']),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF98BF4A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business,
                color: Colors.white,
                size: 40,
              ),
            ),
          
          // Nombre de la empresa centrado
          Text(
            factura['coFa_NombreEmpresa'] ?? 'Empresa',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF141A2F),
              fontFamily: 'Satoshi',
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Dirección empresa centrada
          Text(
            factura['coFa_DireccionEmpresa'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontFamily: 'Satoshi',
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Label Casa Matriz
          const Text(
            'CASA MATRIZ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF141A2F),
              fontFamily: 'Satoshi',
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Teléfono centrado
          if (factura['coFa_Telefono1']?.toString().trim().isNotEmpty == true)
            Text(
              'Tel: ${factura['coFa_Telefono1']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Satoshi',
              ),
            ),
          
          const SizedBox(height: 4),
          
          // Correo centrado
          if (factura['coFa_Correo']?.toString().trim().isNotEmpty == true)
            Text(
              factura['coFa_Correo'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Satoshi',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader(Map<String, dynamic> factura) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea divisoria
          Container(
            height: 2,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF98BF4A), Color(0xFF7BA83A)],
              ),
            ),
          ),
          
          // CAI
          _buildHeaderRow('CAI:', factura['regC_Descripcion'] ?? 'N/A'),
          
          // Número de factura
          _buildHeaderRow('No. Factura:', factura['fact_Numero'] ?? 'N/A'),
          
          // Fecha de emisión
          _buildHeaderRow('Fecha de Emisión:', _formatDate(factura['fact_FechaEmision'])),
          
          // Tipo de venta
          _buildHeaderRow('Tipo de Venta:', factura['fact_TipoVenta'] ?? 'N/A'),
          
          // Cliente
          _buildHeaderRow('Cliente:', factura['cliente'] ?? 'Cliente General'),
          
          // Vendedor
          _buildHeaderRow('Vendedor:', factura['vendedor'] ?? 'N/A'),
          
          // Línea divisoria
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            color: const Color(0xFFE9ECEF),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(Map<String, dynamic> factura) {
    final detalles = factura['detalleFactura'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF141A2F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'DESCRIPCIÓN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    'CANT.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'PRECIO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Filas de productos adaptadas para móvil
          ...detalles.asMap().entries.map((entry) {
            final index = entry.key;
            final detalle = entry.value;
            final isLast = index == detalles.length - 1;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
                border: !isLast ? const Border(
                  bottom: BorderSide(color: Color(0xFFE9ECEF), width: 0.5),
                ) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción del producto
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalle['prod_Descripcion'] ?? 'Producto',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF141A2F),
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        if (detalle['prod_CodigoBarra']?.toString().isNotEmpty == true)
                          Text(
                            'Código: ${detalle['prod_CodigoBarra']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Cantidad
                  SizedBox(
                    width: 50,
                    child: Text(
                      (detalle['faDe_Cantidad'] ?? 0).toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  
                  // Precio
                  SizedBox(
                    width: 70,
                    child: Text(
                      'L ${(detalle['faDe_PrecioUnitario'] ?? 0).toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  
                  // Total
                  SizedBox(
                    width: 70,
                    child: Text(
                      'L ${(detalle['faDe_Total'] ?? 0).toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(Map<String, dynamic> factura) {
    final subtotal = (factura['fact_Subtotal'] ?? 0).toDouble();
    final impuesto15 = (factura['fact_TotalImpuesto15'] ?? 0).toDouble();
    final impuesto18 = (factura['fact_TotalImpuesto18'] ?? 0).toDouble();
    final importeExento = (factura['fact_ImporteExento'] ?? 0).toDouble();
    final importeGravado15 = (factura['fact_ImporteGravado15'] ?? 0).toDouble();
    final importeGravado18 = (factura['fact_ImporteGravado18'] ?? 0).toDouble();
    final importeExonerado = (factura['fact_ImporteExonerado'] ?? 0).toDouble();
    final descuento = (factura['fact_TotalDescuento'] ?? 0).toDouble();
    final total = (factura['fact_Total'] ?? 0).toDouble();
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea divisoria
          Container(
            height: 2,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF98BF4A), Color(0xFF7BA83A)],
              ),
            ),
          ),
          
          // Subtotal
          _buildTotalRow('Subtotal:', 'L ${subtotal.toStringAsFixed(2)}'),
          
          // Importe Exento (si aplica)
          if (importeExento > 0)
            _buildTotalRow('Importe Exento:', 'L ${importeExento.toStringAsFixed(2)}'),
          
          // Importe Gravado 15% (si aplica)
          if (importeGravado15 > 0)
            _buildTotalRow('Importe Gravado 15%:', 'L ${importeGravado15.toStringAsFixed(2)}'),
          
          // Importe Gravado 18% (si aplica)
          if (importeGravado18 > 0)
            _buildTotalRow('Importe Gravado 18%:', 'L ${importeGravado18.toStringAsFixed(2)}'),
          
          // Importe Exonerado (si aplica)
          if (importeExonerado > 0)
            _buildTotalRow('Importe Exonerado:', 'L ${importeExonerado.toStringAsFixed(2)}'),
          
          // Descuento (si aplica)
          if (descuento > 0)
            _buildTotalRow('Total Descuento:', '- L ${descuento.toStringAsFixed(2)}', isNegative: true),
          
          // ISV 15% (si aplica)
          if (impuesto15 > 0)
            _buildTotalRow('ISV 15%:', 'L ${impuesto15.toStringAsFixed(2)}'),
          
          // ISV 18% (si aplica)
          if (impuesto18 > 0)
            _buildTotalRow('ISV 18%:', 'L ${impuesto18.toStringAsFixed(2)}'),
          
          // Línea divisoria antes del total
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: const Color(0xFFE9ECEF),
          ),
          
          // Total final
          _buildTotalRow('TOTAL A PAGAR:', 'L ${total.toStringAsFixed(2)}', isFinal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isFinal = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isFinal ? 16 : 14,
                fontWeight: isFinal ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isFinal ? 18 : 14,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w600,
              color: isFinal 
                ? const Color(0xFF98BF4A)
                : isNegative
                  ? Colors.red
                  : const Color(0xFF141A2F),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDotsLoading extends StatefulWidget {
  const _VerticalDotsLoading({Key? key}) : super(key: key);

  @override
  State<_VerticalDotsLoading> createState() => _VerticalDotsLoadingState();
}

class _VerticalDotsLoadingState extends State<_VerticalDotsLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _animation1 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)));
    _animation2 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeIn)));
    _animation3 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.9, curve: Curves.easeIn)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(opacity: _animation1, child: _dot()),
        const SizedBox(height: 8),
        FadeTransition(opacity: _animation2, child: _dot()),
        const SizedBox(height: 8),
        FadeTransition(opacity: _animation3, child: _dot()),
      ],
    );
  }

  Widget _dot() => Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF141A2F),
          shape: BoxShape.circle,
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}