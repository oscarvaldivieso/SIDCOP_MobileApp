import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';

class CuentasPorCobrarDetailsScreen extends StatefulWidget {
  final int cuentaId;
  final CuentasXCobrar cuentaResumen;

  const CuentasPorCobrarDetailsScreen({
    Key? key,
    required this.cuentaId,
    required this.cuentaResumen,
  }) : super(key: key);

  @override
  State<CuentasPorCobrarDetailsScreen> createState() => _CuentasPorCobrarDetailsScreenState();
}

class _CuentasPorCobrarDetailsScreenState extends State<CuentasPorCobrarDetailsScreen> {
  final CuentasXCobrarService _cuentasService = CuentasXCobrarService();
  Map<String, dynamic>? _cuentaDetalle;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCuentaDetalle();
  }

  Future<void> _loadCuentaDetalle() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final detalle = await _cuentasService.getCuentaPorCobrarDetalle(widget.cuentaId);
      
      if (mounted) {
        setState(() {
          _cuentaDetalle = detalle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el detalle: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatCurrency(double? amount) => NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount ?? 0);

  // Status logic (igual que en la pantalla principal)
  Map<String, dynamic> _getAccountStatus() {
    final cuenta = widget.cuentaResumen;
    if (cuenta.cpCo_Anulado == true) {
      return {'status': 'Anulado', 'color': const Color(0xFF8E44AD), 'icon': Icons.cancel_rounded};
    }
    if (cuenta.cpCo_Saldada == true) {
      return {'status': 'Saldado', 'color': const Color(0xFF2E86AB), 'icon': Icons.check_circle_rounded};
    }
    if (cuenta.cpCo_FechaVencimiento != null && cuenta.cpCo_FechaVencimiento!.isBefore(DateTime.now())) {
      return {'status': 'Vencido', 'color': const Color(0xFF1A365D), 'icon': Icons.warning_rounded};
    }
    return {'status': 'Pendiente', 'color': const Color(0xFFEF6C00), 'icon': Icons.schedule_rounded};
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    body: AppBackground(
      title: 'Detalles de Cuenta por Cobrar',
      icon: Icons.receipt_long,
      onRefresh: _loadCuentaDetalle,
      child: _buildContent(),
    ),
    bottomNavigationBar: _buildBottomButton(),
  );
}

Widget _buildBottomButton() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () {
        // Aquí iría la lógica para registrar el pago
        // Por ahora solo muestra un snackbar de prueba
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Próximamente UwU')),
        );
      },
      child: const Text(
        'REGISTRAR PAGO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Satoshi',
        ),
      ),
    ),
  );
}

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_cuentaDetalle == null) return _buildEmptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildClientSection(),
          const SizedBox(height: 16),
          _buildAccountDetailsSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A))),
          SizedBox(height: 16),
          Text('Cargando detalles...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text('Error al cargar el detalle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[600], fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontFamily: 'Satoshi')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _loadCuentaDetalle,
            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('No se encontraron detalles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final statusData = _getAccountStatus();
    final statusColor = statusData['color'] as Color;
    final statusIcon = statusData['icon'] as IconData;
    final status = statusData['status'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
                const SizedBox(height: 4),
                Text('${widget.cuentaId}', style: const TextStyle(color: Color(0xFF181E34), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection() {
    return _buildSection(
      title: 'Información del Cliente',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _buildDetailRow('Cliente:', '${_cuentaDetalle!['clie_Nombres'] ?? ''} ${_cuentaDetalle!['clie_Apellidos'] ?? ''}'.trim()),
          if (_cuentaDetalle!['clie_NombreNegocio']?.toString().isNotEmpty == true)
            _buildDetailRow('Negocio:', _cuentaDetalle!['clie_NombreNegocio'].toString()),
          if (_cuentaDetalle!['clie_Telefono']?.toString().isNotEmpty == true)
            _buildDetailRow('Teléfono:', _cuentaDetalle!['clie_Telefono'].toString()),
          _buildDetailRow('Límite de Crédito:', _formatCurrency(_cuentaDetalle!['clie_LimiteCredito']?.toDouble())),
          _buildDetailRow('Saldo Actual:', _formatCurrency(_cuentaDetalle!['clie_Saldo']?.toDouble())),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsSection() {
    final valorTotal = _cuentaDetalle!['cpCo_Valor']?.toDouble() ?? 0;
    final saldoPendiente = _cuentaDetalle!['cpCo_Saldo']?.toDouble() ?? 0;
    final pagado = valorTotal - saldoPendiente;

    return _buildSection(
      title: 'Detalle de la Cuenta',
      icon: Icons.receipt_rounded,
      child: Column(
        children: [
          if (_cuentaDetalle!['fact_Id'] != null)
            _buildDetailRow('Factura:', _cuentaDetalle!['fact_Id'].toString()),
          _buildDetailRow('Fecha de Emisión:', _formatDate(_parseDate(_cuentaDetalle!['cpCo_FechaEmision']))),
          _buildDetailRow('Fecha de Vencimiento:', _formatDate(_parseDate(_cuentaDetalle!['cpCo_FechaVencimiento']))),
          const Divider(height: 24),
          _buildDetailRow('Valor Total:', _formatCurrency(valorTotal), isHighlighted: true),
          _buildDetailRow('Saldo Pendiente:', _formatCurrency(saldoPendiente), isHighlighted: true),
          _buildDetailRow('Pagado:', _formatCurrency(pagado)),
          if (_cuentaDetalle!['cpCo_Observaciones']?.toString().isNotEmpty == true) ...[
            const Divider(height: 24),
            _buildDetailRow('Observaciones:', _cuentaDetalle!['cpCo_Observaciones'].toString(), isMultiline: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Color(0xFF181E34), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false, bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? const Color(0xFF1E3A8A) : const Color(0xFF181E34),
                fontSize: isHighlighted ? 16 : 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) return DateTime.tryParse(dateValue);
    return null;
  }
}