import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';

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

  // MARK: - Data Loading
  Future<void> _loadCuentasPorCobrar() async {
    print('🔄 Iniciando carga de cuentas por cobrar...');
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      print('📡 Estado de loading establecido');

      final response = await _cuentasService.getCuentasPorCobrar();
      print('📥 Respuesta recibida: ${response.length} elementos');
      
      if (response.isNotEmpty) {
        print('📄 Primera respuesta: ${response.first}');
      } else {
        print('📭 Lista de respuesta vacía');
      }

      final List<CuentasXCobrar> cuentas = response
          .map((item) {
            try {
              return CuentasXCobrar.fromJson(item);
            } catch (e) {
              print('❌ Error parseando item: $item');
              print('❌ Error detalle: $e');
              return null;
            }
          })
          .where((cuenta) => cuenta != null)
          .cast<CuentasXCobrar>()
          .toList();
      
      print('✅ Cuentas convertidas: ${cuentas.length}');
      if (cuentas.isNotEmpty) {
        print('👤 Primera cuenta: ${cuentas.first.clie_Nombres} ${cuentas.first.clie_Apellidos}');
      }

      if (mounted) {
        setState(() {
          _cuentasPorCobrar = cuentas;
          _isLoading = false;
        });
        print('🎯 Estado actualizado - Loading: false, Cuentas: ${_cuentasPorCobrar.length}');
      }
    } catch (e, stackTrace) {
      print('❌ Error en _loadCuentasPorCobrar: $e');
      print('📚 StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // MARK: - Helper Methods
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double? amount) {
    if (amount == null) return 'L 0.00';
    final formatter = NumberFormat.currency(symbol: 'L ', decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatDateInSpanish(DateTime? date) {
    if (date == null) return 'N/A';
    
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    return "${date.day} de ${meses[date.month]} del ${date.year}";
  }

  // MARK: - Status Logic
  Map<String, dynamic> _getAccountStatus(CuentasXCobrar cuenta) {
    if (cuenta.cpCo_Anulado == true) {
      return {
        'status': 'Anulado',
        'primaryColor': const Color(0xFF8E44AD),
        'secondaryColor': const Color(0xFFAD5EC3),
        'backgroundColor': const Color(0xFFF3E5F5),
        'icon': Icons.cancel_rounded,
      };
    }

    if (cuenta.cpCo_Saldada == true) {
      return {
        'status': 'Saldado',
        'primaryColor': const Color(0xFF2E86AB),
        'secondaryColor': const Color(0xFF3A9BC1),
        'backgroundColor': const Color(0xFFE1F5FE),
        'icon': Icons.check_circle_rounded,
      };
    }

    if (cuenta.cpCo_FechaVencimiento != null && 
        cuenta.cpCo_FechaVencimiento!.isBefore(DateTime.now())) {
      return {
        'status': 'Vencido',
        'primaryColor': const Color(0xFF1A365D),
        'secondaryColor': const Color(0xFF2C5282),
        'backgroundColor': const Color(0xFFEBF4FF),
        'icon': Icons.warning_rounded,
      };
    }

    return {
      'status': 'Pendiente',
      'primaryColor': const Color(0xFF1E3A8A),
      'secondaryColor': const Color(0xFF3B82F6),
      'backgroundColor': const Color(0xFFDDEAFE),
      'icon': Icons.schedule_rounded,
    };
  }

  bool _isOverdue(CuentasXCobrar cuenta) {
    return cuenta.cpCo_FechaVencimiento != null && 
           cuenta.cpCo_FechaVencimiento!.isBefore(DateTime.now()) &&
           cuenta.cpCo_Saldada != true;
  }

  // MARK: - Build Methods
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Cuentas por Cobrar',
        icon: Icons.receipt_long,
        onRefresh: _loadCuentasPorCobrar,
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    print('🖼️ Construyendo contenido - Loading: $_isLoading, Error: $_errorMessage, Cuentas: ${_cuentasPorCobrar.length}');
    
    if (_isLoading) {
      print('⏳ Mostrando loading...');
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      print('⚠️ Mostrando error: $_errorMessage');
      return _buildErrorState();
    }
    
    if (_cuentasPorCobrar.isEmpty) {
      print('📭 Lista vacía');
      return _buildEmptyState();
    }

    print('📋 Mostrando lista con ${_cuentasPorCobrar.length} elementos');
    return Container(
      height: double.infinity,
      child: RefreshIndicator(
        onRefresh: _loadCuentasPorCobrar,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _cuentasPorCobrar.length + 1, // +1 para el header
          itemBuilder: (context, index) {
            print('🏗️ Construyendo item $index');
            try {
              if (index == 0) {
                print('📊 Construyendo header');
                return Column(
                  children: [
                    _buildSummaryHeader(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              
              final cuentaIndex = index - 1;
              if (cuentaIndex >= 0 && cuentaIndex < _cuentasPorCobrar.length) {
                final cuenta = _cuentasPorCobrar[cuentaIndex];
                print('🏗️ Construyendo cuenta $cuentaIndex: ${cuenta.clie_Nombres}');
                return _buildCuentaCard(cuenta);
              } else {
                print('❌ Índice fuera de rango: $cuentaIndex');
                return const SizedBox.shrink();
              }
            } catch (e) {
              print('❌ Error construyendo item $index: $e');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Error mostrando elemento $index: $e',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando cuentas por cobrar...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar las cuentas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loadCuentasPorCobrar,
            child: const Text(
              'Reintentar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
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
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No hay cuentas por cobrar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontFamily: 'Satoshi',
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Desliza hacia abajo para actualizar',
            style: TextStyle(
              color: Colors.grey,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final totalCuentas = _cuentasPorCobrar.length;
    final cuentasPendientes = _cuentasPorCobrar.where((c) => 
        c.cpCo_Saldada != true && c.cpCo_Anulado != true).length;
    final cuentasVencidas = _cuentasPorCobrar.where(_isOverdue).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Cuentas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total',
                  totalCuentas.toString(),
                  Icons.receipt_long_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Pendientes',
                  cuentasPendientes.toString(),
                  Icons.schedule_rounded,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Vencidas',
                  cuentasVencidas.toString(),
                  Icons.warning_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Satoshi',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }

  Widget _buildCuentaCard(CuentasXCobrar cuenta) {
    try {
      print('🎴 Construyendo card para: ${cuenta.clie_Nombres}');
      
      final statusData = _getAccountStatus(cuenta);
      final primaryColor = statusData['primaryColor'] as Color;
      final secondaryColor = statusData['secondaryColor'] as Color;
      final backgroundColor = statusData['backgroundColor'] as Color;
      final statusIcon = statusData['icon'] as IconData;
      final status = statusData['status'] as String;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                              Text(
                                'Cuenta por cobrar',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Información del cliente
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cliente',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cuenta.clie_Nombres ?? ''} ${cuenta.clie_Apellidos ?? ''}'.trim(),
                                    style: const TextStyle(
                                      color: Color(0xFF181E34),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  if (cuenta.clie_NombreNegocio?.isNotEmpty == true)
                                    Text(
                                      cuenta.clie_NombreNegocio!,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Valores monetarios
                        Row(
                          children: [
                            Expanded(
                              child: _buildMoneyInfo(
                                'Valor Total',
                                _formatCurrency(cuenta.cpCo_Valor),
                                Icons.attach_money_rounded,
                                primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMoneyInfo(
                                'Saldo Pendiente',
                                _formatCurrency(cuenta.cpCo_Saldo),
                                Icons.account_balance_wallet_rounded,
                                _isOverdue(cuenta) ? Colors.red.shade600 : primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Fechas
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateInfo(
                                'Emisión',
                                _formatDate(cuenta.cpCo_FechaEmision),
                                Icons.calendar_today_rounded,
                                primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDateInfo(
                                'Vencimiento',
                                _formatDate(cuenta.cpCo_FechaVencimiento),
                                Icons.event_rounded,
                                _isOverdue(cuenta) ? Colors.red.shade600 : primaryColor,
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
      );
    } catch (e, stackTrace) {
      print('❌ Error en _buildCuentaCard: $e');
      print('📚 StackTrace: $stackTrace');
      print('📄 Datos de cuenta: ${cuenta.toString()}');
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error al mostrar cuenta',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cliente: ${cuenta.clie_Nombres ?? 'N/A'} ${cuenta.clie_Apellidos ?? 'N/A'}',
              style: TextStyle(color: Colors.red.shade600),
            ),
            Text(
              'Error: $e',
              style: TextStyle(
                color: Colors.red.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMoneyInfo(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 10,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: 'Satoshi',
          ),
        ),
      ],
    );
  }
}