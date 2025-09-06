import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/ui/screens/venta/invoice_detail_screen.dart';
import 'dart:convert';

class VentasListScreen extends StatefulWidget {
  const VentasListScreen({super.key, this.vendedorId});

  final int? vendedorId;

  @override
  State<VentasListScreen> createState() => _VentasListScreenState();
}

class _VentasListScreenState extends State<VentasListScreen> {
  final VentaService _ventaService = VentaService();
  final PerfilUsuarioService _perfilService = PerfilUsuarioService();
  List<dynamic> permisos = [];
  bool _isLoading = true;
  List<dynamic> _ventas = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPermisos();
    _loadVentas();
  }

  Future<void> _loadPermisos() async {
    final userData = await _perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  Future<void> _loadVentas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final response = await _ventaService.listarVentasPorVendedor(
        widget.vendedorId ?? 13
      );

      if (response != null && response['success'] == true) {
        setState(() {
          _ventas = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response?['message'] ?? 'Error al cargar las ventas';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToInvoiceDetail(int factId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(facturaId: factId, facturaNumero: 'N/A'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      title: 'Mis Ventas',
      icon: Icons.receipt_long,
      permisos: permisos,
      onRefresh: _loadVentas,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              const Text(
                'Historial de ventas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF141A2F),
                    ),
                  ),
                )
              else if (_error != null)
                _buildErrorWidget()
              else if (_ventas.isEmpty)
                _buildEmptyWidget()
              else
                _buildVentasList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFFFF3B30),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Satoshi',
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadVentas,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141A2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Color(0xFF8E8E93),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay ventas registradas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
              color: Color(0xFF141A2F),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las ventas que realices aparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Satoshi',
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentasList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _ventas.length,
      itemBuilder: (context, index) {
        final venta = _ventas[index];
        return _buildVentaCard(venta);
      },
    );
  }
  

  Widget _buildVentaCard(dynamic venta) {
    final factId = venta['fact_Id'] ?? 0;
    final factNumero = venta['fact_Numero']?.toString() ?? 'N/A';
    final fechaEmision = venta['fact_FechaEmision'] ?? '';
    final tipoDocumento = venta['fact_TipoDeDocumento']?.toString() ?? 'Factura';
    final clienteNombre = venta['cliente'] ?? 'Cliente General';
    final total = venta['fact_Total'] ?? 0.0;
    final estado = venta['fact_Anulado'] ?? 'Completada';

    // Configuración de colores según el estado
    Color primaryColor;
    Color secondaryColor;
    Color backgroundColor;
    IconData statusIcon;
    String statusLabel;

    switch (estado.toString().toLowerCase()) {
      case 'true':
        statusLabel = 'Anulada';
        primaryColor = const Color(0xFFFF3B30);
        secondaryColor = const Color(0xFFFF6B60);
        backgroundColor = const Color(0xFFFFE8E6);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusLabel = 'Completada';
        primaryColor = const Color(0xFF141A2F);
        secondaryColor = const Color(0xFF2C3655);
        backgroundColor = const Color(0xFFE8EAF6);
        statusIcon = Icons.check_circle_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => _navigateToInvoiceDetail(factId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, backgroundColor.withOpacity(0.3)],
                ),
              ),
              child: Column(
                children: [
                  // Header con gradiente de estado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$tipoDocumento #$factNumero',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Fecha de venta
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fecha de venta',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8E8E93),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatFechaFromApi(fechaEmision),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF141A2F),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Cliente
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cliente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8E8E93),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    clienteNombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF141A2F),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Total
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.attach_money_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8E8E93),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'L ${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A2F),
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatFechaFromApi(String fechaIso) {
    try {
      final date = DateTime.parse(fechaIso);
      return "${date.day} de ${_mesEnEspanol(date.month)} del ${date.year}";
    } catch (_) {
      return fechaIso;
    }
  }

  String _mesEnEspanol(int mes) {
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes];
  }
}