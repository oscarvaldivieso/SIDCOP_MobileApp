import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_screen.dart';


Future<Uint8List> generarFacturaPdf({
  required String nombreCliente,
  required String codigoCliente,
  String? direccion,
  String? rtn,
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
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(children: [
                pw.Text('COMERCIAL LA ROCA S. DE R.L.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text('Casa Matriz 1ra Ave, 5ta Calle...'),
                pw.Text('Tel: (504) 2516-4076 / 4189 / 4190 / 4191'),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Text('C.A.I: 31FB47-AFB25B-872CE0-63BE03-090949-03', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('No. Factura: $numeroFactura'),
            pw.Text('Fecha Emisión: $fechaFactura'),
            pw.Text('Fecha Entrega: $fechaEntrega'),
            pw.Text('Tipo Factura: Pedido'),
            pw.Divider(),
            pw.Text('Cliente: $nombreCliente'),
            pw.Text('Código: $codigoCliente'),
            if (direccion != null && direccion.isNotEmpty) pw.Text('Dirección: $direccion'),
            if (rtn != null && rtn.isNotEmpty) pw.Text('RTN: $rtn'),
            pw.Text('Vendedor: $vendedor'),
            pw.Divider(),
            pw.Row(children: [
              pw.Expanded(child: pw.Text('Und', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text('Precio', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text('Desc.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text('Monto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
            pw.Divider(),
            ...productos.map((p) => pw.Row(children: [
              pw.Expanded(child: pw.Text('${p.cantidad}')),
              pw.Expanded(flex: 3, child: pw.Text(p.nombre)),
              pw.Expanded(child: pw.Text('L. ${p.precio.toStringAsFixed(2)}')),
              pw.Expanded(child: pw.Text(p.descuentoStr)),
              pw.Expanded(child: pw.Text('L. ${(p.precioFinal * p.cantidad).toStringAsFixed(2)}')),
            ])),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Sub-total: L. ${subtotal.toStringAsFixed(2)}'),
                  pw.Text('Total Descuento: L. ${totalDescuento.toStringAsFixed(2)}'),
                  pw.Text('Total: L. ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('*$totalEnLetras*'),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('La factura es beneficio de todos, ¡exíjala!')),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
