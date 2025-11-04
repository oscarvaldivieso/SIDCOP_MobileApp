import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/models/FormasDePagoViewModel.dart';
import 'package:sidcop_mobile/services/PagosCxCService.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PagoCuentaPorCobrarScreen extends StatefulWidget {
  final CuentasXCobrar cuentaResumen;

  const PagoCuentaPorCobrarScreen({
    super.key,
    required this.cuentaResumen,
  });

  @override
  State<PagoCuentaPorCobrarScreen> createState() => _PagoCuentaPorCobrarScreenState();
}

class _PagoCuentaPorCobrarScreenState extends State<PagoCuentaPorCobrarScreen> {
  final _formKey = GlobalKey<FormState>();
  final PagoCuentasXCobrarService _pagoService = PagoCuentasXCobrarService();

  // Controllers
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _numeroReferenciaController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  // Variables del formulario
  FormaPago? _formaPagoSeleccionada;
  DateTime _fechaPago = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingFormasPago = true;
  double? _saldoRealActualizado; // Saldo real actualizado para mostrar en UI

  List<FormaPago> _formasPago = [];

  @override
  void initState() {
    super.initState();
    // CORRECCIÓN: Pre-llenar el monto con el saldo real actualizado
    _inicializarMontoConSaldoReal();
    // Inicializar referencia automáticamente con número de factura
    _inicializarReferenciaConNumeroFactura();
    // Cargar formas de pago
    _loadFormasPago();
    // Nota: La sincronización se maneja automáticamente por el timer periódico del servicio
  }

  /// Inicializa el campo de monto con el saldo real actualizado
  Future<void> _inicializarMontoConSaldoReal() async {
    try {
      print('🎯 Inicializando monto en pantalla de pagos');
      print('💰 Datos recibidos: totalPendiente=${widget.cuentaResumen.totalPendiente}, cpCo_Saldo=${widget.cuentaResumen.cpCo_Saldo}');
      
      // CORRECCIÓN: Usar directamente el totalPendiente que ya viene calculado correctamente
      // desde la pantalla anterior, evitando problemas de cache
      double saldoParaInicializar = widget.cuentaResumen.totalPendiente ?? widget.cuentaResumen.cpCo_Saldo ?? 0;
      
      // Solo intentar obtener del servicio si el valor recibido es 0 o null
      if (saldoParaInicializar <= 0) {
        final cpCoId = widget.cuentaResumen.cpCo_Id;
        if (cpCoId != null) {
          try {
            print('⚠️ Saldo recibido es 0, intentando obtener del servicio...');
            final saldoDelServicio = await CuentasPorCobrarOfflineService.obtenerSaldoRealCuentaActualizado(cpCoId);
            if (saldoDelServicio > 0) {
              saldoParaInicializar = saldoDelServicio;
              print('✅ Saldo obtenido del servicio: $saldoDelServicio');
            }
          } catch (e) {
            print('⚠️ Error obteniendo saldo del servicio: $e');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _saldoRealActualizado = saldoParaInicializar;
        });
        _montoController.text = saldoParaInicializar.toStringAsFixed(2);
        print('💰 Monto inicializado con saldo: ${_formatCurrency(saldoParaInicializar)}');
      }
    } catch (e) {
      print('❌ Error inicializando monto: $e');
      // Fallback al valor original en caso de error
      final fallbackValue = widget.cuentaResumen.totalPendiente ?? widget.cuentaResumen.cpCo_Saldo ?? 0;
      _montoController.text = fallbackValue.toStringAsFixed(2);
      print('💰 Usando valor fallback: ${_formatCurrency(fallbackValue)}');
    }
  }

