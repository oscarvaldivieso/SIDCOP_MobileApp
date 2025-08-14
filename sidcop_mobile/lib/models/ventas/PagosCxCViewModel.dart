// Archivo: lib/models/ventas/pagosCuentasXCobrar.dart

class PagosCuentasXCobrar {
  int pagoId;
  int cpCoId;
  DateTime pagoFecha;
  double pagoMonto;
  String pagoFormaPago;
  String pagoNumeroReferencia;
  String pagoObservaciones;
  int usuaCreacion;
  DateTime pagoFechaCreacion;
  int usuaModificacion;
  DateTime pagoFechaModificacion;
  bool pagoEstado;
  bool pagoAnulado;
  int foPaId;
  String usuarioCreacion;
  String usuarioModificacion;
  int clieId;
  String clieNombreCompleto;
  String clieRTN;
  int factId;
  String factNumero;

  PagosCuentasXCobrar({
    required this.pagoId,
    required this.cpCoId,
    required this.pagoFecha,
    required this.pagoMonto,
    required this.pagoFormaPago,
    required this.pagoNumeroReferencia,
    required this.pagoObservaciones,
    required this.usuaCreacion,
    required this.pagoFechaCreacion,
    required this.usuaModificacion,
    required this.pagoFechaModificacion,
    required this.pagoEstado,
    required this.pagoAnulado,
    required this.foPaId,
    required this.usuarioCreacion,
    required this.usuarioModificacion,
    required this.clieId,
    required this.clieNombreCompleto,
    required this.clieRTN,
    required this.factId,
    required this.factNumero,
  });

  // Constructor para crear desde JSON
  factory PagosCuentasXCobrar.fromJson(Map<String, dynamic> json) {
    return PagosCuentasXCobrar(
      pagoId: json['pago_Id'] ?? 0,
      cpCoId: json['cpCo_Id'] ?? 0,
      pagoFecha: DateTime.parse(json['pago_Fecha']),
      pagoMonto: (json['pago_Monto'] ?? 0.0).toDouble(),
      pagoFormaPago: json['pago_FormaPago'] ?? '',
      pagoNumeroReferencia: json['pago_NumeroReferencia'] ?? '',
      pagoObservaciones: json['pago_Observaciones'] ?? '',
      usuaCreacion: json['usua_Creacion'] ?? 0,
      pagoFechaCreacion: DateTime.parse(json['pago_FechaCreacion']),
      usuaModificacion: json['usua_Modificacion'] ?? 0,
      pagoFechaModificacion: DateTime.parse(json['pago_FechaModificacion']),
      pagoEstado: json['pago_Estado'] ?? false,
      pagoAnulado: json['pago_Anulado'] ?? false,
      foPaId: json['foPa_Id'] ?? 0,
      usuarioCreacion: json['usuarioCreacion'] ?? '',
      usuarioModificacion: json['usuarioModificacion'] ?? '',
      clieId: json['clie_Id'] ?? 0,
      clieNombreCompleto: json['clie_NombreCompleto'] ?? '',
      clieRTN: json['clie_RTN'] ?? '',
      factId: json['fact_Id'] ?? 0,
      factNumero: json['fact_Numero'] ?? '',
    );
  }

  // Convertir a JSON para envío al API
  Map<String, dynamic> toJson() {
    return {
      'pago_Id': pagoId,
      'cpCo_Id': cpCoId,
      'pago_Fecha': pagoFecha.toIso8601String(),
      'pago_Monto': pagoMonto,
      'pago_FormaPago': pagoFormaPago,
      'pago_NumeroReferencia': pagoNumeroReferencia,
      'pago_Observaciones': pagoObservaciones,
      'usua_Creacion': usuaCreacion,
      'pago_FechaCreacion': pagoFechaCreacion.toIso8601String(),
      'usua_Modificacion': usuaModificacion,
      'pago_FechaModificacion': pagoFechaModificacion.toIso8601String(),
      'pago_Estado': pagoEstado,
      'pago_Anulado': pagoAnulado,
      'foPa_Id': foPaId,
      'usuarioCreacion': usuarioCreacion,
      'usuarioModificacion': usuarioModificacion,
      'clie_Id': clieId,
      'clie_NombreCompleto': clieNombreCompleto,
      'clie_RTN': clieRTN,
      'fact_Id': factId,
      'fact_Numero': factNumero,
    };
  }

  // Constructor para crear un nuevo pago (para insertar)
  factory PagosCuentasXCobrar.nuevoPago({
    required int cpCoId,
    required double pagoMonto,
    required String pagoFormaPago,
    required String pagoNumeroReferencia,
    required String pagoObservaciones,
    required int usuaCreacion,
    required int foPaId,
  }) {
    final now = DateTime.now();
    return PagosCuentasXCobrar(
      pagoId: 0,
      cpCoId: cpCoId,
      pagoFecha: now,
      pagoMonto: pagoMonto,
      pagoFormaPago: pagoFormaPago,
      pagoNumeroReferencia: pagoNumeroReferencia,
      pagoObservaciones: pagoObservaciones,
      usuaCreacion: usuaCreacion,
      pagoFechaCreacion: now,
      usuaModificacion: 0,
      pagoFechaModificacion: now,
      pagoEstado: true,
      pagoAnulado: false,
      foPaId: foPaId,
      usuarioCreacion: '',
      usuarioModificacion: '',
      clieId: 0,
      clieNombreCompleto: '',
      clieRTN: '',
      factId: 0,
      factNumero: '',
    );
  }
}