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
      pageFormat: PdfPageFormat(100 * PdfPageFormat.mm, double.infinity, marginAll: 10 * PdfPageFormat.mm),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(children: [
                pw.Text('COMERCIAL LA ROCA S. DE R.L.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 3),
                pw.Text('Casa Matriz 1ra Ave, 5ta Calle...', style: pw.TextStyle(fontSize: 9)),
                pw.Text('Tel: (504) 2516-4076 / 4189 / 4190 / 4191', style: pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Text('No. Pedido: $numeroFactura', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text('Fecha Emisión: $fechaFactura', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Fecha Entrega: $fechaEntrega', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Tipo Documento: Pedido', style: pw.TextStyle(fontSize: 9)),
            pw.Divider(),
            pw.Text('Cliente: $nombreCliente', style: pw.TextStyle(fontSize: 9)),
            pw.Text('Código: $codigoCliente', style: pw.TextStyle(fontSize: 9)),
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
                  pw.Text('Impuesto 15%: L. ${(subtotal * 0.15).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
                  pw.Text('Impuesto 18%: L. ${(subtotal * 0.18).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
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
