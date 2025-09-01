import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sidcop_mobile/models/PedidosViewModel.Dart';
import 'package:sidcop_mobile/services/printer_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  Color get _primaryColor => const Color(0xFF141A2F);
  Color get _goldColor => const Color(0xFFE0C7A0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Factura',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _printInvoice,
            ),
          if (_isSharing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareInvoice,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _invoiceKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInvoiceContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    final List<dynamic> detalles = _parseDetalles(widget.pedido.detallesJson);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompanyHeader(),
          const SizedBox(height: 32),
          _buildInvoiceDetails(),
          const SizedBox(height: 24),
          _buildProductsTable(detalles),
          const SizedBox(height: 24),
          _buildTotals(detalles),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Column(
      children: [
        // Company Logo Placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.business,
            size: 40,
            color: _goldColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.pedido.coFaNombreEmpresa ?? 'Comercial La Roca S de RL',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'CASA MATRIZ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.pedido.coFaDireccionEmpresa ?? 'Bo. Guamilito',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Text(
          'Tel: ${widget.pedido.coFaTelefono1 ?? '20158040'}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Text(
          widget.pedido.coFaCorreo ?? 'sac@larocacomercial.com',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildInvoiceDetails() {
    return Column(
      children: [
        const Divider(thickness: 1),
        const SizedBox(height: 16),
        _buildDetailRow('CAI:', '35ABDF-AB7210-9748E0-63BE03-090965'),
        _buildDetailRow('No. Factura:', _generateInvoiceNumber()),
        _buildDetailRow('Fecha de Emisión:', _formatDateTime(DateTime.now())),
        _buildDetailRow('Tipo de Venta:', 'CO'),
        _buildDetailRow('Cliente:', widget.pedido.clieNombreNegocio ?? 'Cliente General'),
        _buildDetailRow('RTN Cliente:', widget.pedido.coFaRTN ?? '0290-2390-84293'),
        _buildDetailRow('RTN Cliente:', 'progreso'),
        _buildDetailRow('Vendedor:', '${widget.pedido.vendNombres ?? ''} ${widget.pedido.vendApellidos ?? ''}'),
        _buildDetailRow('No Orden de compra exenta:', ''),
        _buildDetailRow('No Constancia de reg de exonerados:', ''),
        _buildDetailRow('No Registro de la SAG:', ''),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(List<dynamic> detalles) {
    return Column(
      children: [
        // Table Header
        Container(
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'DESCRIPCIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'CANT.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'PRECIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Table Content
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Column(
            children: detalles.map((item) => _buildProductRow(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(dynamic item) {
    final String descripcion = item['descripcion']?.toString() ?? '';
    final int cantidad = item['cantidad'] is int
        ? item['cantidad']
        : int.tryParse(item['cantidad']?.toString() ?? '') ?? 0;
    final double precio = item['precio'] is double
        ? item['precio']
        : double.tryParse(item['precio']?.toString() ?? '') ?? 0.0;
    final double total = cantidad * precio;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              descripcion,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              cantidad.toString(),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'L ${precio.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'L ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(List<dynamic> detalles) {
    final double subtotal = _calculateSubtotal(detalles);
    final double descuento = 0.0;
    final double importeExento = subtotal;
    final double importeExonerado = 0.0;
    final double importeGravado15 = 0.0;
    final double importeGravado18 = 0.0;
    final double totalImpuesto15 = 0.0;
    final double totalImpuesto18 = 0.0;
    final double total = subtotal;

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        _buildTotalRow('Subtotal:', 'L ${subtotal.toStringAsFixed(2)}'),
        _buildTotalRow('Total Descuento:', 'L ${descuento.toStringAsFixed(2)}'),
        _buildTotalRow('Importe Exento:', 'L ${importeExento.toStringAsFixed(2)}'),
        _buildTotalRow('Importe Exonerado:', 'L ${importeExonerado.toStringAsFixed(2)}'),
        _buildTotalRow('Importe Gravado 15%:', 'L ${importeGravado15.toStringAsFixed(2)}'),
        _buildTotalRow('Importe Gravado 18%:', 'L ${importeGravado18.toStringAsFixed(2)}'),
        _buildTotalRow('Total Impuesto 15%:', 'L ${totalImpuesto15.toStringAsFixed(2)}'),
        _buildTotalRow('Total Impuesto 18%:', 'L ${totalImpuesto18.toStringAsFixed(2)}'),
        const Divider(thickness: 2),
        const SizedBox(height: 8),
        _buildTotalRow(
          'Total:',
          'L ${total.toStringAsFixed(2)}',
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
