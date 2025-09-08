// Archivo: lib/models/ventas/pagosCuentasXCobrar.dart - VERSIÓN CORREGIDA

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
  DateTime? pagoFechaModificacion;  // Puede ser null
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
    this.pagoFechaModificacion,  // Opcional
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

  // Constructor para crear desde JSON - MEJORADO para manejar ambos formatos (servidor y cache)
  factory PagosCuentasXCobrar.fromJson(Map<String, dynamic> json) {
    // Debug: Mostrar qué campos están disponibles
    print('🔧 fromJson recibido: ${json.keys.toList()}');
    
    return PagosCuentasXCobrar(
      pagoId: json['pago_Id'] ?? 0,
      cpCoId: json['cpCo_Id'] ?? json['CPCo_Id'] ?? 0, // Formato server vs cache
      pagoFecha: json['pago_Fecha'] != null ? DateTime.parse(json['pago_Fecha']) : DateTime.now(),
      pagoMonto: (json['pago_Monto'] ?? json['Pago_Monto'] ?? 0.0).toDouble(), // Formato server vs cache - CORREGIDO
      pagoFormaPago: json['pago_FormaPago'] ?? json['foPa_Descripcion'] ?? json['FoPa_Descripcion'] ?? 'Efectivo', // Múltiples formatos, default "Efectivo" - CORREGIDO
      pagoNumeroReferencia: json['pago_NumeroReferencia'] ?? json['Pago_NumeroReferencia'] ?? '', // Formato server vs cache
      pagoObservaciones: json['pago_Observaciones'] ?? json['Pago_Observaciones'] ?? '', // Formato server vs cache
      usuaCreacion: json['usua_Creacion'] ?? json['Usua_Creacion'] ?? 1, // Formato server vs cache, default 1
      pagoFechaCreacion: json['pago_FechaCreacion'] != null ? DateTime.parse(json['pago_FechaCreacion']) : DateTime.now(),
      usuaModificacion: json['usua_Modificacion'] ?? 0,
      pagoFechaModificacion: json['pago_FechaModificacion'] != null ? DateTime.parse(json['pago_FechaModificacion']) : null,
      pagoEstado: json['pago_Estado'] ?? true, // Por defecto activo
      pagoAnulado: json['pago_Anulado'] ?? false,
      foPaId: json['foPa_Id'] ?? json['FoPa_Id'] ?? 1, // Formato server vs cache, default 1 para Efectivo
      usuarioCreacion: json['usuarioCreacion'] ?? '',
      usuarioModificacion: json['usuarioModificacion'] ?? '',
      clieId: json['clie_Id'] ?? 0,
      clieNombreCompleto: json['clie_NombreCompleto'] ?? '',
      clieRTN: json['clie_RTN'] ?? '',
      factId: json['fact_Id'] ?? 0,
      factNumero: json['fact_Numero'] ?? '',
    );
  }

  // VERSIÓN MEJORADA: JSON para envío al API que coincida EXACTAMENTE con el backend
 Map<String, dynamic> toJson() {
  final json = {
    'CPCo_Id': cpCoId,                        // ✅ Exacto como espera el backend
    'Pago_Monto': pagoMonto,                  // ✅ Exacto como espera el backend
    'FoPa_Id': foPaId,                        // ✅ Exacto como espera el backend
    'FoPa_Descripcion': pagoFormaPago,        // 🔧 AGREGADO: Campo requerido por la API
    'Pago_NumeroReferencia': pagoNumeroReferencia, // ✅ Exacto como espera el backend
    'Pago_Observaciones': pagoObservaciones,       // ✅ Exacto como espera el backend
    'Usua_Creacion': usuaCreacion,            // ✅ Exacto como espera el backend
  };
  
  return json;
}

  // JSON completo para recibir del API (cuando se consulta)
  Map<String, dynamic> toFullJson() {
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
      'pago_FechaModificacion': pagoFechaModificacion?.toIso8601String(),
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

  // Constructor para crear un nuevo pago (para insertar) - MEJORADO
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
    
    // Validación básica antes de crear el objeto
    if (cpCoId <= 0) throw ArgumentError('cpCoId debe ser mayor a 0');
    if (pagoMonto <= 0) throw ArgumentError('pagoMonto debe ser mayor a 0');
    if (foPaId <= 0) throw ArgumentError('foPaId debe ser mayor a 0');
    if (pagoNumeroReferencia.trim().isEmpty) throw ArgumentError('pagoNumeroReferencia no puede estar vacío');
    if (pagoObservaciones.trim().isEmpty) throw ArgumentError('pagoObservaciones no puede estar vacío');
    if (usuaCreacion <= 0) throw ArgumentError('usuaCreacion debe ser mayor a 0');
    
    final pago = PagosCuentasXCobrar(
      pagoId: 0,
      cpCoId: cpCoId,
      pagoFecha: now,
      pagoMonto: pagoMonto,
      pagoFormaPago: pagoFormaPago,
      pagoNumeroReferencia: pagoNumeroReferencia.trim(),
      pagoObservaciones: pagoObservaciones.trim(),
      usuaCreacion: usuaCreacion,
      pagoFechaCreacion: now,
      usuaModificacion: 0,
      pagoFechaModificacion: null, // Puede ser null al crear
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
    return pago;
  }
}