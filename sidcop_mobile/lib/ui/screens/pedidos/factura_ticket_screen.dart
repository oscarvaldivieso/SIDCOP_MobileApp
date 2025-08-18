import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/factura_ticket_pdf.dart';
import 'package:sidcop_mobile/services/EmpresaService.dart';
import 'package:sidcop_mobile/models/ConfiguracionFacturaViewModel.dart';
import 'package:screenshot/screenshot.dart';
//import 'package:share_plus/share_plus.dart';

class FacturaTicketScreen extends StatelessWidget {
  final String nombreCliente;
  final String codigoCliente;
  final String? direccion;
  final String? rtn;
  final String vendedor;
  final String fechaFactura;
  final String fechaEntrega;
  final String numeroFactura;
  final List<ProductoFactura> productos;
  final num subtotal;
  final num totalDescuento;
  final num total;
  final String totalEnLetras;
  final List<ConfiguracionFacturaViewModel> empresa;

  const FacturaTicketScreen({
    Key? key,
    required this.nombreCliente,
    required this.codigoCliente,
    this.direccion,
    this.rtn,
    required this.vendedor,
    required this.fechaFactura,
    required this.fechaEntrega,
    required this.numeroFactura,
    required this.productos,
    required this.subtotal,
    required this.totalDescuento,
    required this.total,
    required this.totalEnLetras,
    required this.empresa,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Factura',
      icon: Icons.receipt_long,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opciones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Descargar',
                  onPressed: () async {
                    try {
                      final pdfBytes = await generarFacturaPdf(
                        nombreCliente: nombreCliente,
                        codigoCliente: codigoCliente,
                        direccion: direccion,
                        rtn: rtn,
                        logo: empresa?[0].coFa_Logo,
                        nombreEmpresa: empresa?[0].coFa_NombreEmpresa,
                        direccionEmpresa:
                            '${empresa?[0].coFa_DireccionEmpresa ?? ''}, ${empresa?[0].muni_Descripcion ?? ''}, ${empresa?[0].depa_Descripcion ?? ''}',
                        telefonoEmpresa: empresa?[0].coFa_Telefono1,
                        correoEmpresa: empresa?[0].coFa_Correo,
                        vendedor: vendedor,
                        fechaFactura: fechaFactura,
                        fechaEntrega: fechaEntrega,
                        numeroFactura: numeroFactura,
                        productos: productos,
                        subtotal: subtotal,
                        totalDescuento: totalDescuento,
                        total: total,
                        totalEnLetras: totalEnLetras,
                      );

                      final directory =
                          await getApplicationDocumentsDirectory();
                      final filePath =
                          '${directory.path}/factura_${numeroFactura.replaceAll('/', '_')}.pdf';
                      final file = File(filePath);
                      await file.writeAsBytes(pdfBytes);

                      // Usar printing para mostrar y compartir el PDF
                      // await Printing.sharePdf(
                      //   bytes: pdfBytes,
                      //   filename: 'factura_${nombreCliente}, ${fechaFactura}.pdf',
                      // );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PDF generado exitosamente'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al generar PDF')),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Compartir',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    FontAwesomeIcons.whatsapp,
                    color: Colors.green,
                  ),
                  tooltip: 'Enviar por WhatsApp',
                  onPressed: () async {
                    try {
                      // Generar el PDF
                      final pdfBytes = await generarFacturaPdf(
                        nombreCliente: nombreCliente,
                        codigoCliente: codigoCliente,
                        direccion: direccion,
                        rtn: rtn,
                        logo: empresa?[0].coFa_Logo,
                        nombreEmpresa: empresa?[0].coFa_NombreEmpresa,
                        direccionEmpresa:
                            '${empresa?[0].coFa_DireccionEmpresa ?? ''}, ${empresa?[0].muni_Descripcion ?? ''}, ${empresa?[0].depa_Descripcion ?? ''}',
                        telefonoEmpresa: empresa?[0].coFa_Telefono1,
                        correoEmpresa: empresa?[0].coFa_Correo,
                        vendedor: vendedor,
                        fechaFactura: fechaFactura,
                        fechaEntrega: fechaEntrega,
                        numeroFactura: numeroFactura,
                        productos: productos,
                        subtotal: subtotal,
                        totalDescuento: totalDescuento,
                        total: total,
                        totalEnLetras: totalEnLetras,
                      );

                      // Crear mensaje para WhatsApp
                      final mensaje = Uri.encodeComponent(
                        '¡Hola! Te envío la factura $nombreCliente\n',
                      );

                      // Guardar PDF en almacenamiento temporal
                      final directory = await getTemporaryDirectory();
                      // Normalizar nombre de archivo
                      final safeNombre = nombreCliente.replaceAll(
                        RegExp(r'[^a-zA-Z0-9]'),
                        '_',
                      );
                      final safeFecha = fechaFactura.replaceAll(
                        RegExp(r'[^a-zA-Z0-9]'),
                        '_',
                      );
                      final filePath =
                          '${directory.path}/factura_${safeNombre}_${safeFecha}.pdf';
                      final file = File(filePath);
                      await file.writeAsBytes(pdfBytes);

                      // Verificar existencia antes de compartir
                      if (await file.exists()) {
                        await Share.shareXFiles(
                          [XFile(filePath)],
                          text: '¡Hola! Te envío la factura $nombreCliente',
                          subject: 'Factura $nombreCliente',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selecciona WhatsApp o la app deseada para compartir el archivo.',
                              ),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Error: el archivo PDF no se generó correctamente.',
                              ),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al compartir por WhatsApp: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Encabezado
            Center(
              child: Column(
                children: [
                  Image.network(
                    '${empresa[0].coFa_Logo}',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'COMERCIAL LA ROCA S. DE R.L.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Casa Matriz\n1ra Ave, 5ta Calle...',
                  ), // Puedes expandir con datos reales
                  const SizedBox(height: 4),
                  Text('Tel: (504) 2516-4076 / 4189 / 4190 / 4191'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // CAI y datos de factura
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fecha Emisión: $fechaFactura'),
                Text('Fecha Entrega: $fechaEntrega'),
                const Text('Tipo Factura: Pedido'),
              ],
            ),
            const SizedBox(height: 16),
            // Datos de factura y cliente
            Text('Cliente: $nombreCliente'),
            Text('Código: $codigoCliente'),
            if (direccion != null && direccion!.isNotEmpty)
              Text('Dirección: $direccion'),
            if (rtn != null && rtn!.isNotEmpty) Text('RTN: $rtn'),
            Text('Vendedor: $vendedor'),
            const Divider(height: 24),
            // Tabla de productos
            Row(
              children: const [
                Expanded(
                  child: Text(
                    'Und',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Producto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Precio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Desc.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Monto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            ...productos.map(
              (p) => Row(
                children: [
                  Expanded(child: Text('${p.cantidad}')),
                  Expanded(flex: 3, child: Text(p.nombre)),
                  Expanded(child: Text('L. ${p.precio.toStringAsFixed(2)}')),
                  Expanded(child: Text(p.descuentoStr)),
                  Expanded(
                    child: Text(
                      'L. ${(p.precioFinal * p.cantidad).toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Resumen
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sub-total: L. ${subtotal.toStringAsFixed(2)}'),
                  Text(
                    'Total Descuento: L. ${totalDescuento.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Impuestos: L. ${_calcularTotalImpuestos(productos).toStringAsFixed(2)}',
                  ),
                  Text(
                    'Total: L. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('*$totalEnLetras*'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Pie
          ],
        ),
      ),
    );
  }

  double _calcularTotalImpuestos(List<ProductoFactura> productos) {
    double total = 0.0;
    for (var p in productos) {
      total += p.impuesto * p.cantidad;
    }
    return total;
  }
}

class ProductoFactura {
  final String nombre;
  final int cantidad;
  final num precio;
  final num precioFinal;
  final String descuentoStr;
  final num impuesto; // Nuevo campo

  ProductoFactura({
    required this.nombre,
    required this.cantidad,
    required this.precio,
    required this.precioFinal,
    required this.descuentoStr,
    this.impuesto = 0,
  });
}
