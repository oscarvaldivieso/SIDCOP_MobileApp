import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/cuentasPorCobrarDetails_screen.dart';
//import 'package:sidcop_mobile/ui/screens/venta/pagoCuentaPorCobrar_screen.dart';


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

      // Usar el nuevo endpoint de resumen por cliente
      final response = await _cuentasService.getResumenCliente();
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

  // Status logic actualizada para usar los nuevos campos
  Map<String, dynamic> _getAccountStatus(CuentasXCobrar cuenta) {
    if (cuenta.cpCo_Anulado == true) {
      return _createStatusData('Anulado', const Color(0xFF8E44AD), Icons.cancel_rounded);
    }
    if (cuenta.cpCo_Saldada == true) {
      return _createStatusData('Saldado', const Color(0xFF2E86AB), Icons.check_circle_rounded);
    }
    // Usar los nuevos campos de vencimiento
    if (cuenta.tieneDeudaVencida) {
      return _createStatusData('Vencido', const Color(0xFF1A365D), Icons.warning_rounded);
    }
    if ((cuenta.totalPendiente ?? 0) > 0) {
      return _createStatusData('Pendiente', const Color(0xFF1E3A8A), Icons.schedule_rounded);
    }
    return _createStatusData('Al Día', const Color(0xFF059669), Icons.check_circle_rounded);
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
          const Text('Resumen de Clientes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Total', stats['total'].toString(), Icons.people_rounded)),
              Expanded(child: _buildSummaryItem('Pendientes', stats['pending'].toString(), Icons.schedule_rounded)),
              Expanded(child: _buildSummaryItem('Vencidos', stats['overdue'].toString(), Icons.warning_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total por Cobrar:', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
                Text(_formatCurrency(stats['totalAmount']), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    double totalAmount = 0;
    int pendingCount = 0;
    int overdueCount = 0;

    for (var cuenta in _cuentasPorCobrar) {
      totalAmount += (cuenta.totalPendiente ?? 0);
      
      if ((cuenta.totalPendiente ?? 0) > 0 && cuenta.cpCo_Anulado != true) {
        pendingCount++;
      }
      
      if (cuenta.tieneDeudaVencida) {
        overdueCount++;
      }
    }

    return {
      'total': _cuentasPorCobrar.length,
      'pending': pendingCount,
      'overdue': overdueCount,
      'totalAmount': totalAmount,
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

    return GestureDetector(
      onTap: () => _navigateToDetail(cuenta),
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
              _buildCardHeader(status, statusIcon, primaryColor, secondaryColor, cuenta),
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
            cuentaResumen: cuenta,
          ),
        ),
      );
    }
  }

  Widget _buildCardHeader(String status, IconData statusIcon, Color primaryColor, Color secondaryColor, CuentasXCobrar cuenta) {
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
                Text('No. ${cuenta.secuencia ?? "N/A"}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          if ((cuenta.facturasPendientes ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${cuenta.facturasPendientes} facturas', 
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')
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
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _buildClientInfo(cuenta, primaryColor),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoBox('Total Facturado', _formatCurrency(cuenta.totalFacturado), Icons.receipt_rounded, primaryColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildInfoBox('Total Pendiente', _formatCurrency(cuenta.totalPendiente), Icons.account_balance_wallet_rounded, cuenta.tieneDeudaVencida ? Colors.red.shade600 : primaryColor)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoBox('Límite Crédito', _formatCurrency(cuenta.clie_LimiteCredito), Icons.credit_card_rounded, Colors.blue.shade600)),
            const SizedBox(width: 8),
            Expanded(child: _buildDateInfo('Último Pago', _formatDate(cuenta.ultimoPago), Icons.payment_rounded, Colors.green.shade600)),
          ],
        ),
        if (cuenta.tieneDeudaVencida) ...[
          const SizedBox(height: 12),
          _buildVencimientosInfo(cuenta),
        ],
        // NUEVO: Agregar botón de Registrar Pago
        const SizedBox(height: 16),
        _buildActionButtons(cuenta, primaryColor),
      ],
    ),
  );
}

Widget _buildActionButtons(CuentasXCobrar cuenta, Color primaryColor) {
  //final bool tienePendiente = (cuenta.totalPendiente ?? 0) > 0;
  //final bool estaAnulado = cuenta.cpCo_Anulado == true;
  //final bool estaSaldado = cuenta.cpCo_Saldada == true;
  
  return Row(
    children: [
      // Botón Ver Detalles
      Expanded(
        flex: 2,
        child: OutlinedButton.icon(
          onPressed: () => _navigateToDetail(cuenta),
          icon: Icon(Icons.visibility_rounded, size: 16, color: primaryColor),
          label: const Text('Ver Detalles', style: TextStyle(fontSize: 12, fontFamily: 'Satoshi')),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
      
      const SizedBox(width: 8),
      
     
    ],
  );
}

// void _navigateToPaymentScreen(CuentasXCobrar cuenta) async {
//   final result = await Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => PagoCuentaPorCobrarScreen(
//         cuentaResumen: cuenta,
//       ),
//     ),
//   );
  
//   // Si el pago fue exitoso, recargar la lista
//   if (result == true) {
//     _loadCuentasPorCobrar();
//   }
// }

  Widget _buildClientInfo(CuentasXCobrar cuenta, Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.store_rounded, color: primaryColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
              const SizedBox(height: 2),
              Text(cuenta.nombreCompleto, style: const TextStyle(color: Color(0xFF181E34), fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
              if (cuenta.clie_NombreNegocio?.isNotEmpty == true)
                Text(cuenta.clie_NombreNegocio!, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Satoshi')),
              if (cuenta.clie_Telefono?.isNotEmpty == true)
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(cuenta.telefonoFormateado, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w400, fontSize: 12, fontFamily: 'Satoshi')),
                  ],
                ),
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

  Widget _buildVencimientosInfo(CuentasXCobrar cuenta) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red.shade600, size: 14),
              const SizedBox(width: 4),
              Text('Montos Vencidos', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Satoshi')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if ((cuenta.v1_30 ?? 0) > 0)
                Expanded(child: _buildVencimientoItem('1-30 días', cuenta.v1_30, Colors.orange.shade600)),
              if ((cuenta.v31_60 ?? 0) > 0)
                Expanded(child: _buildVencimientoItem('31-60 días', cuenta.v31_60, Colors.red.shade500)),
            ],
          ),
          if ((cuenta.v61_90 ?? 0) > 0 || (cuenta.mayor90 ?? 0) > 0)
            const SizedBox(height: 8),
          if ((cuenta.v61_90 ?? 0) > 0 || (cuenta.mayor90 ?? 0) > 0)
            Row(
              children: [
                if ((cuenta.v61_90 ?? 0) > 0)
                  Expanded(child: _buildVencimientoItem('61-90 días', cuenta.v61_90, Colors.red.shade600)),
                if ((cuenta.mayor90 ?? 0) > 0)
                  Expanded(child: _buildVencimientoItem('+90 días', cuenta.mayor90, Colors.red.shade800)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildVencimientoItem(String label, double? amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 9, fontFamily: 'Satoshi')),
          const SizedBox(height: 2),
          Text(_formatCurrency(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }
}