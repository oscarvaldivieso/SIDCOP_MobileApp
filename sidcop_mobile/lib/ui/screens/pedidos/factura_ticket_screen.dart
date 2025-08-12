import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/utils/numero_en_letras.dart';

class FacturaTicketScreen extends StatefulWidget {
  final int clienteId;
  final int usuarioId;
  final String numeroFactura;
  final DateTime fechaFactura;
  final DateTime fechaLimite;
  final List<dynamic> productos;
  final num subtotal;
  final num totalDescuento;
  final num totalExento;
  final num totalExonerado;
  final num totalGravado15;
  final num totalGravado18;
  final num totalImpuesto15;
  final num totalImpuesto18;
  final num total;

  const FacturaTicketScreen({
    Key? key,
    required this.clienteId,
    required this.usuarioId,
    required this.numeroFactura,
    required this.fechaFactura,
    required this.fechaLimite,
    required this.productos,
    required this.subtotal,
    required this.totalDescuento,
    required this.totalExento,
    required this.totalExonerado,
    required this.totalGravado15,
    required this.totalGravado18,
    required this.totalImpuesto15,
    required this.totalImpuesto18,
    required this.total,
  }) : super(key: key);

  @override
  State<FacturaTicketScreen> createState() => _FacturaTicketScreenState();
}

class _FacturaTicketScreenState extends State<FacturaTicketScreen> {
  Map<String, dynamic>? cliente;
  Map<String, dynamic>? usuario;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final c = await ClientesService.getClienteById(widget.clienteId);
    final perfilService = PerfilUsuarioService();
    final u = await perfilService.obtenerDatosCompletoUsuario(widget.usuarioId);
    setState(() {
      cliente = c;
      usuario = u;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double ticketWidth = 350;
    const mono = TextStyle(fontFamily: 'RobotoMono', fontSize: 13);
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Datos de cliente y usuario
    final nombreCliente = cliente?['nombre'] ?? '';
    final codigoCliente = cliente?['codigo'] ?? '';
    final direccionCliente = cliente?['direccion'] ?? '';
    final rtnCliente = cliente?['rtn'] ?? '';
    final rutaCliente = cliente?['ruta'] ?? '';
    final nombreVendedor = usuario?['nombre'] ?? '';
    // Total en letras
    final totalEnLetras = NumeroEnLetras.convertir(widget.total);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Container(
          width: ticketWidth,
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo y encabezado
              Image.asset('assets/Sidcop_Logo.png', height: 48),
              const SizedBox(height: 4),
              Text('COMERCIAL LA ROCA S. DE R.L', style: mono.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text('Casa Matriz', style: mono.copyWith(fontWeight: FontWeight.bold)),
              Text('1ra Ave, 5ta Calle., N.O Bo. Guamilito, San Pedro Sula,\nHonduras, C.A', style: mono, textAlign: TextAlign.center),
              Text('Sucursal: Comercial La Roca Bo. Guamilito, 1ra Ave, 5ta Calle.,\nN.O San Pedro Sula, Cortes', style: mono, textAlign: TextAlign.center),
              Text('Telefono: (504) 2516-4076 / 4189 / 4190 / 4191', style: mono, textAlign: TextAlign.center),
              Text('E-mail: sac@comerciallaroca.com / contabilidadlaroca@gmail.com', style: mono, textAlign: TextAlign.center),
              Text('05019002058978', style: mono, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              // CAI y metadatos
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('C.A.I: 31FB47-AFB25B-872CE0-63BE03-090949-03', style: mono.copyWith(fontWeight: FontWeight.bold)),
                    Text('No. Factura: ${widget.numeroFactura}', style: mono.copyWith(fontWeight: FontWeight.bold)),
                    Text('Fecha Emision: ${widget.fechaFactura.day}/${widget.fechaFactura.month}/${widget.fechaFactura.year} ${widget.fechaFactura.hour}:${widget.fechaFactura.minute.toString().padLeft(2, '0')}', style: mono),
                    Text('Tipo Venta: Contado', style: mono),
                    Text('Cliente: $nombreCliente', style: mono),
                    Text('Código Cliente: $codigoCliente', style: mono),
                    Text('Direccion Cliente: $direccionCliente', style: mono),
                    Text('RTN Cliente: $rtnCliente', style: mono),
                    Text('Ruta: $rutaCliente', style: mono),
                    Text('Vendedor: $nombreVendedor', style: mono),
                    Text('No. Orden de compra exenta:', style: mono),
                    Text('No. constancia de Reg. de exonerados', style: mono),
                    Text('No. Registro de la SAG', style: mono),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Cabecera de productos
              Row(
                children: [
                  Expanded(child: Text('Und', style: mono.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Prod', style: mono.copyWith(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Precio', style: mono.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  Expanded(child: Text('Monto', style: mono.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
              const Divider(thickness: 1),
              ...widget.productos.map<Widget>((p) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text('${p.cantidad}', style: mono)),
                  Expanded(flex: 3, child: Text('${p.nombre}\n${p.descripcion ?? ''}', style: mono)),
                  Expanded(child: Text(p.precioFinal.toStringAsFixed(2), style: mono, textAlign: TextAlign.right)),
                  Expanded(child: Text((p.precioFinal * p.cantidad).toStringAsFixed(2), style: mono, textAlign: TextAlign.right)),
                ],
              )),
              const Divider(thickness: 1),
              // Totales y desglose
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Sub-total: L. ${widget.subtotal.toStringAsFixed(2)}', style: mono),
                    Text('Total Descuento: L.${widget.totalDescuento.toStringAsFixed(2)}', style: mono),
                    Text('Importe Exento: L.${widget.totalExento.toStringAsFixed(2)}', style: mono),
                    Text('Importe Exonerado: L.${widget.totalExonerado.toStringAsFixed(2)}', style: mono),
                    Text('Importe Gravado 15%: L.${widget.totalGravado15.toStringAsFixed(2)}', style: mono),
                    Text('Importe Gravado 18%: L.${widget.totalGravado18.toStringAsFixed(2)}', style: mono),
                    Text('Total Impuesto 15%: L.${widget.totalImpuesto15.toStringAsFixed(2)}', style: mono),
                    Text('Total Impuesto 18%: L.${widget.totalImpuesto18.toStringAsFixed(2)}', style: mono),
                    Text('Total: L.${widget.total.toStringAsFixed(2)}', style: mono.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('*${totalEnLetras.toUpperCase()} LPS*', style: mono.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Pie de página
              Text('Fecha Límite Emision:', style: mono),
              Text('${widget.fechaLimite.day.toString().padLeft(2, '0')}/${widget.fechaLimite.month.toString().padLeft(2, '0')}/${widget.fechaLimite.year}', style: mono),
              Text('Rango Autorizado:', style: mono),
              Text('Desde: 000-044-01-00008801', style: mono),
              Text('Hasta: 000-044-01-00009500', style: mono),
              Text('Original: Cliente, Copia 1: Obligado Tributario Emisor', style: mono),
              Text('Copia 2: Archivo', style: mono),
              const SizedBox(height: 5),
              Text('Original', style: mono.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('LA FACTURA ES BENEFICIO DE TODOS, ¡EXIJALA!', style: mono, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
// --- Fin de la versión nueva. Todo lo que sigue es duplicado viejo y debe eliminarse ---