  /// Inicializa automáticamente el campo de referencia con el número de factura
  void _inicializarReferenciaConNumeroFactura() {
    try {
      String referenciaAutomatica = '';
      
      // Prioridad de campos para la referencia:
      // 1. referencia (si está disponible)
      // 2. secuencia (si está disponible)  
      // 3. 'FACT-${fact_Id}' (si está disponible)
      // 4. 'REF-${cpCo_Id}' (fallback)
      
      if (widget.cuentaResumen.referencia != null && widget.cuentaResumen.referencia!.isNotEmpty) {
        referenciaAutomatica = widget.cuentaResumen.referencia!;
        print('📋 Referencia tomada del campo referencia: $referenciaAutomatica');
      } else if (widget.cuentaResumen.secuencia != null && widget.cuentaResumen.secuencia!.isNotEmpty) {
        referenciaAutomatica = widget.cuentaResumen.secuencia!;
        print('📋 Referencia tomada del campo secuencia: $referenciaAutomatica');
      } else if (widget.cuentaResumen.fact_Id != null) {
        referenciaAutomatica = 'FACT-${widget.cuentaResumen.fact_Id}';
        print('📋 Referencia generada con fact_Id: $referenciaAutomatica');
      } else {
        referenciaAutomatica = 'REF-${widget.cuentaResumen.cpCo_Id ?? 0}';
        print('📋 Referencia fallback con cpCo_Id: $referenciaAutomatica');
      }
      
      _numeroReferenciaController.text = referenciaAutomatica;
      print('✅ Campo de referencia inicializado automáticamente: $referenciaAutomatica');
      
    } catch (e) {
      print('❌ Error inicializando referencia automática: $e');
      // En caso de error, usar un fallback básico
      _numeroReferenciaController.text = 'REF-${widget.cuentaResumen.cpCo_Id ?? 0}';
    }
  }

