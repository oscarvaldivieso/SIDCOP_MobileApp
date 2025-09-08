import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/printer_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Clase para crear el efecto de factura rota
class TornPaperClipper extends CustomClipper<Path> {
  final double jaggedness = 20.0;

  @override
  Path getClip(Size size) {
    var path = Path();
    // Inicia en la esquina superior izquierda
    path.lineTo(0, 0);

    // Dibuja la parte superior con picos irregulares
    var i = 0.0;
    while (i < size.width) {
      path.lineTo(i + jaggedness / 2, jaggedness);
      path.lineTo(i + jaggedness, 0);
      i += jaggedness;
    }

    // Dibuja el resto de los bordes rectos
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(TornPaperClipper oldClipper) => true;
}

class InvoicePreviewScreen extends StatefulWidget {
  final PedidosViewModel pedido;
  
  const InvoicePreviewScreen({super.key, required this.pedido});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final PrinterService _printerService = PrinterService();
  final GlobalKey _invoiceKey = GlobalKey();
  bool _isPrinting = false;
  bool _isSharing = false;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF141A2F),
              const Color(0xFF1A2238),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70,
          leading: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromARGB(255, 160, 148, 83).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Regresar',
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Factura',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Botón de imprimir
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: _isPrinting
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _printInvoice,
                    icon: const Icon(
                      Icons.print_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Imprimir',
                  ),
            ),
            
            // Botón de compartir
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: _isSharing
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) => IconButton(
                      onPressed: _shareInvoice,
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Compartir',
                    ),
                  ),
            ),
          ],
        ),
      ),
    ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RepaintBoundary(
            key: _invoiceKey,
            child: ClipPath(
              clipper: TornPaperClipper(),
              child: Column(
                children: [
                  // Agrega un padding superior aquí
                  Padding(
                    padding: const EdgeInsets.only(top: 0), // Ajusta este valor
                    child: _buildCompanyHeader(),
                  ),
                  _buildInvoiceDetails(),
                  _buildProductsTable(_parseDetalles(widget.pedido.detallesJson)),
                  _buildTotals(_parseDetalles(widget.pedido.detallesJson)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildCompanyHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo centrado
          Container(
            width: 70,
            height: 70,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: widget.pedido.coFaLogo != null && 
                   widget.pedido.coFaLogo.toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.pedido.coFaLogo!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      _buildDefaultLogo(),
                  ),
                )
              : _buildDefaultLogo(),
          ),
          
          // Nombre de la empresa centrado
          Text(
            widget.pedido.coFaNombreEmpresa ?? 'Empresa',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 0, 0),
              fontFamily: 'Satoshi',
              height: 1.2,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Casa Matriz centrada
          const Text(
            'CASA MATRIZ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 0, 0, 0),
              fontFamily: 'Satoshi',
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 10),
          
          // Dirección centrada
          if (widget.pedido.coFaDireccionEmpresa?.toString().trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.pedido.coFaDireccionEmpresa!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontFamily: 'Satoshi',
                  height: 1.3,
                ),
              ),
            ),
          
          // Teléfono centrado
          if (widget.pedido.coFaTelefono1?.toString().trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Tel: ${widget.pedido.coFaTelefono1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          
          // Correo centrado
          if (widget.pedido.coFaCorreo?.toString().trim().isNotEmpty == true)
            Text(
              widget.pedido.coFaCorreo!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
              ),
            ),
        ],
      ),
    );
  }

  // Widget auxiliar para el logo por defecto
  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF98BF4A).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.business_outlined,
          color: Color(0xFF98BF4A),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // CAI
          _buildHeaderRow('CAI:', '35ABDF-AB7210-9748E0-63BE03-090965'),
          
          // Número de factura
          _buildHeaderRow('No. Factura:', _generateInvoiceNumber()),
          
          // Fecha de emisión
          _buildHeaderRow('Fecha de Emisión:', _formatDate(DateTime.now().toString())),
          
          // Tipo de venta
          _buildHeaderRow('Tipo de Venta:', 'CO'),
          
          // Cliente
          _buildHeaderRow('Cliente:', widget.pedido.clieNombreNegocio ?? 'Cliente General'),

          // RTN del  Cliente
          _buildHeaderRow('RTN Cliente:', widget.pedido.coFaRTN ?? '0290-2390-84293'),
          
          // Direccion del  Cliente
          _buildHeaderRow('RTN Cliente:', 'progreso'),

          // Vendedor
          _buildHeaderRow('Vendedor:', '${widget.pedido.vendNombres ?? ''} ${widget.pedido.vendApellidos ?? ''}'),

          // Vendedor
          _buildHeaderRow('No Orden de compra exenta:', ''),

          // Vendedor
          _buildHeaderRow('No Constancia de reg de exonerados:', ''),

          // Vendedor
          _buildHeaderRow('No Registro de la SAG:', ''),
          
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
                fontSize: 12,
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
                fontSize: 12,
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildProductsTable(List<dynamic> detalles) {
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
            
            return _buildProductRow(detalle, index, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildProductRow(dynamic detalle, int index, bool isLast) {
    final String descripcion = detalle['descripcion']?.toString() ?? '';
    final int cantidad = detalle['cantidad'] is int
        ? detalle['cantidad']
        : int.tryParse(detalle['cantidad']?.toString() ?? '') ?? 0;
    final double precio = detalle['precio'] is double
        ? detalle['precio']
        : double.tryParse(detalle['precio']?.toString() ?? '') ?? 0.0;
    final double total = cantidad * precio;

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
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF141A2F),
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
              cantidad.toStringAsFixed(0),
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
              'L ${precio.toStringAsFixed(2)}',
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
              'L ${total.toStringAsFixed(2)}',
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
  }

  Widget _buildTotals(List<dynamic> detalles) {
    final double subtotal = _calculateSubtotal(detalles);
    final double totalDescuento = 0.0;
    final double importeExento = subtotal;
    final double importeExonerado = 0.0;
    final double importeGravado15 = 0.0;
    final double importeGravado18 = 0.0;
    final double impuesto15 = 0.0;
    final double impuesto18 = 0.0;
    final double total = subtotal;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea divisoria
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.grey[400],
          ),

          // Subtotal
          _buildTotalRow('Subtotal:', subtotal.toStringAsFixed(2)),

          // Descuento
          _buildTotalRow('Total Descuento:', totalDescuento.toStringAsFixed(2), isNegative: true),

          // Importe Exento
          _buildTotalRow('Importe Exento:', importeExento.toStringAsFixed(2)),

          // Importe Exonerado
          _buildTotalRow('Importe Exonerado:', importeExonerado.toStringAsFixed(2)),

          // Importe Gravado 15%
          _buildTotalRow('Importe Gravado 15%:', importeGravado15.toStringAsFixed(2)),

          // Importe Gravado 18%
          _buildTotalRow('Importe Gravado 18%:', importeGravado18.toStringAsFixed(2)),

          // ISV 15%
          _buildTotalRow('Total Impuesto 15%:', impuesto15.toStringAsFixed(2)),

          // ISV 18%
          _buildTotalRow('Total Impuesto 18%:', impuesto18.toStringAsFixed(2)),

          // Línea divisoria antes del total
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[400],
          ),

          // Total final
          _buildTotalRow('Total:', total.toStringAsFixed(2), isFinal: true),
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
                ? const Color.fromARGB(255, 0, 0, 0)
                : isNegative
                  ? const Color.fromARGB(255, 0, 0, 0)
                  : const Color(0xFF141A2F),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _parseDetalles(String? detallesJson) {
    if (detallesJson == null || detallesJson.isEmpty) return [];
    try {
      return jsonDecode(detallesJson) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  double _calculateSubtotal(List<dynamic> detalles) {
    double subtotal = 0.0;
    for (var item in detalles) {
      final int cantidad = item['cantidad'] is int
          ? item['cantidad']
          : int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
      final double precio = item['precio'] is double
          ? item['precio']
          : double.tryParse(item['precio']?.toString() ?? '') ?? 0.0;
      subtotal += cantidad * precio;
    }
    return subtotal;
  }

  String _generateInvoiceNumber() {
    return widget.pedido.pedi_Codigo ?? 'N/A';
  }


  Future<void> _printInvoice() async {
    if (!mounted) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      final selectedDevice = await _printerService.showPrinterSelectionDialog(context);
      if (selectedDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impresión cancelada'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final connected = await _printerService.connect(selectedDevice);
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al conectar con la impresora'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final printSuccess = await _printerService.printPedido(widget.pedido);
      await _printerService.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(printSuccess ? 'Factura impresa exitosamente' : 'Error al imprimir la factura'),
            backgroundColor: printSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _shareInvoice() async {
    if (!mounted) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Capture the invoice as image
      final boundary = _invoiceKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo capturar la factura');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/factura_${widget.pedido.pediId}.png').create();
      await file.writeAsBytes(pngBytes);

      // Show sharing options
      await _showSharingOptions(file);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _showSharingOptions(File imageFile) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Compartir Factura',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Compartir con otras apps'),
              onTap: () async {
                Navigator.pop(context);
                await Share.shareXFiles(
                  [XFile(imageFile.path)],
                  text: 'Factura #${_generateInvoiceNumber()}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('Compartir por WhatsApp'),
              onTap: () async {
                Navigator.pop(context);
                await _shareViaWhatsApp(imageFile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareViaWhatsApp(File imageFile) async {
    try {
      final text = 'Factura #${_generateInvoiceNumber()}\nCliente: ${widget.pedido.clieNombreNegocio ?? 'Cliente General'}\nTotal: L ${_calculateSubtotal(_parseDetalles(widget.pedido.detallesJson)).toStringAsFixed(2)}';
      
      // Try to share directly to WhatsApp
      await Share.shareXFiles(
        [XFile(imageFile.path)],
        text: text,
        sharePositionOrigin: Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height / 2),
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir por WhatsApp: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
