import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/cuentasPorCobrarDetails_screen.dart';


class CxCScreen extends StatefulWidget {
  const CxCScreen({super.key});

  @override
  State<CxCScreen> createState() => _CxCScreenState();
}

class _CxCScreenState extends State<CxCScreen> {
  final CuentasXCobrarService _cuentasService = CuentasXCobrarService();
  List<CuentasXCobrar> _cuentasPorCobrar = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCuentasPorCobrar();
  }

  Future<void> _loadCuentasPorCobrar() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await _cuentasService.getCuentasPorCobrar();
      final List<CuentasXCobrar> cuentas = response
          .map((item) {
            try {
              return CuentasXCobrar.fromJson(item);
            } catch (e) {
              print('❌ Error parseando item: $e');
              return null;
            }
          })
          .where((cuenta) => cuenta != null)
          .cast<CuentasXCobrar>()
          .toList();

      if (mounted) {
        setState(() {
          _cuentasPorCobrar = cuentas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Formatters optimizados
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    const mesesEspanol = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    
    return "${date.day} ${mesesEspanol[date.month]} ${date.year}";
  }
  
  String _formatCurrency(double? amount) => NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount ?? 0);

  // Status logic simplificada
  Map<String, dynamic> _getAccountStatus(CuentasXCobrar cuenta) {
    if (cuenta.cpCo_Anulado == true) {
      return _createStatusData('Anulado', const Color(0xFF8E44AD), Icons.cancel_rounded);
    }
    if (cuenta.cpCo_Saldada == true) {
      return _createStatusData('Saldado', const Color(0xFF2E86AB), Icons.check_circle_rounded);
    }
    if (cuenta.cpCo_FechaVencimiento != null && cuenta.cpCo_FechaVencimiento!.isBefore(DateTime.now())) {
      return _createStatusData('Vencido', const Color(0xFF1A365D), Icons.warning_rounded);
    }
    return _createStatusData('Pendiente', const Color(0xFF1E3A8A), Icons.schedule_rounded);
  }

  Map<String, dynamic> _createStatusData(String status, Color primaryColor, IconData icon) {
    return {
      'status': status,
      'primaryColor': primaryColor,
      'secondaryColor': Color.lerp(primaryColor, Colors.white, 0.2),
      'backgroundColor': primaryColor.withOpacity(0.1),
      'icon': icon,
    };
  }

  bool _isOverdue(CuentasXCobrar cuenta) =>
      cuenta.cpCo_FechaVencimiento != null &&
      cuenta.cpCo_FechaVencimiento!.isBefore(DateTime.now()) &&
      cuenta.cpCo_Saldada != true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Cuentas por Cobrar',
        icon: Icons.receipt_long,
        onRefresh: _loadCuentasPorCobrar,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_cuentasPorCobrar.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSummaryHeader(),
        ),
        ..._cuentasPorCobrar.map((cuenta) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: _buildCuentaCard(cuenta),
        )).toList(),
        const SizedBox(height: 80), // Espacio inferior para poder hacer scroll
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A))),
          SizedBox(height: 16),
          Text('Cargando cuentas por cobrar...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
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
          Text('No hay cuentas por cobrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Satoshi')),
          SizedBox(height: 8),
          Text('Desliza hacia abajo para actualizar', style: TextStyle(color: Colors.grey, fontFamily: 'Satoshi')),
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
          Text('Error al cargar las cuentas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[600], fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontFamily: 'Satoshi')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _loadCuentasPorCobrar,
            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final stats = _calculateStats();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen de Cuentas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Total', stats['total'].toString(), Icons.receipt_long_rounded)),
              Expanded(child: _buildSummaryItem('Pendientes', stats['pending'].toString(), Icons.schedule_rounded)),
              Expanded(child: _buildSummaryItem('Vencidas', stats['overdue'].toString(), Icons.warning_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    return {
      'total': _cuentasPorCobrar.length,
      'pending': _cuentasPorCobrar.where((c) => c.cpCo_Saldada != true && c.cpCo_Anulado != true).length,
      'overdue': _cuentasPorCobrar.where(_isOverdue).length,
    };
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
      ],
    );
  }

  Widget _buildCuentaCard(CuentasXCobrar cuenta) {
  final statusData = _getAccountStatus(cuenta);
  final primaryColor = statusData['primaryColor'] as Color;
  final secondaryColor = statusData['secondaryColor'] as Color;
  final statusIcon = statusData['icon'] as IconData;
  final status = statusData['status'] as String;

  return GestureDetector(  // Agregar GestureDetector
    onTap: () => _navigateToDetail(cuenta),  // Agregar navegación
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildCardHeader(status, statusIcon, primaryColor, secondaryColor),
            _buildCardContent(cuenta, primaryColor),
          ],
        ),
      ),
    ),
  );
}


void _navigateToDetail(CuentasXCobrar cuenta) {
  if (cuenta.cpCo_Id != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuentasPorCobrarDetailsScreen(
          cuentaId: cuenta.cpCo_Id!,
          cuentaResumen: cuenta, // Pasar la cuenta completa para mostrar info básica mientras carga
        ),
      ),
    );
  }
}

  Widget _buildCardHeader(String status, IconData statusIcon, Color primaryColor, Color secondaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, secondaryColor])),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(statusIcon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Satoshi')),
                Text('Cuenta por cobrar', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(CuentasXCobrar cuenta, Color primaryColor) {
    return Container(
      color: Colors.white, // Fondo blanco para el contenido de la tarjeta
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildClientInfo(cuenta, primaryColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoBox('Valor Total', _formatCurrency(cuenta.cpCo_Valor), Icons.attach_money_rounded, primaryColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildInfoBox('Saldo Pendiente', _formatCurrency(cuenta.cpCo_Saldo), Icons.account_balance_wallet_rounded, _isOverdue(cuenta) ? Colors.red.shade600 : primaryColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDateInfo('Emisión', _formatDate(cuenta.cpCo_FechaEmision), Icons.calendar_today_rounded, primaryColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildDateInfo('Vencimiento', _formatDate(cuenta.cpCo_FechaVencimiento), Icons.event_rounded, _isOverdue(cuenta) ? Colors.red.shade600 : primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfo(CuentasXCobrar cuenta, Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.person_rounded, color: primaryColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
              const SizedBox(height: 2),
              Text('${cuenta.clie_Nombres ?? ''} ${cuenta.clie_Apellidos ?? ''}'.trim(), style: const TextStyle(color: Color(0xFF181E34), fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
              if (cuenta.clie_NombreNegocio?.isNotEmpty == true)
                Text(cuenta.clie_NombreNegocio!, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w400, fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Satoshi')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi'))]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi'))]),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Satoshi')),
      ],
    );
  }
}