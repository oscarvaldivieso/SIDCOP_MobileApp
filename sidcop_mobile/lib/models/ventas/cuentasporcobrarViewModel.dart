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
  final String? clie_NombreNegocio;
  final String? clie_Telefono;
  final double? clie_LimiteCredito;
  final double? clie_Saldo;
  final String? usuarioCreacion;
  final String? usuarioModificacion;
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
    this.clie_NombreNegocio,
    this.clie_Telefono,
    this.clie_LimiteCredito,
    this.clie_Saldo,
    this.usuarioCreacion,
    this.usuarioModificacion,
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
      "clie_NombreNegocio": clie_NombreNegocio,
      "clie_Telefono": clie_Telefono,
      "clie_LimiteCredito": clie_LimiteCredito,
      "clie_Saldo": clie_Saldo,
      "usuarioCreacion": usuarioCreacion,
      "usuarioModificacion": usuarioModificacion,
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
      clie_NombreNegocio: json['clie_NombreNegocio'],
      clie_Telefono: json['clie_Telefono'],
      clie_LimiteCredito: json['clie_LimiteCredito'] != null
          ? double.tryParse(json['clie_LimiteCredito'].toString())
          : null,
      clie_Saldo: json['clie_Saldo'] != null
          ? double.tryParse(json['clie_Saldo'].toString())
          : null,
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
      clie: json['clie'],
      fact: json['fact'],
      usua_CreacionNavigation: json['usua_CreacionNavigation'],
      usua_ModificacionNavigation: json['usua_ModificacionNavigation'],
      tbPagosCuentasPorCobrar: json['tbPagosCuentasPorCobrar'] != null
          ? List<dynamic>.from(json['tbPagosCuentasPorCobrar'])
          : null,
    );
  }
}