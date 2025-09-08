import 'package:flutter/material.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/ui/screens/venta/pagoCuentaPorCobrar_screen.dart';
import 'package:sidcop_mobile/ui/screens/venta/detailsCxC_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      List<dynamic> response;
      
      if (isConnected) {
        try {
          // Intentar cargar desde el servidor y sincronizar
          response = await _cuentasService.getTimelineCliente(clienteId);
          
          // Guardar en cache offline para uso posterior
          await CuentasPorCobrarOfflineService.sincronizarTimelineCliente(clienteId);
          
          print('✅ Timeline cliente $clienteId sincronizado desde servidor (${response.length} elementos)');
        } catch (e) {
          print('⚠️ Error cargando timeline desde servidor, intentando datos offline: $e');
          // Si falla el servidor, usar datos offline
          response = await CuentasPorCobrarOfflineService.obtenerTimelineClienteLocal(clienteId);
          
          // Si no hay datos offline, intentar cargar datos generales del cliente
          if (response.isEmpty) {
            print('📄 No hay timeline offline, buscando en resumen general...');
            response = await _buscarMovimientosClienteEnResumenGeneral(clienteId);
          }
        }
      } else {
        // Sin conexión, cargar datos offline
        print('📱 Sin conexión, cargando timeline offline para cliente $clienteId');
        response = await CuentasPorCobrarOfflineService.obtenerTimelineClienteLocal(clienteId);
        
        // Si no hay timeline específico offline, buscar en datos generales
        if (response.isEmpty) {
          print('📄 No hay timeline offline, buscando en datos generales offline...');
          response = await _buscarMovimientosClienteEnResumenGeneral(clienteId);
        }
      }
      final List<CuentasXCobrar> movimientos = response
          .map((item) {
            try {
              return CuentasXCobrar.fromJson(item);
            } catch (e) {
              print('❌ Error parseando movimiento: $e');
              print('   Datos del item: $item');
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

      print('📊 Timeline cliente $clienteId: ${movimientos.length} movimientos procesados exitosamente');
      
      // Log adicional para debug
      if (movimientos.isNotEmpty) {
        print('   📋 Tipos de movimientos encontrados:');
        final tiposMovimientos = <String, int>{};
        for (final mov in movimientos) {
          final tipo = mov.tipo ?? (mov.referencia?.contains('F') == true ? 'FACTURA' : 'OTRO');
          tiposMovimientos[tipo] = (tiposMovimientos[tipo] ?? 0) + 1;
        }
        tiposMovimientos.forEach((tipo, cantidad) {
          print('      - $tipo: $cantidad');
        });
      }

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
          print('Error parseando item del resumen: $e');
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
          print('Error parseando item de cuentas generales: $e');
        }
      }
      
      print('🔍 Encontrados ${movimientosCliente.length} movimientos para cliente $clienteId en datos generales');
      return movimientosCliente;
      
    } catch (e) {
      print('Error buscando movimientos en datos generales: $e');
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
        title: 'Timeline Cliente',
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
                  print('Error en recarga manual: $e');
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
              if (movimiento.totalPendiente != null && movimiento.totalPendiente! > 0)
                Expanded(
                  child: _buildInfoBox('Pendiente', _formatCurrency(movimiento.totalPendiente), Icons.pending_actions_rounded, Colors.orange.shade600),
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
    // - Tiene totalPendiente > 0
    // - No está anulado ni saldado
    // - Tiene cpCo_Id (es una cuenta por cobrar)
    final tienePendiente = (movimiento.totalPendiente ?? 0) > 0;
    final noEstaAnulado = movimiento.cpCo_Anulado != true;
    final noEstaSaldado = movimiento.cpCo_Saldada != true;
    final tieneCuentaId = movimiento.cpCo_Id != null;
    
    return tienePendiente && noEstaAnulado && noEstaSaldado && tieneCuentaId;
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
    // Crear un objeto de resumen para el pago basado en el movimiento específico
    final cuentaParaPago = CuentasXCobrar(
      cpCo_Id: movimiento.cpCo_Id,
      clie_Id: widget.cuentaResumen.clie_Id,
      fact_Id: movimiento.fact_Id,
      referencia: movimiento.referencia,
      totalPendiente: movimiento.totalPendiente,
      cliente: widget.cuentaResumen.nombreCompleto,
      clie_Nombres: widget.cuentaResumen.clie_Nombres,
      clie_Apellidos: widget.cuentaResumen.clie_Apellidos,
      clie_NombreNegocio: widget.cuentaResumen.clie_NombreNegocio,
      clie_Telefono: widget.cuentaResumen.clie_Telefono,
    );

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
      print('✅ Pago registrado, recargando datos...');
      
      // Recargar inmediatamente el timeline y actualizar la cuenta
      await _loadTimelineCliente();
      
      // Actualizar también la información de la cuenta desde los datos offline actualizados
      await _actualizarInformacionCuenta();
      
      // Notificar a la pantalla anterior que hubo cambios (sin delay para inmediatez)
      if (mounted) {
        Navigator.of(context).pop({'pagoRegistrado': true});
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

  /// Actualiza la información de la cuenta desde los datos offline actualizados
  Future<void> _actualizarInformacionCuenta() async {
    try {
      // Buscar la cuenta actualizada en el resumen de clientes offline
      final resumenClientes = await CuentasPorCobrarOfflineService.obtenerResumenClientesLocal();
      
      for (final item in resumenClientes) {
        if (item['cpCo_Id'] == widget.cuentaResumen.cpCo_Id) {
          // Crear una nueva instancia de la cuenta con los datos actualizados
          final cuentaActualizada = CuentasXCobrar.fromJson(item);
          
          // Como no puedo modificar el widget.cuentaResumen directamente, 
          // simplemente forzar un rebuild del UI que mostrará los nuevos datos
          setState(() {
            // Solo hacer un setState para refrescar la UI
          });
          
          print('✅ Información de cuenta actualizada: Nuevo saldo ${cuentaActualizada.totalPendiente}');
          break;
        }
      }
    } catch (e) {
      print('Error actualizando información de cuenta: $e');
    }
  }
}