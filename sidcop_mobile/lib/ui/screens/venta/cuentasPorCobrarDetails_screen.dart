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
  List<CuentasXCobrar> _timelineMovimientos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimelineCliente();
  }

  Future<void> _loadTimelineCliente() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Usar el ID del cliente desde el resumen
      final clienteId = widget.cuentaResumen.clie_Id;
      if (clienteId == null) {
        throw Exception('ID de cliente no disponible');
      }

      final response = await _cuentasService.getTimelineCliente(clienteId);
      final List<CuentasXCobrar> movimientos = response
          .map((item) {
            try {
              return CuentasXCobrar.fromJson(item);
            } catch (e) {
              print('❌ Error parseando movimiento: $e');
              return null;
            }
          })
          .where((movimiento) => movimiento != null)
          .cast<CuentasXCobrar>()
          .toList();

      // Ordenar por fecha descendente (más reciente primero)
      movimientos.sort((a, b) {
        final fechaA = a.fecha ?? a.cpCo_FechaCreacion;
        final fechaB = b.fecha ?? b.cpCo_FechaCreacion;
        if (fechaA == null && fechaB == null) return 0;
        if (fechaA == null) return 1;
        if (fechaB == null) return -1;
        return fechaB.compareTo(fechaA);
      });

      if (mounted) {
        setState(() {
          _timelineMovimientos = movimientos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el timeline: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    const mesesEspanol = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    
    return "${date.day} ${mesesEspanol[date.month]} ${date.year}";
  }

  String _formatCurrency(double? amount) => NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount ?? 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Timeline Cliente',
        icon: Icons.timeline,
        onRefresh: _loadTimelineCliente,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_timelineMovimientos.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildClientHeader(),
        ),
        ..._timelineMovimientos.map((movimiento) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: _buildMovimientoCard(movimiento),
        )).toList(),
        const SizedBox(height: 80),
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
          Text('Cargando timeline del cliente...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
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
          Text('Error al cargar el timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[600], fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontFamily: 'Satoshi')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _loadTimelineCliente,
            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No hay registros para este cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Text('El cliente no tiene movimientos registrados', style: TextStyle(color: Colors.grey, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildClientHeader() {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
                    const SizedBox(height: 2),
                    Text(widget.cuentaResumen.nombreCompleto, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
                  ],
                ),
              ),
            ],
          ),
          if (widget.cuentaResumen.clie_NombreNegocio?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.business_rounded, color: Colors.white.withOpacity(0.8), size: 14),
                  const SizedBox(width: 6),
                  Text(widget.cuentaResumen.clie_NombreNegocio!, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Satoshi')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Total Pendiente', _formatCurrency(widget.cuentaResumen.totalPendiente), Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryItem('Facturas', '${widget.cuentaResumen.facturasPendientes ?? 0}', Icons.receipt_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildMovimientoCard(CuentasXCobrar movimiento) {
    final isPago = movimiento.tipo?.toUpperCase() == 'PAGO';
    final isFactura = movimiento.tipo?.toUpperCase() == 'FACTURA';
    
    Color primaryColor;
    Color secondaryColor;
    IconData icon;
    
    if (isPago) {
      primaryColor = const Color(0xFF059669);
      secondaryColor = const Color(0xFF10B981);
      icon = Icons.payment_rounded;
    } else if (isFactura) {
      primaryColor = const Color(0xFF1E3A8A);
      secondaryColor = const Color(0xFF3B82F6);
      icon = Icons.receipt_long_rounded;
    } else {
      primaryColor = const Color(0xFF6B7280);
      secondaryColor = const Color(0xFF9CA3AF);
      icon = Icons.description_rounded;
    }

    return Container(
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
            _buildMovimientoHeader(movimiento, primaryColor, secondaryColor, icon),
            _buildMovimientoContent(movimiento, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientoHeader(CuentasXCobrar movimiento, Color primaryColor, Color secondaryColor, IconData icon) {
    final fecha = movimiento.fecha ?? movimiento.cpCo_FechaCreacion;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, secondaryColor])),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movimiento.tipo ?? 'MOVIMIENTO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Satoshi')),
                Text(_formatDate(fecha), style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          if (movimiento.referencia?.isNotEmpty == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Ref: ${movimiento.referencia}', 
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMovimientoContent(CuentasXCobrar movimiento, Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoBox('Monto', _formatCurrency(movimiento.monto), Icons.attach_money_rounded, primaryColor),
              ),
              const SizedBox(width: 8),
              if (movimiento.formaPago?.isNotEmpty == true)
                Expanded(
                  child: _buildInfoBox('Forma de Pago', movimiento.formaPago ?? 'N/A', Icons.payment_rounded, Colors.blue.shade600),
                ),
            ],
          ),
          if (movimiento.referencia?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Referencia:', movimiento.referencia ?? 'N/A', Icons.confirmation_number_rounded, Colors.grey.shade700),
          ],
        ],
      ),
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

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Satoshi')),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Satoshi')),
        ),
      ],
    );
  }
}