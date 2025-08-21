import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<File> generateInvoicePdf(Map<String, dynamic> factura, String facturaNumero) async {
  final pdf = pw.Document();
  
  // Cargar logo si existe
  Uint8List logoBytes = Uint8List(0);
  if (factura['coFa_Logo'] != null && factura['coFa_Logo'].toString().isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(factura['coFa_Logo']));
      if (response.statusCode == 200) {
        logoBytes = response.bodyBytes;
      }
    } catch (e) {
      print('Error cargando logo: $e');
    }
  }
  final logo = logoBytes.isNotEmpty ? pw.MemoryImage(logoBytes) : null;

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        // ENCABEZADO DE EMPRESA - Centrado y simple
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 24),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo centrado
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
                    child: pw.Icon(
                      pw.IconData(0xe0af),
                      size: 40,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              
              // Nombre de la empresa
              pw.Text(
                factura['coFa_NombreEmpresa'] ?? 'EMPRESA',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex("#141A2F"),
                ),
                textAlign: pw.TextAlign.center,
              ),
              
              pw.SizedBox(height: 8),
              
              // Dirección
              if (factura['coFa_DireccionEmpresa']?.toString().isNotEmpty == true)
                pw.Text(
                  factura['coFa_DireccionEmpresa'],
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              
              pw.SizedBox(height: 4),
              
              // Casa Matriz
              pw.Text(
                "CASA MATRIZ",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex("#141A2F"),
                  letterSpacing: 1,
                ),
                textAlign: pw.TextAlign.center,
              ),
              
              pw.SizedBox(height: 8),
              
              // Información de contacto
              if (factura['coFa_Telefono1']?.toString().isNotEmpty == true)
                pw.Text(
                  "Tel: ${factura['coFa_Telefono1']}",
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center,
                ),
              
              pw.SizedBox(height: 4),
              
              if (factura['coFa_Correo']?.toString().isNotEmpty == true)
                pw.Text(
                  factura['coFa_Correo'],
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
                  textAlign: pw.TextAlign.center,
                ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // LÍNEA DIVISORIA SIMPLE
        pw.Container(
          height: 2,
          width: double.infinity,
          color: PdfColor.fromHex("#98BF4A"),
        ),

        pw.SizedBox(height: 16),

        // INFORMACIÓN DE LA FACTURA - Alineada a la izquierda como en la imagen
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // CAI
            _buildInfoRow("CAI:", factura['regC_Descripcion'] ?? 'N/A'),
            
            // Número de factura
            _buildInfoRow("No. Factura:", factura['fact_Numero'] ?? 'N/A'),
            
            // Fecha de emisión
            _buildInfoRow("Fecha de Emisión:", _formatDate(factura['fact_FechaEmision'])),
            
            // Tipo de venta
            _buildInfoRow("Tipo de Venta:", factura['fact_TipoVenta'] ?? 'N/A'),
            
            // Cliente
            _buildInfoRow("Cliente:", factura['cliente'] ?? 'Cliente General'),
            
            // Vendedor
            _buildInfoRow("Vendedor:", factura['vendedor'] ?? 'N/A'),
          ],
        ),

        pw.SizedBox(height: 20),

        // TABLA DE PRODUCTOS - Simple y limpia
        pw.Table.fromTextArray(
          headers: ["DESCRIPCIÓN", "CANT.", "PRECIO", "TOTAL"],
          headerStyle: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex("#141A2F"),
          ),
          cellStyle: pw.TextStyle(
            fontSize: 11,
            color: PdfColor.fromHex("#141A2F"),
          ),
          cellPadding: const pw.EdgeInsets.all(8),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          data: ((factura['detalleFactura'] as List<dynamic>?) ?? []).map((item) {
            final description = item['prod_Descripcion'] ?? 'Producto';
            final codigo = item['prod_CodigoBarra']?.toString();
            final fullDescription = codigo != null && codigo.isNotEmpty 
                ? '$description\nCódigo: $codigo' 
                : description;
            
            return [
              fullDescription,
              (item['faDe_Cantidad'] ?? 0).toStringAsFixed(0),
              "L ${(item['faDe_PrecioUnitario'] ?? 0).toStringAsFixed(2)}",
              "L ${(item['faDe_Total'] ?? 0).toStringAsFixed(2)}",
            ];
          }).toList(),
        ),

        pw.SizedBox(height: 20),

        // SECCIÓN DE TOTALES - Alineada a la derecha
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  // Subtotal
                  _buildTotalRow("Subtotal:", "L ${(factura['fact_Subtotal'] ?? 0).toStringAsFixed(2)}"),
                  
                  // Importes condicionalmente
                  if ((factura['fact_ImporteExento'] ?? 0) > 0)
                    _buildTotalRow("Importe Exento:", "L ${(factura['fact_ImporteExento']).toStringAsFixed(2)}"),
                  
                  if ((factura['fact_ImporteGravado15'] ?? 0) > 0)
                    _buildTotalRow("Importe Gravado 15%:", "L ${(factura['fact_ImporteGravado15']).toStringAsFixed(2)}"),
                  
                  if ((factura['fact_ImporteGravado18'] ?? 0) > 0)
                    _buildTotalRow("Importe Gravado 18%:", "L ${(factura['fact_ImporteGravado18']).toStringAsFixed(2)}"),
                  
                  if ((factura['fact_ImporteExonerado'] ?? 0) > 0)
                    _buildTotalRow("Importe Exonerado:", "L ${(factura['fact_ImporteExonerado']).toStringAsFixed(2)}"),
                  
                  if ((factura['fact_TotalDescuento'] ?? 0) > 0)
                    _buildTotalRow("Total Descuento:", "- L ${(factura['fact_TotalDescuento']).toStringAsFixed(2)}", isNegative: true),
                  
                  // ISV
                  if ((factura['fact_TotalImpuesto15'] ?? 0) > 0)
                    _buildTotalRow("ISV 15%:", "L ${(factura['fact_TotalImpuesto15']).toStringAsFixed(2)}"),
                  
                  if ((factura['fact_TotalImpuesto18'] ?? 0) > 0)
                    _buildTotalRow("ISV 18%:", "L ${(factura['fact_TotalImpuesto18']).toStringAsFixed(2)}"),
                  
                  pw.SizedBox(height: 8),
                  
                  // Total final justificado y destacado
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "TOTAL A PAGAR:",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex("#141A2F"),
                        ),
                      ),
                      pw.Text(
                        "L ${(factura['fact_Total'] ?? 0).toStringAsFixed(2)}",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex("#98BF4A"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/Factura_${factura['fact_Numero']}.pdf");
  await file.writeAsBytes(await pdf.save());
  return file;
}

// Función helper para crear filas de información
pw.Widget _buildInfoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex("#141A2F"),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.normal,
              color: PdfColor.fromHex("#141A2F"),
            ),
          ),
        ),
      ],
    ),
  );
}

// Función helper para crear filas de totales
pw.Widget _buildTotalRow(String label, String value, {bool isNegative = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.normal,
            color: PdfColor.fromHex("#141A2F"),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: isNegative ? PdfColors.red : PdfColor.fromHex("#141A2F"),
          ),
        ),
      ],
    ),
  );
}

// Función helper para formatear fecha
String _formatDate(dynamic fecha) {
  if (fecha == null) return 'N/A';
  
  try {
    if (fecha is DateTime) {
      return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
    } else if (fecha is String) {
      final parsedDate = DateTime.tryParse(fecha);
      if (parsedDate != null) {
        return "${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}";
      }
      return fecha;
    }
    return fecha.toString();
  } catch (e) {
    return 'N/A';
  }
}