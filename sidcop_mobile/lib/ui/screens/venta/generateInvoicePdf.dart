import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<File> generateInvoicePdf(Map<String, dynamic> factura, String facturaNumero) async {
  final pdf = pw.Document();
  Uint8List logoBytes = Uint8List(0);
  if (factura['coFa_Logo'] != null && factura['coFa_Logo'].toString().isNotEmpty) {
    final response = await http.get(Uri.parse(factura['coFa_Logo']));
    if (response.statusCode == 200) {
      logoBytes = response.bodyBytes;
    }
  }
  final logo = logoBytes.isNotEmpty ? pw.MemoryImage(logoBytes) : null;

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // ENCABEZADO DE EMPRESA
        pw.Column(
          children: [
            if (logo != null)
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                  image: pw.DecorationImage(
                    image: logo,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              )
            else
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#98BF4A"),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Center(
                  child: pw.Icon(pw.IconData(0xe0af), size: 40, color: PdfColors.white),
                ),
              ),
            pw.Text(
              factura['coFa_NombreEmpresa'] ?? 'Empresa',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#141A2F"),
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              factura['coFa_DireccionEmpresa'] ?? '',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "CASA MATRIZ",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex("#141A2F"),
              ),
            ),
            pw.SizedBox(height: 8),
            if (factura['coFa_Telefono1']?.toString().isNotEmpty == true)
              pw.Text("Tel: ${factura['coFa_Telefono1']}",
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
            if (factura['coFa_Correo']?.toString().isNotEmpty == true)
              pw.Text(factura['coFa_Correo'],
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey)),
          ],
        ),
        pw.SizedBox(height: 20),

        // ENCABEZADO DE FACTURA
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Divider(thickness: 2, color: PdfColor.fromHex("#98BF4A")),
            pw.Text("CAI: ${factura['regC_Descripcion'] ?? 'N/A'}",
                style: const pw.TextStyle(fontSize: 14)),
            pw.Text("No. Factura: ${factura['fact_Numero'] ?? 'N/A'}"),
            pw.Text("Fecha: ${factura['fact_FechaEmision']}"),
            pw.Text("Cliente: ${factura['cliente'] ?? 'Cliente General'}"),
            pw.Text("Vendedor: ${factura['vendedor'] ?? 'N/A'}"),
            pw.Divider(),
          ],
        ),

        // TABLA PRODUCTOS
        pw.Table.fromTextArray(
          headers: ["Descripción", "Cant.", "Precio", "Total"],
          headerStyle: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF141A2F)),
          cellStyle: const pw.TextStyle(fontSize: 12),
          data: (factura['detalleFactura'] as List<dynamic>)
              .map((item) => [
                    item['prod_Descripcion'] ?? 'Producto',
                    item['faDe_Cantidad'].toString(),
                    "L ${(item['faDe_PrecioUnitario']).toStringAsFixed(2)}",
                    "L ${(item['faDe_Total']).toStringAsFixed(2)}",
                  ])
              .toList(),
        ),

        pw.SizedBox(height: 20),

        // TOTALES
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text("Subtotal: L ${(factura['fact_Subtotal']).toStringAsFixed(2)}"),
            pw.Text("ISV 15%: L ${(factura['fact_TotalImpuesto15']).toStringAsFixed(2)}"),
            pw.Text("ISV 18%: L ${(factura['fact_TotalImpuesto18']).toStringAsFixed(2)}"),
            pw.Divider(),
            pw.Text("TOTAL A PAGAR: L ${(factura['fact_Total']).toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex("#98BF4A"),
                )),
          ],
        ),
      ],
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/Factura_$facturaNumero.pdf");
  await file.writeAsBytes(await pdf.save());
  return file;
}