  Future<void> _loadFormasPago() async {
    try {
      setState(() {
        _isLoadingFormasPago = true;
      });

      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      List<FormaPago> formas;

      if (isConnected) {
        try {
          // Intentar cargar desde el servidor y sincronizar
          formas = await _pagoService.getFormasPago();
          
          // Guardar en cache offline para uso posterior
          await CuentasPorCobrarOfflineService.sincronizarFormasPago();
          
          print('✅ Formas de pago sincronizadas desde servidor');
        } catch (e) {
          print('⚠️ Error cargando formas de pago desde servidor, intentando datos offline: $e');
          // Si falla el servidor, usar datos offline
          formas = await CuentasPorCobrarOfflineService.obtenerFormasPagoLocal();
        }
      } else {
        // Sin conexión, cargar datos offline
        print('📱 Sin conexión, cargando formas de pago offline');
        formas = await CuentasPorCobrarOfflineService.obtenerFormasPagoLocal();
      }
      
      if (mounted) {
        setState(() {
          _formasPago = formas;
          _isLoadingFormasPago = false;
          // Seleccionar la primera forma de pago por defecto si hay opciones disponibles
          if (_formasPago.isNotEmpty) {
            _formaPagoSeleccionada = _formasPago.first;
          }
        });
      }
    } catch (e) {
      print('❌ Error general en _loadFormasPago: $e');
      if (mounted) {
        setState(() {
          _isLoadingFormasPago = false;
        });
        _showErrorDialog('Error al cargar formas de pago: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    _numeroReferenciaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'L ', decimalDigits: 2).format(amount);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _fechaPago) {
      setState(() {
        _fechaPago = picked;
      });
    }
  }

  // Método optimizado para registro rápido de pagos con actualización inmediata del saldo

Future<void> _registrarPago() async {
  if (!_formKey.currentState!.validate()) return;

  // PREVENIR MÚLTIPLES ENVÍOS
  if (_isLoading) {
    print('⚠️ Ya hay un pago en proceso, ignorando solicitud adicional');
    return;
  }

  // Validar que el monto no sea mayor al pendiente
  final double montoIngresado = double.tryParse(_montoController.text) ?? 0;
  
  if (montoIngresado <= 0) {
    _showErrorDialog('El monto debe ser mayor a cero');
    return;
  }

  // VALIDACIONES ADICIONALES ANTES DE CREAR EL OBJETO
  final int cpCoId = widget.cuentaResumen.cpCo_Id ?? 0;
  final int foPaId = _formaPagoSeleccionada?.foPaId ?? 0;

  if (cpCoId <= 0) {
    _showErrorDialog('Error: ID de cuenta por cobrar no válido');
    return;
  }

  if (foPaId <= 0) {
    _showErrorDialog('Error: Forma de pago no válida');
    return;
  }

  final String numeroReferencia = _numeroReferenciaController.text.trim();
  if (numeroReferencia.isEmpty) {
    _showErrorDialog('El número de referencia es requerido');
    return;
  }

  // Obtener el saldo real actualizado desde los datos offline (incluyendo pagos ya aplicados)
  final double saldoReal = await CuentasPorCobrarOfflineService.obtenerSaldoRealCuentaActualizado(cpCoId);
  
  if (montoIngresado > saldoReal) {
    _showErrorDialog('El monto ingresado no puede ser mayor al saldo pendiente (${_formatCurrency(saldoReal)})');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Crear observaciones - asegurar que no esté vacío
    String observaciones = _observacionesController.text.trim();
    if (observaciones.isEmpty) {
      observaciones = 'Pago registrado desde la aplicación móvil';
    }

    // Crear el objeto de pago con datos validados
    final pago = PagosCuentasXCobrar.nuevoPago(
      cpCoId: cpCoId,
      pagoMonto: montoIngresado,
      pagoFormaPago: _formaPagoSeleccionada!.foPaDescripcion,
      pagoNumeroReferencia: numeroReferencia,
      pagoObservaciones: observaciones,
      usuaCreacion: 1, // TODO: Obtener del usuario logueado
      foPaId: foPaId,
    );

    // Actualizar la fecha seleccionada
    pago.pagoFecha = _fechaPago;

    // Validar datos antes de enviar
    if (!_pagoService.validarDatosPago(pago)) {
      _showErrorDialog('Error en los datos del pago. Verifique que todos los campos estén correctos.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // ESTRATEGIA MEJORADA: Verificar conectividad y actuar en consecuencia
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;

    print('🚀 INICIANDO REGISTRO PAGO - CpCo_Id: ${pago.cpCoId}, Monto: ${pago.pagoMonto}, Ref: ${pago.pagoNumeroReferencia}');

    if (isConnected) {
      // CON INTERNET: Intentar envío directo al servidor
      try {
        print('🌐 Con internet - enviando pago directamente al servidor...');
        print('📤 Datos del pago a enviar: ${pago.toJson()}');
        
        final response = await _pagoService.insertarPago(pago);
        
        if (response['success'] == true) {
          print('✅ ÉXITO: Pago enviado al servidor - ID asignado: ${response['pagoId']}');
          // NO guardar offline si se envió exitosamente al servidor
          _showSuccessDialog();
        } else {
          print('⚠️ FALLO SERVIDOR: ${response['message']} - Guardando offline como fallback');
          // Si falla el servidor, guardar offline como fallback
          await CuentasPorCobrarOfflineService.guardarPagoConActualizacionInmediata(pago);
          _showSuccessDialog();
        }
      } catch (e) {
        print('❌ ERROR CONEXIÓN: $e - Guardando offline');
        // Si hay error de conexión, guardar offline
        await CuentasPorCobrarOfflineService.guardarPagoConActualizacionInmediata(pago);
        _showSuccessDialog();
      }
    } else {
      // SIN INTERNET: Guardar offline únicamente
      print('📱 SIN INTERNET - guardando pago offline...');
      await CuentasPorCobrarOfflineService.guardarPagoConActualizacionInmediata(pago);
      _showSuccessDialog();
    }
  } catch (e) {
    _showErrorDialog('Error registrando el pago: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Pago Registrado', style: TextStyle(fontFamily: 'Satoshi')),
          ],
        ),
        content: const Text(
          'El pago ha sido registrado exitosamente.',
          style: TextStyle(fontFamily: 'Satoshi'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar diálogo
              Navigator.of(context).pop({'pagoRegistrado': true, 'recargarDatos': true}); // Regresar con señal de recarga
            },
            child: const Text('Aceptar', style: TextStyle(color: Color(0xFF1E3A8A), fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(fontFamily: 'Satoshi')),
          ],
        ),
        content: Text(message, style: const TextStyle(fontFamily: 'Satoshi')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar', style: TextStyle(color: Color(0xFF1E3A8A), fontFamily: 'Satoshi')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        title: 'Registrar Pago',
        icon: Icons.payment,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingFormasPago) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A))),
            SizedBox(height: 16),
            Text('Cargando formas de pago...', style: TextStyle(fontSize: 16, fontFamily: 'Satoshi')),
          ],
        ),
      );
    }

    if (_formasPago.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text('No se pudieron cargar las formas de pago', 
              style: TextStyle(fontSize: 16, fontFamily: 'Satoshi')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFormasPago,
              child: const Text('Reintentar', style: TextStyle(fontFamily: 'Satoshi')),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
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
                    'Registrar Pago',
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientInfoCard(),
                  const SizedBox(height: 16),
                  _buildPaymentForm(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                child: const Icon(Icons.store, color: Color(0xFF1E3A8A), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Información del Cliente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                    fontFamily: 'Satoshi',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Cliente:', widget.cuentaResumen.nombreCompleto),
          if (widget.cuentaResumen.clie_NombreNegocio?.isNotEmpty == true)
            _buildInfoRow('Negocio:', widget.cuentaResumen.clie_NombreNegocio!),
          _buildInfoRow('Cuenta No.:', widget.cuentaResumen.secuencia ?? 'N/A'),
          _buildSaldoPendienteRow(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoPendienteRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Total Pendiente:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  _formatCurrency(_saldoRealActualizado ?? widget.cuentaResumen.totalPendiente ?? 0),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Satoshi',
                    color: _saldoRealActualizado != null ? const Color(0xFF1E3A8A) : Colors.grey.shade700,
                  ),
                ),
                if (_saldoRealActualizado == null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade600,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos del Pago',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              fontFamily: 'Satoshi',
            ),
          ),
          const SizedBox(height: 16),
          
          // Monto
          _buildFormField(
            label: 'Monto del Pago',
            child: TextFormField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _getInputDecoration('0.00'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El monto es requerido';
                }
                final double? monto = double.tryParse(value);
                if (monto == null || monto <= 0) {
                  return 'Ingrese un monto válido';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Fecha
          _buildFormField(
            label: 'Fecha del Pago',
            child: InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_fechaPago),
                      style: const TextStyle(fontSize: 16, fontFamily: 'Satoshi'),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Forma de Pago
          _buildFormField(
            label: 'Forma de Pago',
            child: DropdownButtonFormField<FormaPago>(
              value: _formaPagoSeleccionada,
              decoration: _getInputDecoration('Seleccionar forma de pago'),
              items: _formasPago.map((forma) {
                return DropdownMenuItem<FormaPago>(
                  value: forma,
                  child: Text(forma.foPaDescripcion, style: const TextStyle(fontFamily: 'Satoshi')),
                );
              }).toList(),
              onChanged: (FormaPago? newValue) {
                if (newValue != null) {
                  setState(() {
                    _formaPagoSeleccionada = newValue;
                  });
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Seleccione una forma de pago';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Número de Referencia (Automático)
          _buildFormField(
            label: 'Número de Referencia',
            child: TextFormField(
              controller: _numeroReferenciaController,
              readOnly: true,
              decoration: _getInputDecoration('Generado automáticamente').copyWith(
                fillColor: Colors.grey.shade100,
                filled: true,
                prefixIcon: const Icon(Icons.lock, color: Colors.grey, size: 20),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El número de referencia es requerido';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Observaciones
          _buildFormField(
            label: 'Observaciones (Opcional)',
            child: TextFormField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: _getInputDecoration('Observaciones adicionales...'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            fontFamily: 'Satoshi',
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _getInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontFamily: 'Satoshi'),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
      ),
      contentPadding: const EdgeInsets.all(12),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registrarPago,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Registrar Pago',
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
}