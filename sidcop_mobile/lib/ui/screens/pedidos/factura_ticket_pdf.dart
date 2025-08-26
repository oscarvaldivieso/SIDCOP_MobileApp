import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';
import 'package:printing/printing.dart';

Future<Uint8List> generarFacturaPdf({
  required String nombreCliente,
  required String codigoCliente,
  String? direccion,
  String? rtn,
  String? logo,
  String? nombreEmpresa,
  String? direccionEmpresa,
  String? telefonoEmpresa,
  String? correoEmpresa,
  required String vendedor,
  required String fechaFactura,
  required String fechaEntrega,
  required String numeroFactura,
  required List<ProductoFactura> productos,
  required num subtotal,
  required num totalDescuento,
  required num total,
  required String totalEnLetras,
}) async {
  print('DEBUG PDF: numeroFactura recibido en generarFacturaPdf: $numeroFactura');
  final pdf = pw.Document();

  // Cargar el logo
  // final logoBytes = await rootBundle.load('$logo');
  // final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final netImage = await networkImage('$logo');

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, double.infinity, marginAll: 10 * PdfPageFormat.mm),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(children: [
                pw.Image(netImage, width: 100, height: 100),
                pw.SizedBox(height: 5),
                pw.Text('$nombreEmpresa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 3),
                pw.Text('$direccionEmpresa', style: pw.TextStyle(fontSize: 9)),
                pw.Text('Tel: $telefonoEmpresa', style: pw.TextStyle(fontSize: 9)),
                pw.Text('Correo: $correoEmpresa', style: pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Text('No. Pedido: $numeroFactura', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text('Fecha Emisión: $fechaFactura', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Fecha Entrega: $fechaEntrega', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Tipo Documento: Pedido', style: pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            pw.Text('Cliente: $nombreCliente', style: pw.TextStyle(fontSize: 9)),
            if (direccion != null && direccion.isNotEmpty) pw.Text('Dirección: $direccion', style: pw.TextStyle(fontSize: 9)),
            if (rtn != null && rtn.isNotEmpty) pw.Text('RTN: $rtn', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Vendedor: $vendedor', style: pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            pw.Row(children: [
              pw.Expanded(child: pw.Text('Und', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.Expanded(flex: 3, child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.Expanded(child: pw.Text('Precio', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.Expanded(child: pw.Text('Desc.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.Expanded(child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
            ]),
            pw.Divider(),
            ...productos.map((p) => pw.Row(children: [
              pw.Expanded(child: pw.Text('${p.cantidad}', style: pw.TextStyle(fontSize: 8))),
              pw.Expanded(flex: 3, child: pw.Text(p.nombre, style: pw.TextStyle(fontSize: 8))),
              pw.Expanded(child: pw.Text('L. ${p.precio.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8))),
              pw.Expanded(child: pw.Text(p.descuentoStr, style: pw.TextStyle(fontSize: 8))),
              pw.Expanded(child: pw.Text('L. ${(p.precioFinal * p.cantidad).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8))),
            ])),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Sub-total: L. ${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('Total Descuento: L. ${totalDescuento.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('Impuestos: L. ${_calcularTotalImpuestos(productos).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('Total: L. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('*$totalEnLetras*', style: pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('Gracias por su preferencia', 
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center)),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

double _calcularTotalImpuestos(List<ProductoFactura> productos) {
  double total = 0.0;
  for (var p in productos) {
    total += p.impuesto * p.cantidad;
  }
  return total;
}
