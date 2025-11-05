import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/pagoCuentaPorCobrar_screen.dart';
import 'package:sidcop_mobile/ui/screens/venta/detailsCxC_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';

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
  List<CuentasXCobrar> _timelineMovimientos = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Variable para el saldo actualizado dinámicamente
  double? _saldoActualizado;
  
  // Cache de saldos actualizados por cuenta específica
  Map<int, double> _saldosActualizadosCache = {};

  @override
  void initState() {
    super.initState();
    _loadTimelineCliente();
    
    // Cargar el saldo actualizado inmediatamente
    _actualizarInformacionCuenta();
    
    // Pre-cargar datos del cliente en background si es necesario
    if (widget.cuentaResumen.clie_Id != null) {
      Future.microtask(() => 
        CuentasPorCobrarOfflineService.precargarDatosCliente(widget.cuentaResumen.clie_Id!)
      );
    }
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

      List<dynamic> response;
      
      // VERIFICAR CONECTIVIDAD PARA FORZAR RECARGA CUANDO SEA POSIBLE
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected && globalVendId != null) {
        print('🔄 Conexión disponible - Forzando recarga timeline para cliente $clienteId');
        try {
          // Forzar sincronización del timeline del cliente desde el servidor
          response = await CuentasPorCobrarOfflineService.sincronizarTimelineCliente(clienteId);
          print('✅ Timeline recargado desde servidor: ${response.length} movimientos');
        } catch (e) {
          print('⚠️ Error recargando timeline desde servidor, usando datos offline: $e');
          // Fallback a datos offline si falla la sincronización
          response = await CuentasPorCobrarOfflineService.obtenerTimelineClienteLocal(clienteId);
        }
      } else {
        // Sin conexión, usar datos offline
        print('📱 Sin conexión - Usando timeline offline para cliente $clienteId');
        response = await CuentasPorCobrarOfflineService.obtenerTimelineClienteLocal(clienteId);
      }
      
      // Si no hay datos offline, intentar cargar datos generales del cliente
      if (response.isEmpty) {
        response = await _buscarMovimientosClienteEnResumenGeneral(clienteId);
      }
      final List<CuentasXCobrar> movimientos = response
          .map((item) {
            try {
              return CuentasXCobrar.fromJson(item);
            } catch (e) {
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

      
      // Log adicional para debug
      if (movimientos.isNotEmpty) {
        final tiposMovimientos = <String, int>{};
        for (final mov in movimientos) {
          final tipo = mov.tipo ?? (mov.referencia?.contains('F') == true ? 'FACTURA' : 'OTRO');
          tiposMovimientos[tipo] = (tiposMovimientos[tipo] ?? 0) + 1;
        }
        tiposMovimientos.forEach((tipo, cantidad) {
        });
      }

      if (mounted) {
        setState(() {
          _timelineMovimientos = movimientos;
          _isLoading = false;
        });
        
        // Actualizar cache de saldos para todas las cuentas por cobrar en background
        Future.microtask(() async {
          for (final movimiento in movimientos) {
            if (movimiento.cpCo_Id != null) {
              await _actualizarSaldoCuentaEnCache(movimiento.cpCo_Id!);
            }
          }
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

  /// Busca movimientos de un cliente específico en los datos generales de cuentas por cobrar
  Future<List<dynamic>> _buscarMovimientosClienteEnResumenGeneral(int clienteId) async {
    try {
      // Intentar obtener datos del resumen general de clientes
      final resumenClientes = await CuentasPorCobrarOfflineService.obtenerResumenClientesLocal();
      final cuentasGenerales = await CuentasPorCobrarOfflineService.obtenerCuentasPorCobrarLocal();
      
      // Filtrar movimientos del cliente específico
      final movimientosCliente = <dynamic>[];
      
      // Buscar en resumen de clientes
      for (final item in resumenClientes) {
        try {
          final cuenta = CuentasXCobrar.fromJson(item);
          if (cuenta.clie_Id == clienteId) {
            movimientosCliente.add(item);
          }
        } catch (e) {
        }
      }
      
      // Buscar en cuentas generales
      for (final item in cuentasGenerales) {
        try {
          final cuenta = CuentasXCobrar.fromJson(item);
          if (cuenta.clie_Id == clienteId) {
            // Evitar duplicados
            bool yaExiste = movimientosCliente.any((existente) {
              try {
                final cuentaExistente = CuentasXCobrar.fromJson(existente);
                return cuentaExistente.cpCo_Id == cuenta.cpCo_Id;
              } catch (_) {
                return false;
              }
            });
            
            if (!yaExiste) {
              movimientosCliente.add(item);
            }
          }
        } catch (e) {
        }
      }
      
      return movimientosCliente;
      
    } catch (e) {
      return [];
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
        title: 'Historial del Cliente',
        icon: Icons.timeline,
        onRefresh: () async {
          // Sincronizar datos específicos del cliente antes de recargar
          if (widget.cuentaResumen.clie_Id != null) {
            await CuentasPorCobrarOfflineService.precargarDatosCliente(widget.cuentaResumen.clie_Id!);
          }
          await _loadTimelineCliente();
        },
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
        // Botón de regreso
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              // Botón de regreso
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios,
                  size: 24,
                  color: Color(0xFF141A2F),
                ),
              ),
              const SizedBox(width: 16),
              // Título de la sección
              const Expanded(
                child: Text(
                  'Historial del Cliente',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF141A2F),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          const SizedBox(height: 16),
          // Agregar botón para intentar recargar
          ElevatedButton.icon(
            onPressed: () async {
              // Intentar sincronizar datos específicos del cliente
              if (widget.cuentaResumen.clie_Id != null) {
                try {
                  await CuentasPorCobrarOfflineService.precargarDatosCliente(widget.cuentaResumen.clie_Id!);
                  await _loadTimelineCliente();
                } catch (e) {
                }
              }
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Intentar recargar', style: TextStyle(color: Colors.white, fontFamily: 'Satoshi')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
              Expanded(child: _buildSummaryItem('Total Pendiente', _formatCurrency(_saldoPendienteActual), Icons.account_balance_wallet_rounded)),
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
    final isFactura = movimiento.tipo?.toUpperCase() == 'FACTURA' || movimiento.referencia?.contains('F') == true;
    
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
                Text(_getMovimientoTipo(movimiento), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Satoshi')),
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
              child: Text('${movimiento.referencia}', 
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, fontFamily: 'Satoshi')
              ),
            ),
        ],
      ),
    );
  }

  String _getMovimientoTipo(CuentasXCobrar movimiento) {
    if (movimiento.tipo?.isNotEmpty == true) {
      return movimiento.tipo!.toUpperCase();
    }
    
    // Si no tiene tipo pero tiene referencia que parece factura
    if (movimiento.referencia?.contains('F') == true) {
      return 'FACTURA';
    }
    
    return 'MOVIMIENTO';
  }

  Widget _buildMovimientoContent(CuentasXCobrar movimiento, Color primaryColor) {
    // Obtener el saldo actualizado para mostrar información correcta
    final saldoActualizado = _getSaldoActualizadoMovimiento(movimiento);
    
    // DEBUG: Logging detallado para diagnóstico
    if (movimiento.cpCo_Id != null && _saldosActualizadosCache.containsKey(movimiento.cpCo_Id!)) {
    }
    
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
              if (saldoActualizado > 0)
                Expanded(
                  child: _buildInfoBox('Pendiente', _formatCurrency(saldoActualizado), Icons.pending_actions_rounded, Colors.orange.shade600),
                )
              else if (_shouldShowPagadoStatus(movimiento, saldoActualizado))
                // Mostrar PAGADO solo cuando estemos seguros de que realmente está pagado
                Expanded(
                  child: _buildInfoBox('Estado', 'PAGADO', Icons.check_circle_rounded, Colors.green.shade600),
                ),
            ],
          ),
          if (movimiento.formaPago?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Forma de Pago:', movimiento.formaPago ?? 'N/A', Icons.payment_rounded, Colors.blue.shade600),
          ],
          if (movimiento.referencia?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Referencia:', movimiento.referencia ?? 'N/A', Icons.confirmation_number_rounded, Colors.grey.shade700),
          ],
          // NUEVO: Agregar botones de acción (siempre mostrar si tiene cpCo_Id)
          if (movimiento.cpCo_Id != null) ...[
            const SizedBox(height: 16),
            _buildPaymentButton(movimiento),
          ],
        ],
      ),
    );
  }

  // Determinar si debe mostrar el botón de pago
  bool _shouldShowPaymentButton(CuentasXCobrar movimiento) {
    // Mostrar si:
    // - Tiene saldo pendiente actualizado > 0
    // - No está anulado ni saldado
    // - Tiene cpCo_Id (es una cuenta por cobrar)
    
    // Intentar obtener el saldo actualizado dinámicamente
    final saldoActualizado = _getSaldoActualizadoMovimiento(movimiento);
    final tienePendiente = saldoActualizado > 0;
    final noEstaAnulado = movimiento.cpCo_Anulado != true;
    final noEstaSaldado = movimiento.cpCo_Saldada != true;
    final tieneCuentaId = movimiento.cpCo_Id != null;
    
    
    return tienePendiente && noEstaAnulado && noEstaSaldado && tieneCuentaId;
  }

  /// Determina si debe mostrar el estado "PAGADO" de forma más conservadora
  bool _shouldShowPagadoStatus(CuentasXCobrar movimiento, double saldoActualizado) {
    // LÓGICA SIMPLIFICADA: Solo mostrar PAGADO si:
    // 1. El saldo es realmente 0 o menor
    // 2. La cuenta está marcada como saldada en los datos del servidor
    
    final saldoEsCero = saldoActualizado <= 0;
    final estaMarcadaComoSaldada = movimiento.cpCo_Saldada == true;
    
    // Mostrar PAGADO solo si el saldo es 0 Y está marcada como saldada
    return saldoEsCero && estaMarcadaComoSaldada;
  }

  /// Obtiene el saldo actualizado de un movimiento específico
  double _getSaldoActualizadoMovimiento(CuentasXCobrar movimiento) {
    // SOLUCIÓN SIMPLIFICADA: Usar directamente los datos del movimiento
    // Esto elimina el problema del cache que mostraba 0.0 incorrectamente
    final totalPendiente = movimiento.totalPendiente;
    final cpCoSaldo = movimiento.cpCo_Saldo;
    final resultado = totalPendiente ?? cpCoSaldo ?? 0;
    
    print('🔍 _getSaldoActualizadoMovimiento para cuenta ${movimiento.cpCo_Id}: totalPendiente=$totalPendiente, cpCo_Saldo=$cpCoSaldo, resultado=$resultado');
    
    return resultado;
  }

  /// Actualiza el cache de saldos para una cuenta específica
  /// NOTA: Método simplificado - ya no es crítico con la nueva lógica
  Future<void> _actualizarSaldoCuentaEnCache(int cpCoId) async {
    // Método mantenido para compatibilidad pero simplificado
    // La nueva lógica usa directamente los datos del timeline
    print('ℹ️ Cache update para cuenta $cpCoId - usando datos directos del timeline');
  }

  Widget _buildPaymentButton(CuentasXCobrar movimiento) {
    final bool shouldShowPaymentButton = _shouldShowPaymentButton(movimiento);
    
    return Row(
      children: [
        // Botón Ver Detalle (siempre visible si tiene cpCo_Id)
        if (movimiento.cpCo_Id != null) ...[
          Expanded(
            flex: shouldShowPaymentButton ? 1 : 2,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToDetailScreen(movimiento),
              icon: Icon(Icons.visibility_rounded, size: 16, color: Colors.blue.shade600),
              label: const Text(
                'Ver Detalle', 
                style: TextStyle(fontSize: 12, fontFamily: 'Satoshi', fontWeight: FontWeight.w600)
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade600,
                side: BorderSide(color: Colors.blue.shade600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          
          if (shouldShowPaymentButton) const SizedBox(width: 8),
        ],
        
        // Botón Registrar Pago (condicional)
        if (shouldShowPaymentButton)
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPaymentScreen(movimiento),
              icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Pagar', 
                style: TextStyle(fontSize: 12, fontFamily: 'Satoshi', color: Colors.white, fontWeight: FontWeight.w600)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToDetailScreen(CuentasXCobrar movimiento) async {
    if (movimiento.cpCo_Id == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsCxCScreen(
          cpCoId: movimiento.cpCo_Id!,
        ),
      ),
    );
    
    // Si se hizo algún cambio en el detalle, recargar el timeline
    if (result == true) {
      _loadTimelineCliente();
    }
  }

  void _navigateToPaymentScreen(CuentasXCobrar movimiento) async {
    print('🎯 Navegando a pago desde historial - Cuenta: ${movimiento.cpCo_Id}');
    print('💰 Datos originales del movimiento: totalPendiente=${movimiento.totalPendiente}, cpCo_Saldo=${movimiento.cpCo_Saldo}');
    
    // CORRECCIÓN DEFINITIVA: Buscar el movimiento actualizado en la lista actual
    // Esto garantiza que usamos los datos más recientes cargados en la pantalla
    CuentasXCobrar movimientoActualizado = movimiento;
    
    if (movimiento.cpCo_Id != null) {
      // Buscar el movimiento actualizado en la lista de movimientos actuales
      final movimientoEncontrado = _timelineMovimientos.firstWhere(
        (m) => m.cpCo_Id == movimiento.cpCo_Id,
        orElse: () => movimiento,
      );
      
      if (movimientoEncontrado != movimiento) {
        print('✅ Movimiento actualizado encontrado en lista actual');
        movimientoActualizado = movimientoEncontrado;
      } else {
        print('ℹ️ Usando movimiento original (no se encontró actualización)');
      }
    }
    
    print('💰 Datos del movimiento actualizado: totalPendiente=${movimientoActualizado.totalPendiente}, cpCo_Saldo=${movimientoActualizado.cpCo_Saldo}');
    
    // Usar el saldo del movimiento actualizado
    final saldoActualEnPantalla = _getSaldoActualizadoMovimiento(movimientoActualizado);
    print('💰 Saldo calculado en pantalla actual: $saldoActualEnPantalla');
    
    // Si el saldo en pantalla es válido (mayor a 0), usarlo directamente
    // Si no, intentar obtenerlo del servicio como fallback
    double saldoParaPago = saldoActualEnPantalla;
    
    if (saldoParaPago <= 0 && movimientoActualizado.cpCo_Id != null) {
      try {
        print('⚠️ Saldo en pantalla es 0, intentando obtener del servicio...');
        saldoParaPago = await CuentasPorCobrarOfflineService.obtenerSaldoRealCuentaActualizado(movimientoActualizado.cpCo_Id!);
        print('💰 Saldo obtenido del servicio como fallback: $saldoParaPago');
      } catch (e) {
        print('⚠️ Error obteniendo saldo del servicio: $e');
        // Como último recurso, usar el totalPendiente original si es mayor a 0
        if ((movimientoActualizado.totalPendiente ?? 0) > 0) {
          saldoParaPago = movimientoActualizado.totalPendiente!;
          print('💰 Usando totalPendiente original como último recurso: $saldoParaPago');
        }
      }
    }
    
    // Crear un objeto de resumen para el pago basado en el movimiento específico
    final cuentaParaPago = CuentasXCobrar(
      cpCo_Id: movimientoActualizado.cpCo_Id,
      clie_Id: widget.cuentaResumen.clie_Id,
      fact_Id: movimientoActualizado.fact_Id,
      referencia: movimientoActualizado.referencia,
      totalPendiente: saldoParaPago, // Usar el saldo calculado correctamente
      cliente: widget.cuentaResumen.nombreCompleto,
      clie_Nombres: widget.cuentaResumen.clie_Nombres,
      clie_Apellidos: widget.cuentaResumen.clie_Apellidos,
      clie_NombreNegocio: widget.cuentaResumen.clie_NombreNegocio,
      clie_Telefono: widget.cuentaResumen.clie_Telefono,
    );
    
    print('💰 Cuenta para pago final: totalPendiente=${cuentaParaPago.totalPendiente}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PagoCuentaPorCobrarScreen(
          cuentaResumen: cuentaParaPago,
        ),
      ),
    );
    
    // Si el pago fue exitoso, recargar el timeline y notificar a la pantalla anterior
    if (result != null && result['pagoRegistrado'] == true) {
      
      // OPTIMIZACIÓN: Actualizar inmediatamente el cache local del saldo
      if (movimiento.cpCo_Id != null && result['montoRegistrado'] != null) {
        final montoRegistrado = result['montoRegistrado'] as double;
        final saldoAnterior = _getSaldoActualizadoMovimiento(movimiento);
        final nuevoSaldo = (saldoAnterior - montoRegistrado).clamp(0.0, double.infinity);
        
        if (mounted) {
          setState(() {
            _saldosActualizadosCache[movimiento.cpCo_Id!] = nuevoSaldo;
          });
        }
        
      }
      
      // Mostrar indicador de actualización rápida
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // MEJORA: Forzar sincronización más agresiva de datos
      try {
        final clienteId = widget.cuentaResumen.clie_Id;
        if (clienteId != null) {
          // Intentar sincronizar datos específicos del cliente desde el servidor
          await CuentasPorCobrarOfflineService.precargarDatosCliente(clienteId);
          
          // También sincronizar historial de pagos de la cuenta específica si se tiene el ID
          if (movimiento.cpCo_Id != null) {
            await CuentasPorCobrarOfflineService.sincronizarHistorialPagos(movimiento.cpCo_Id!);
            
            // Actualizar el saldo específico de esta cuenta en el cache
            await _actualizarSaldoCuentaEnCache(movimiento.cpCo_Id!);
          }
        }
      } catch (e) {
      }
      
      // Ejecutar actualizaciones en paralelo para máxima velocidad
      await Future.wait([
        _loadTimelineCliente(),
        _actualizarInformacionCuenta(),
      ]);
      
      // Notificar a la pantalla anterior que hubo cambios (sin delay para inmediatez)
      if (mounted) {
        Navigator.of(context).pop({'pagoRegistrado': true, 'recargarDatos': true});
      }
    }
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

  /// Actualiza la información de la cuenta desde los datos offline actualizados de forma optimizada
  Future<void> _actualizarInformacionCuenta() async {
    try {
      
      // Usar el método optimizado para obtener saldo actualizado
      final saldoActualizado = await CuentasPorCobrarOfflineService.obtenerSaldoRealCuentaActualizado(widget.cuentaId);
      
      if (mounted) {
        setState(() {
          _saldoActualizado = saldoActualizado;
        });
      }
    } catch (e) {
    }
  }

  /// Obtiene el saldo pendiente actual (actualizado o original)
  double get _saldoPendienteActual {
    return _saldoActualizado ?? widget.cuentaResumen.totalPendiente ?? 0;
  }
}