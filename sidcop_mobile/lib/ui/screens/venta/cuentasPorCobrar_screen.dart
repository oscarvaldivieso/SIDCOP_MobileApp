import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/cuentasPorCobrarDetails_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
//import 'package:sidcop_mobile/ui/screens/venta/pagoCuentaPorCobrar_screen.dart';


class CxCScreen extends StatefulWidget {
  const CxCScreen({super.key});

  @override
  State<CxCScreen> createState() => _CxCScreenState();
}

class _CxCScreenState extends State<CxCScreen> {
  List<CuentasXCobrar> _cuentasPorCobrar = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCuentasPorCobrar();
    // Realizar sincronización inicial completa en background (incluye pagos)
    _sincronizacionInicialCompleta();
  }

  /// Realiza una sincronización completa inicial si hay conectividad
  Future<void> _sincronizacionInicialCompleta() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        print('🔄 Realizando sincronización inicial completa...');
        // Ejecutar sincronización completa en paralelo sin bloquear la UI
        CuentasPorCobrarOfflineService.sincronizacionCompleta().then((resultado) {
          print('✅ Sincronización inicial completa:');
          print('   - Éxito: ${resultado['exito']}');
          print('   - Datos sincronizados: ${resultado['sincronizacionDatos']}');
          print('   - Pagos sincronizados: ${resultado['pagosSincronizados']}');
          if ((resultado['errores'] as List?)?.isNotEmpty == true) {
            print('   - Errores: ${resultado['errores']}');
          }
        }).catchError((error) {
          print('⚠️ Error en sincronización inicial completa: $error');
        });
      } else {
        print('📱 Sin conexión, omitiendo sincronización inicial');
      }
    } catch (e) {
      print('Error en sincronización inicial: $e');
    }
  }

  Future<void> _loadCuentasPorCobrar() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      List<dynamic> response;
      
      // MODO OFFLINE PRIORITARIO - Siempre usar datos offline para inmediatez
      print('📱 Cargando datos offline actualizados para reflejo inmediato');
      response = await CuentasPorCobrarOfflineService.obtenerResumenClientesLocal();
      
      if (response.isEmpty) {
        print('⚠️ No hay datos offline disponibles');
      } else {
        print('✅ Cargados ${response.length} registros desde cache offline actualizado');
      }

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
      print('❌ Error general en _loadCuentasPorCobrar: $e');
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

  // Status logic actualizada para usar los colores de las cards de ventas
  Map<String, dynamic> _getAccountStatus(CuentasXCobrar cuenta) {
    if (cuenta.cpCo_Anulado == true) {
      return _createStatusData('Anulado', const Color(0xFFFF3B30), const Color(0xFFFF6B60), const Color(0xFFFFE8E6), Icons.cancel_rounded);
    }
    if (cuenta.cpCo_Saldada == true) {
      return _createStatusData('Saldado', const Color(0xFF141A2F), const Color(0xFF2C3655), const Color(0xFFE8EAF6), Icons.check_circle_rounded);
    }
    // Usar los nuevos campos de vencimiento - mantener rojo para vencidos
    if (cuenta.tieneDeudaVencida) {
      return _createStatusData('Vencido', const Color(0xFFFF3B30), const Color(0xFFFF6B60), const Color(0xFFFFE8E6), Icons.warning_rounded);
    }
    if ((cuenta.totalPendiente ?? 0) > 0) {
      return _createStatusData('Pendiente', const Color(0xFF141A2F), const Color(0xFF2C3655), const Color(0xFFE8EAF6), Icons.schedule_rounded);
    }
    return _createStatusData('Al Día', const Color(0xFF141A2F), const Color(0xFF2C3655), const Color(0xFFE8EAF6), Icons.check_circle_rounded);
  }

  Map<String, dynamic> _createStatusData(String status, Color primaryColor, Color secondaryColor, Color backgroundColor, IconData icon) {
    return {
      'status': status,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'backgroundColor': backgroundColor,
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

    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF141A2F),
            ),
          ),
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
          Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF8E8E93)),
          SizedBox(height: 16),
          Text('No hay cuentas por cobrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF141A2F), fontFamily: 'Satoshi')),
          SizedBox(height: 8),
          Text('Desliza hacia abajo para actualizar', style: TextStyle(color: Color(0xFF8E8E93), fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Color(0xFFFF3B30)),
          const SizedBox(height: 16),
          const Text('Error al cargar las cuentas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30), fontFamily: 'Satoshi')),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8E8E93), fontFamily: 'Satoshi')),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF141A2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loadCuentasPorCobrar,
            child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final stats = _calculateStats();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141A2F), Color(0xFF2C3655)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141A2F).withOpacity(0.15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen de Clientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildSummaryItem('Total', stats['total'].toString(), Icons.people_rounded)),
              Expanded(child: _buildSummaryItem('Pendientes', stats['pending'].toString(), Icons.schedule_rounded)),
              Expanded(child: _buildSummaryItem('Vencidos', stats['overdue'].toString(), Icons.warning_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total por Cobrar:', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
                Text(_formatCurrency(stats['totalAmount']), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Satoshi')),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Satoshi')),
      ],
    );
  }

  Widget _buildCuentaCard(CuentasXCobrar cuenta) {
    final statusData = _getAccountStatus(cuenta);
    final primaryColor = statusData['primaryColor'] as Color;
    final secondaryColor = statusData['secondaryColor'] as Color;
    final backgroundColor = statusData['backgroundColor'] as Color;
    final statusIcon = statusData['icon'] as IconData;
    final status = statusData['status'] as String;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => _navigateToDetail(cuenta),
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
                  _buildCardHeader(status, statusIcon, primaryColor, secondaryColor, cuenta),
                  _buildCardContent(cuenta, primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(CuentasXCobrar cuenta) async {
    if (cuenta.cpCo_Id != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CuentasPorCobrarDetailsScreen(
            cuentaId: cuenta.cpCo_Id!,
            cuentaResumen: cuenta,
          ),
        ),
      );
      
      // Si hubo cambios (como pagos), recargar los datos
      if (result != null && result['pagoRegistrado'] == true) {
        print('✅ Cambios detectados, recargando cuentas por cobrar...');
        _loadCuentasPorCobrar();
      }
    }
  }

  Widget _buildCardHeader(String status, IconData statusIcon, Color primaryColor, Color secondaryColor, CuentasXCobrar cuenta) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            child: Icon(statusIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Satoshi')),
                const SizedBox(height: 2),
                Text('No. ${cuenta.secuencia ?? "N/A"}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Satoshi')),
              ],
            ),
          ),
          if ((cuenta.facturasPendientes ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${cuenta.facturasPendientes} facturas', 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

Widget _buildCardContent(CuentasXCobrar cuenta, Color primaryColor) {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        _buildClientInfo(cuenta, primaryColor),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInfoBox('Total Facturado', _formatCurrency(cuenta.totalFacturado), Icons.receipt_rounded, primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoBox('Total Pendiente', _formatCurrency(cuenta.totalPendiente), Icons.account_balance_wallet_rounded, cuenta.tieneDeudaVencida ? const Color(0xFFFF3B30) : primaryColor)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInfoBox('Límite Crédito', _formatCurrency(cuenta.clie_LimiteCredito), Icons.credit_card_rounded, primaryColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildDateInfo('Último Pago', _formatDate(cuenta.ultimoPago), Icons.payment_rounded, primaryColor)),
          ],
        ),
        if (cuenta.tieneDeudaVencida) ...[
          const SizedBox(height: 16),
          _buildVencimientosInfo(cuenta),
        ],
        const SizedBox(height: 16),
        _buildActionButtons(cuenta, primaryColor),
      ],
    ),
  );
}

