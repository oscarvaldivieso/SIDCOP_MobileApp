class CuentasXCobrar {
  final int? cpCo_Id;
  final int? clie_Id;
  final int? fact_Id;
  final DateTime? cpCo_FechaEmision;
  final DateTime? cpCo_FechaVencimiento;
  final double? cpCo_Valor;
  final double? cpCo_Saldo;
  final String? cpCo_Observaciones;
  final bool? cpCo_Anulado;
  final bool? cpCo_Saldada;
  final int? usua_Creacion;
  final DateTime? cpCo_FechaCreacion;
  final int? usua_Modificacion;
  final DateTime? cpCo_FechaModificacion;
  final bool? cpCo_Estado;
  final String? clie_Codigo;
  final String? clie_Nombres;
  final String? clie_Apellidos;
  final String? cliente; // Campo agregado
  final String? clie_NombreNegocio;
  final String? clie_Telefono;
  final String? formaPago; // Campo agregado
  final double? clie_LimiteCredito;
  final double? clie_Saldo;
  final String? tipo; // Campo agregado
  final String? referencia; // Campo agregado
  final double? monto; // Campo agregado
  final DateTime? fecha; // Campo agregado
  final double? actual; // Campo agregado
  final double? v1_30; // Campo agregado (cambié nombre por conflicto con números)
  final double? v31_60; // Campo agregado
  final double? v61_90; // Campo agregado
  final double? mayor90; // Campo agregado
  final int? facturasPendientes; // Campo agregado
  final double? totalFacturado; // Campo agregado
  final double? total; // Campo agregado
  final double? totalPendiente; // Campo agregado
  final double? totalVencido; // Campo agregado
  final DateTime? ultimoPago; // Campo agregado
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final String? secuencia; // Campo agregado
  final dynamic clie;
  final dynamic fact;
  final dynamic usua_CreacionNavigation;
  final dynamic usua_ModificacionNavigation;
  final List<dynamic>? tbPagosCuentasPorCobrar;

  CuentasXCobrar({
    this.cpCo_Id,
    this.clie_Id,
    this.fact_Id,
    this.cpCo_FechaEmision,
    this.cpCo_FechaVencimiento,
    this.cpCo_Valor,
    this.cpCo_Saldo,
    this.cpCo_Observaciones,
    this.cpCo_Anulado,
    this.cpCo_Saldada,
    this.usua_Creacion,
    this.cpCo_FechaCreacion,
    this.usua_Modificacion,
    this.cpCo_FechaModificacion,
    this.cpCo_Estado,
    this.clie_Codigo,
    this.clie_Nombres,
    this.clie_Apellidos,
    this.cliente,
    this.clie_NombreNegocio,
    this.clie_Telefono,
    this.formaPago,
    this.clie_LimiteCredito,
    this.clie_Saldo,
    this.tipo,
    this.referencia,
    this.monto,
    this.fecha,
    this.actual,
    this.v1_30,
    this.v31_60,
    this.v61_90,
    this.mayor90,
    this.facturasPendientes,
    this.totalFacturado,
    this.total,
    this.totalPendiente,
    this.totalVencido,
    this.ultimoPago,
    this.usuarioCreacion,
    this.usuarioModificacion,
    this.secuencia,
    this.clie,
    this.fact,
    this.usua_CreacionNavigation,
    this.usua_ModificacionNavigation,
    this.tbPagosCuentasPorCobrar,
  });

  Map<String, dynamic> toJson() {
    return {
      "cpCo_Id": cpCo_Id,
      "clie_Id": clie_Id,
      "fact_Id": fact_Id,
      "cpCo_FechaEmision": cpCo_FechaEmision?.toUtc().toIso8601String(),
      "cpCo_FechaVencimiento": cpCo_FechaVencimiento?.toUtc().toIso8601String(),
      "cpCo_Valor": cpCo_Valor,
      "cpCo_Saldo": cpCo_Saldo,
      "cpCo_Observaciones": cpCo_Observaciones,
      "cpCo_Anulado": cpCo_Anulado,
      "cpCo_Saldada": cpCo_Saldada,
      "usua_Creacion": usua_Creacion,
      "cpCo_FechaCreacion": cpCo_FechaCreacion?.toUtc().toIso8601String(),
      "usua_Modificacion": usua_Modificacion,
      "cpCo_FechaModificacion": cpCo_FechaModificacion?.toUtc().toIso8601String(),
      "cpCo_Estado": cpCo_Estado,
      "clie_Codigo": clie_Codigo,
      "clie_Nombres": clie_Nombres,
      "clie_Apellidos": clie_Apellidos,
      "cliente": cliente,
      "clie_NombreNegocio": clie_NombreNegocio,
      "clie_Telefono": clie_Telefono,
      "formaPago": formaPago,
      "clie_LimiteCredito": clie_LimiteCredito,
      "clie_Saldo": clie_Saldo,
      "tipo": tipo,
      "referencia": referencia,
      "monto": monto,
      "fecha": fecha?.toUtc().toIso8601String(),
      "actual": actual,
      "_1_30": v1_30,
      "_31_60": v31_60,
      "_61_90": v61_90,
      "mayor90": mayor90,
      "facturasPendientes": facturasPendientes,
      "totalFacturado": totalFacturado,
      "total": total,
      "totalPendiente": totalPendiente,
      "totalVencido": totalVencido,
      "ultimoPago": ultimoPago?.toUtc().toIso8601String(),
      "usuarioCreacion": usuarioCreacion,
      "usuarioModificacion": usuarioModificacion,
      "secuencia": secuencia,
      "clie": clie,
      "fact": fact,
      "usua_CreacionNavigation": usua_CreacionNavigation,
      "usua_ModificacionNavigation": usua_ModificacionNavigation,
      "tbPagosCuentasPorCobrar": tbPagosCuentasPorCobrar,
    };
  }

  factory CuentasXCobrar.fromJson(Map<String, dynamic> json) {
    return CuentasXCobrar(
      cpCo_Id: json['cpCo_Id'],
      clie_Id: json['clie_Id'],
      fact_Id: json['fact_Id'],
      cpCo_FechaEmision: json['cpCo_FechaEmision'] != null
          ? DateTime.tryParse(json['cpCo_FechaEmision'].toString())
          : null,
      cpCo_FechaVencimiento: json['cpCo_FechaVencimiento'] != null
          ? DateTime.tryParse(json['cpCo_FechaVencimiento'].toString())
          : null,
      cpCo_Valor: json['cpCo_Valor'] != null
          ? double.tryParse(json['cpCo_Valor'].toString())
          : null,
      cpCo_Saldo: json['cpCo_Saldo'] != null
          ? double.tryParse(json['cpCo_Saldo'].toString())
          : null,
      cpCo_Observaciones: json['cpCo_Observaciones'],
      cpCo_Anulado: json['cpCo_Anulado'],
      cpCo_Saldada: json['cpCo_Saldada'],
      usua_Creacion: json['usua_Creacion'],
      cpCo_FechaCreacion: json['cpCo_FechaCreacion'] != null
          ? DateTime.tryParse(json['cpCo_FechaCreacion'].toString())
          : null,
      usua_Modificacion: json['usua_Modificacion'],
      cpCo_FechaModificacion: json['cpCo_FechaModificacion'] != null
          ? DateTime.tryParse(json['cpCo_FechaModificacion'].toString())
          : null,
      cpCo_Estado: json['cpCo_Estado'],
      clie_Codigo: json['clie_Codigo'],
      clie_Nombres: json['clie_Nombres'],
      clie_Apellidos: json['clie_Apellidos'],
      cliente: json['cliente'],
      clie_NombreNegocio: json['clie_NombreNegocio'],
      clie_Telefono: json['clie_Telefono'],
      formaPago: json['formaPago'],
      clie_LimiteCredito: json['clie_LimiteCredito'] != null
          ? double.tryParse(json['clie_LimiteCredito'].toString())
          : null,
      clie_Saldo: json['clie_Saldo'] != null
          ? double.tryParse(json['clie_Saldo'].toString())
          : null,
      tipo: json['tipo'],
      referencia: json['referencia'],
      monto: json['monto'] != null
          ? double.tryParse(json['monto'].toString())
          : null,
      fecha: json['fecha'] != null
          ? DateTime.tryParse(json['fecha'].toString())
          : null,
      actual: json['actual'] != null
          ? double.tryParse(json['actual'].toString())
          : null,
      v1_30: json['_1_30'] != null
          ? double.tryParse(json['_1_30'].toString())
          : null,
      v31_60: json['_31_60'] != null
          ? double.tryParse(json['_31_60'].toString())
          : null,
      v61_90: json['_61_90'] != null
          ? double.tryParse(json['_61_90'].toString())
          : null,
      mayor90: json['mayor90'] != null
          ? double.tryParse(json['mayor90'].toString())
          : null,
      facturasPendientes: json['facturasPendientes'],
      totalFacturado: json['totalFacturado'] != null
          ? double.tryParse(json['totalFacturado'].toString())
          : null,
      total: json['total'] != null
          ? double.tryParse(json['total'].toString())
          : null,
      totalPendiente: json['totalPendiente'] != null
          ? double.tryParse(json['totalPendiente'].toString())
          : null,
      totalVencido: json['totalVencido'] != null
          ? double.tryParse(json['totalVencido'].toString())
          : null,
      ultimoPago: json['ultimoPago'] != null
          ? DateTime.tryParse(json['ultimoPago'].toString())
          : null,
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
      secuencia: json['secuencia'],
      clie: json['clie'],
      fact: json['fact'],
      usua_CreacionNavigation: json['usua_CreacionNavigation'],
      usua_ModificacionNavigation: json['usua_ModificacionNavigation'],
      tbPagosCuentasPorCobrar: json['tbPagosCuentasPorCobrar'] != null
          ? List<dynamic>.from(json['tbPagosCuentasPorCobrar'])
          : null,
    );
  }

  // Métodos útiles para mostrar información
  String get nombreCompleto {
    if (cliente != null && cliente!.isNotEmpty) {
      return cliente!;
    }
    if (clie_Nombres != null || clie_Apellidos != null) {
      return '${clie_Nombres ?? ''} ${clie_Apellidos ?? ''}'.trim();
    }
    return clie_NombreNegocio ?? 'Sin nombre';
  }

  String get telefonoFormateado {
    return clie_Telefono ?? 'Sin teléfono';
  }

  double get totalVencimientosPorRango {
    return (actual ?? 0) + (v1_30 ?? 0) + (v31_60 ?? 0) + (v61_90 ?? 0) + (mayor90 ?? 0);
  }

  bool get tieneDeudaVencida {
    return (v1_30 ?? 0) > 0 || (v31_60 ?? 0) > 0 || (v61_90 ?? 0) > 0 || (mayor90 ?? 0) > 0;
  }

  String get estadoDescripcion {
    if (cpCo_Anulado == true) return 'Anulado';
    if (cpCo_Saldada == true) return 'Saldado';
    if (tieneDeudaVencida) return 'Vencido';
    return 'Pendiente';
  }
}