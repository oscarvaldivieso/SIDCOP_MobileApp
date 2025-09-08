import 'package:flutter/material.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:intl/intl.dart';

/// Widget que muestra el saldo actualizado en tiempo real
/// Se actualiza automáticamente cuando se detectan cambios en los pagos
class SaldoActualizadoWidget extends StatefulWidget {
  final int cpCoId;
  final double? saldoInicial;
  final TextStyle? textStyle;
  final Color? color;
  final bool mostrarIcono;
  final VoidCallback? onSaldoActualizado;

  const SaldoActualizadoWidget({
    Key? key,
    required this.cpCoId,
    this.saldoInicial,
    this.textStyle,
    this.color,
    this.mostrarIcono = true,
    this.onSaldoActualizado,
  }) : super(key: key);

  @override
  State<SaldoActualizadoWidget> createState() => _SaldoActualizadoWidgetState();
}

class _SaldoActualizadoWidgetState extends State<SaldoActualizadoWidget> with WidgetsBindingObserver {
  double? _saldoActual;
  bool _isLoading = false;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saldoActual = widget.saldoInicial;
    _actualizarSaldo();
    
    // Configurar actualización periódica
    _configurarActualizacionPeriodica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Actualizar cuando la app vuelve al primer plano
      _actualizarSaldo();
    }
  }

  void _configurarActualizacionPeriodica() {
    // Actualizar cada 30 segundos si hay cambios pendientes
    Stream.periodic(const Duration(seconds: 30)).listen((_) {
      if (mounted) {
        _verificarYActualizarSiEsNecesario();
      }
    });
  }

  Future<void> _verificarYActualizarSiEsNecesario() async {
    try {
      // Solo actualizar si han pasado más de 10 segundos desde la última actualización
      if (_ultimaActualizacion != null && 
          DateTime.now().difference(_ultimaActualizacion!).inSeconds < 10) {
        return;
      }

      // Verificar si hay pagos pendientes para esta cuenta
      final pagosPendientes = await CuentasPorCobrarOfflineService.obtenerPagosPendientesLocal();
      final tienePagosPendientes = pagosPendientes.any((item) {
        try {
          final pagoData = item['pago'] as Map<String, dynamic>;
          return pagoData['cpCoId'] == widget.cpCoId;
        } catch (e) {
          return false;
        }
      });

      if (tienePagosPendientes) {
        await _actualizarSaldo();
      }
    } catch (e) {
      print('Error verificando actualización de saldo: $e');
    }
  }

  Future<void> _actualizarSaldo() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final saldoActualizado = await CuentasPorCobrarOfflineService.obtenerSaldoRealCuentaActualizado(widget.cpCoId);
      
      if (mounted && saldoActualizado != _saldoActual) {
        setState(() {
          _saldoActual = saldoActualizado;
          _ultimaActualizacion = DateTime.now();
          _isLoading = false;
        });

        // Notificar al widget padre si hay callback
        if (widget.onSaldoActualizado != null) {
          widget.onSaldoActualizado!();
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error actualizando saldo: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount);
  }

  Color _getSaldoColor() {
    if (widget.color != null) return widget.color!;
    
    final saldo = _saldoActual ?? 0;
    if (saldo <= 0) {
      return Colors.green.shade600; // Pagado completamente
    } else if (saldo < (widget.saldoInicial ?? 0) * 0.5) {
      return Colors.orange.shade600; // Más del 50% pagado
    } else {
      return Colors.red.shade600; // Saldo alto pendiente
    }
  }

  IconData _getSaldoIcon() {
    final saldo = _saldoActual ?? 0;
    if (saldo <= 0) {
      return Icons.check_circle;
    } else if (saldo < (widget.saldoInicial ?? 0) * 0.5) {
      return Icons.schedule;
    } else {
      return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldoActual ?? widget.saldoInicial ?? 0;
    final color = _getSaldoColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.mostrarIcono) ...[
          Icon(
            _getSaldoIcon(),
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
        ],
        
        Text(
          _formatCurrency(saldo),
          style: widget.textStyle?.copyWith(color: color) ?? 
                 TextStyle(
                   color: color,
                   fontWeight: FontWeight.w600,
                   fontFamily: 'Satoshi',
                 ),
        ),
        
        if (_isLoading) ...[
          const SizedBox(width: 4),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              color: color,
              strokeWidth: 2,
            ),
          ),
        ],
      ],
    );
  }

  /// Método público para forzar actualización desde el widget padre
  Future<void> actualizarManualmente() async {
    await _actualizarSaldo();
  }
}

/// Widget simplificado para mostrar solo el saldo sin icono
class SaldoSimpleWidget extends StatelessWidget {
  final int cpCoId;
  final double? saldoInicial;
  final TextStyle? textStyle;

  const SaldoSimpleWidget({
    Key? key,
    required this.cpCoId,
    this.saldoInicial,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SaldoActualizadoWidget(
      cpCoId: cpCoId,
      saldoInicial: saldoInicial,
      textStyle: textStyle,
      mostrarIcono: false,
    );
  }
}