Widget _buildActionButtons(CuentasXCobrar cuenta, Color primaryColor) {
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

  Widget _buildClientInfo(CuentasXCobrar cuenta, Color primaryColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.store_rounded, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cliente', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93), fontFamily: 'Satoshi')),
              const SizedBox(height: 2),
              Text(cuenta.clie_NombreNegocio?? '', style: const TextStyle(color: Color(0xFF141A2F), fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
              if (cuenta.nombreCompleto.isNotEmpty == true)
                Text(cuenta.nombreCompleto, style: const TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500, fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Satoshi')),
              if (cuenta.clie_Telefono?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 4),
                    Text(cuenta.telefonoFormateado, style: const TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w400, fontSize: 12, fontFamily: 'Satoshi')),
                  ],
                ),
              ],
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: const TextStyle(
                    color: Color(0xFF8E8E93), 
                    fontWeight: FontWeight.w500, 
                    fontSize: 10, 
                    fontFamily: 'Satoshi'
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: const TextStyle(
                    color: Color(0xFF8E8E93), 
                    fontWeight: FontWeight.w500, 
                    fontSize: 10, 
                    fontFamily: 'Satoshi'
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }

  Widget _buildVencimientosInfo(CuentasXCobrar cuenta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_rounded, color: Color(0xFFFF3B30), size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Montos Vencidos', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Satoshi')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if ((cuenta.v1_30 ?? 0) > 0)
                Expanded(child: _buildVencimientoItem('1-30 días', cuenta.v1_30, const Color(0xFFFF8A65))),
              if ((cuenta.v31_60 ?? 0) > 0) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildVencimientoItem('31-60 días', cuenta.v31_60, const Color(0xFFFF5722))),
              ],
            ],
          ),
          if ((cuenta.v61_90 ?? 0) > 0 || (cuenta.mayor90 ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if ((cuenta.v61_90 ?? 0) > 0)
                  Expanded(child: _buildVencimientoItem('61-90 días', cuenta.v61_90, const Color(0xFFFF3B30))),
                if ((cuenta.mayor90 ?? 0) > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _buildVencimientoItem('+90 días', cuenta.mayor90, const Color(0xFFD32F2F))),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVencimientoItem(String label, double? amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 10, fontFamily: 'Satoshi')),
          const SizedBox(height: 4),
          Text(_formatCurrency(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Satoshi')),
        ],
      ),
    );
  }
}