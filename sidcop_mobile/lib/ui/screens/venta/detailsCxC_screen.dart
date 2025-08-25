import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/services/PagosCxCService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/pagoCuentaPorCobrar_screen.dart';

class DetailsCxCScreen extends StatefulWidget {
  final int cpCoId;

  const DetailsCxCScreen({
    Key? key,
    required this.cpCoId,
  }) : super(key: key);

  @override
  State<DetailsCxCScreen> createState() => _DetailsCxCScreenState();
}

class _DetailsCxCScreenState extends State<DetailsCxCScreen> {
  final CuentasXCobrarService _cuentasService = CuentasXCobrarService();
  final PagoCuentasXCobrarService _pagosService = PagoCuentasXCobrarService();
  
  CuentasXCobrar? _cuentaDetalle;
  List<PagosCuentasXCobrar> _pagos = [];
  bool _isLoading = true;
  bool _isLoadingPagos = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadCuentaDetalle(),
      _loadPagos(),
    ]);
  }

  Future<void> _loadCuentaDetalle() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final cuenta = await _cuentasService.getDetalleCuentaPorCobrar(widget.cpCoId);
      
      if (mounted) {
        setState(() {
          _cuentaDetalle = cuenta;
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

  Future<void> _loadPagos() async {
    try {
      setState(() => _isLoadingPagos = true);

      final pagos = await _pagosService.listarPagosPorCuenta(widget.cpCoId);
      
      if (mounted) {
        setState(() {
          _pagos = pagos;
          _isLoadingPagos = false;
        });
      }
    } catch (e) {
      print('Error cargando pagos: $e');
      if (mounted) {
        setState(() {
          _pagos = [];
          _isLoadingPagos = false;
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

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatCurrency(double? amount) => NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount ?? 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Detalle Cuenta por Cobrar',
        icon: Icons.receipt_long,
        onRefresh: _loadData,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_cuentaDetalle == null) return _buildNotFoundState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildClientInfoCard(),
          const SizedBox(height: 16),
          _buildFinancialInfoCard(),
          const SizedBox(height: 16),
          _buildDatesCard(),
          const SizedBox(height: 16),
          _buildObservationsCard(),
          const SizedBox(height: 16),
          _buildPagosCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 32),
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
          Text('Cargando detalle...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
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
            onPressed: _loadData,
            child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Cuenta no encontrada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Text('No se pudo encontrar la cuenta solicitada', style: TextStyle(color: Colors.grey, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final cuenta = _cuentaDetalle!;
    final statusData = _getAccountStatus(cuenta);
    final primaryColor = statusData['primaryColor'] as Color;
    final statusIcon = statusData['icon'] as IconData;
    final status = statusData['status'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Icon(statusIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cuenta por Cobrar', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
                    const SizedBox(height: 4)
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildHeaderStat('Valor Inicial', _formatCurrency(cuenta.cpCo_Valor), Icons.receipt_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _buildHeaderStat('Saldo Actual', _formatCurrency(cuenta.cpCo_Saldo), Icons.account_balance_wallet_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    final cuenta = _cuentaDetalle!;
    
    return _buildCard(
      title: 'Información del Cliente',
      icon: Icons.person_rounded,
      color: const Color(0xFF1E3A8A),
      child: Column(
        children: [
          _buildDetailRow('Código', cuenta.clie_Codigo ?? 'N/A', Icons.tag_rounded),
          _buildDetailRow('Nombre', cuenta.clie_Nombres ?? 'N/A', Icons.person_outline_rounded),
          if (cuenta.clie_Apellidos?.isNotEmpty == true)
            _buildDetailRow('Apellidos', cuenta.clie_Apellidos!, Icons.person_outline_rounded),
          if (cuenta.clie_NombreNegocio?.isNotEmpty == true)
            _buildDetailRow('Negocio', cuenta.clie_NombreNegocio!, Icons.business_rounded),
          if (cuenta.clie_Telefono?.isNotEmpty == true)
            _buildDetailRow('Teléfono', cuenta.clie_Telefono!, Icons.phone_rounded),
        ],
      ),
    );
  }

  Widget _buildFinancialInfoCard() {
    final cuenta = _cuentaDetalle!;
    
    return _buildCard(
      title: 'Información Financiera',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF059669),
      child: Column(
        children: [
          _buildDetailRow('Valor Inicial', _formatCurrency(cuenta.cpCo_Valor), Icons.receipt_rounded),
          _buildDetailRow('Saldo Pendiente', _formatCurrency(cuenta.cpCo_Saldo), Icons.pending_actions_rounded),
          if (cuenta.clie_LimiteCredito != null && cuenta.clie_LimiteCredito! > 0)
            _buildDetailRow('Límite de Crédito', _formatCurrency(cuenta.clie_LimiteCredito), Icons.credit_card_rounded),
          if (cuenta.fact_Id != null)
            _buildDetailRow('ID Factura', cuenta.fact_Id.toString(), Icons.description_rounded),
        ],
      ),
    );
  }

  Widget _buildDatesCard() {
    final cuenta = _cuentaDetalle!;
    
    return _buildCard(
      title: 'Fechas Importantes',
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFF7C3AED),
      child: Column(
        children: [
          _buildDetailRow('Fecha Emisión', _formatDate(cuenta.cpCo_FechaEmision), Icons.today_rounded),
          _buildDetailRow('Fecha Vencimiento', _formatDate(cuenta.cpCo_FechaVencimiento), Icons.event_rounded),
        ],
      ),
    );
  }

  Widget _buildObservationsCard() {
    final cuenta = _cuentaDetalle!;
    
    if (cuenta.cpCo_Observaciones?.isEmpty != false) {
      return const SizedBox.shrink();
    }
    
    return _buildCard(
      title: 'Observaciones',
      icon: Icons.note_rounded,
      color: const Color(0xFF6B7280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              cuenta.cpCo_Observaciones!,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
          ),
        ],
      ),
    );
  }

  Widget _buildPagosCard() {
    return _buildCard(
      title: 'Historial de Pagos',
      icon: Icons.payment_rounded,
      color: const Color(0xFF059669),
      child: _isLoadingPagos ? _buildPagosLoading() : _buildPagosContent(),
    );
  }

  Widget _buildPagosLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              strokeWidth: 2,
            ),
            SizedBox(height: 12),
            Text('Cargando pagos...', 
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey, 
                fontFamily: 'Satoshi'
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagosContent() {
    if (_pagos.isEmpty) {
      return _buildNoPagosState();
    }

    return Column(
      children: [
        // Header con resumen
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF059669).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.summarize_rounded, color: const Color(0xFF059669), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total de pagos registrados: ${_pagos.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
              // Text(
              //   _formatCurrency(_pagos.fold(0.0, (sum, pago) => sum + (pago.pagoMonto ?? 0.0))),
              //   style: const TextStyle(
              //     fontSize: 14,
              //     fontWeight: FontWeight.bold,
              //     color: Color(0xFF059669),
              //     fontFamily: 'Satoshi',
              //   ),
              // ),
            ],
          ),
        ),
        
        // Lista de pagos
        ..._pagos.asMap().entries.map((entry) {
          final index = entry.key;
          final pago = entry.value;
          return Column(
            children: [
              _buildPagoItem(pago),
              if (index < _pagos.length - 1) 
                const Divider(height: 24, color: Colors.grey),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNoPagosState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 32,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin pagos registrados',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aún no se han registrado pagos para esta cuenta',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontFamily: 'Satoshi',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagoItem(PagosCuentasXCobrar pago) {
    final bool isAnulado = pago.pagoAnulado;
    final Color statusColor = isAnulado ? Colors.red.shade600 : const Color(0xFF059669);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header del pago
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isAnulado ? Icons.cancel_rounded : Icons.check_circle_rounded,
                  color: statusColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isAnulado) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'ANULADO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatDateTime(pago.pagoFecha),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(pago.pagoMonto),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Detalles del pago
          Row(
            children: [
              Expanded(
                child: _buildPagoDetailItem('Forma de Pago', pago.pagoFormaPago, Icons.payment_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPagoDetailItem('Referencia', pago.pagoNumeroReferencia, Icons.confirmation_number_rounded),
              ),
            ],
          ),
          
          if (pago.pagoObservaciones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_rounded, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pago.pagoObservaciones,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontFamily: 'Satoshi',
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagoDetailItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : 'N/A',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF181E34),
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final cuenta = _cuentaDetalle!;
    final bool tienePendiente = (cuenta.cpCo_Saldo ?? 0) > 0;
    final bool estaAnulado = cuenta.cpCo_Anulado == true;
    final bool estaSaldado = cuenta.cpCo_Saldada == true;
    
    return Row(
      children: [
        // Botón Registrar Pago (solo si tiene saldo pendiente y no está anulado ni saldado)
        if (tienePendiente && !estaAnulado && !estaSaldado)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPaymentScreen(),
              icon: const Icon(Icons.payment_rounded, size: 18, color: Colors.white),
              label: const Text('Registrar Pago', style: TextStyle(fontSize: 14, fontFamily: 'Satoshi', color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToPaymentScreen() async {
    final cuenta = _cuentaDetalle!;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PagoCuentaPorCobrarScreen(
          cuentaResumen: cuenta,
        ),
      ),
    );
    
    // Si el pago fue exitoso, recargar los datos y regresar
    if (result == true) {
      await _loadData();
      if (mounted) {
        Navigator.pop(context, true); // Regresar con resultado exitoso
      }
    }
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 14, fontFamily: 'Satoshi')),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Color(0xFF181E34), fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getAccountStatus(CuentasXCobrar cuenta) {
    if (cuenta.cpCo_Anulado == true) {
      return _createStatusData('Anulado', const Color(0xFF8E44AD), Icons.cancel_rounded);
    }
    if (cuenta.cpCo_Saldada == true) {
      return _createStatusData('Saldado', const Color(0xFF2E86AB), Icons.check_circle_rounded);
    }
    
    final saldo = cuenta.cpCo_Saldo ?? 0;
    final vencimiento = cuenta.cpCo_FechaVencimiento;
    
    if (saldo <= 0) {
      return _createStatusData('Al Día', const Color(0xFF059669), Icons.check_circle_rounded);
    }
    
    if (vencimiento != null && DateTime.now().isAfter(vencimiento)) {
      return _createStatusData('Vencido', const Color(0xFFDC2626), Icons.warning_rounded);
    }
    
    return _createStatusData('Pendiente', const Color(0xFF1E3A8A), Icons.schedule_rounded);
  }

  Map<String, dynamic> _createStatusData(String status, Color primaryColor, IconData icon) {
    return {
      'status': status,
      'primaryColor': primaryColor,
      'icon': icon,
    };
  }
}