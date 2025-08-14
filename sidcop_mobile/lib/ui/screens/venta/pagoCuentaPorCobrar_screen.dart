import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';
import 'package:sidcop_mobile/models/ventas/PagosCXCViewModel.dart';
import 'package:sidcop_mobile/models/FormasDePagoViewModel.dart';
import 'package:sidcop_mobile/services/PagosCxCService.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';

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

  List<FormaPago> _formasPago = [];

  @override
  void initState() {
    super.initState();
    // Pre-llenar el monto con el total pendiente
    _montoController.text = (widget.cuentaResumen.totalPendiente ?? 0).toStringAsFixed(2);
    // Cargar formas de pago
    _loadFormasPago();
  }

  Future<void> _loadFormasPago() async {
    try {
      setState(() {
        _isLoadingFormasPago = true;
      });

      final formas = await _pagoService.getFormasPago();
      
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

  Future<void> _registrarPago() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que el monto no sea mayor al pendiente
    final double montoIngresado = double.tryParse(_montoController.text) ?? 0;
    final double totalPendiente = widget.cuentaResumen.totalPendiente ?? 0;

    if (montoIngresado > totalPendiente) {
      _showErrorDialog('El monto ingresado no puede ser mayor al total pendiente (${_formatCurrency(totalPendiente)})');
      return;
    }

    if (montoIngresado <= 0) {
      _showErrorDialog('El monto debe ser mayor a cero');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear el objeto de pago
      final pago = PagosCuentasXCobrar.nuevoPago(
        cpCoId: widget.cuentaResumen.cpCo_Id ?? 0,
        pagoMonto: montoIngresado,
        pagoFormaPago: _formaPagoSeleccionada?.foPaDescripcion ?? '',
        pagoNumeroReferencia: _numeroReferenciaController.text.trim(),
        pagoObservaciones: _observacionesController.text.trim().isEmpty 
            ? 'Pago registrado desde la aplicación móvil' 
            : _observacionesController.text.trim(),
        usuaCreacion: 1, // TODO: Obtener del usuario logueado
        foPaId: _formaPagoSeleccionada?.foPaId ?? 0,
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

      // Enviar al servicio
      final resultado = await _pagoService.insertarPago(pago);

      if (resultado['success']) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(resultado['message'] ?? 'Error desconocido al registrar el pago');
      }
    } catch (e) {
      _showErrorDialog('Error de conexión: ${e.toString()}');
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
              Navigator.of(context).pop(true); // Regresar a la pantalla anterior con resultado
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
          _buildInfoRow('Total Pendiente:', _formatCurrency(widget.cuentaResumen.totalPendiente ?? 0)),
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
          
          // Número de Referencia
          _buildFormField(
            label: 'Número de Referencia',
            child: TextFormField(
              controller: _numeroReferenciaController,
              decoration: _getInputDecoration('Ej: 123456789'),
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