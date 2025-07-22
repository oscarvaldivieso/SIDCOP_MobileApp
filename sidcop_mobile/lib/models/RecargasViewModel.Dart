class RecargasViewModel {
  final int? reca_Id;
  final int? empl_Id;
  final int? bode_Id;
  final int? tras_Id;
  final DateTime? reca_Fecha;
  final String? reca_Observacion;
  final String? reca_Confirmacion; // "p", "A", "R"
  final int? usua_Confirmacion;
  final int? usua_Creacion;
  final DateTime? reca_FechaCreacion;
  final int? usua_Modificacion;
  final DateTime? reca_FechaModificacion;
  final bool? reca_Estado;

  // Detalle de recarga
  final int? reDe_Id;
  final int? prod_Id;
  final int? reDe_Cantidad;
  final String? reDe_Observaciones;

  // Producto relacionado
  final String? prod_DescripcionCorta;
  final String? prod_Codigo;
  final String? prod_Imagen;

  RecargasViewModel({
    this.reca_Id,
    this.empl_Id,
    this.bode_Id,
    this.tras_Id,
    this.reca_Fecha,
    this.reca_Observacion,
    this.reca_Confirmacion,
    this.usua_Confirmacion,
    this.usua_Creacion,
    this.reca_FechaCreacion,
    this.usua_Modificacion,
    this.reca_FechaModificacion,
    this.reca_Estado,
    this.reDe_Id,
    this.prod_Id,
    this.reDe_Cantidad,
    this.reDe_Observaciones,
    this.prod_DescripcionCorta,
    this.prod_Codigo,
    this.prod_Imagen,
  });

  factory RecargasViewModel.fromJson(Map<String, dynamic> json) {
    return RecargasViewModel(
      reca_Id: json['reca_Id'],
      empl_Id: json['empl_Id'],
      bode_Id: json['bode_Id'],
      tras_Id: json['tras_Id'],
      reca_Fecha: json['reca_Fecha'] != null ? DateTime.tryParse(json['reca_Fecha']) : null,
      reca_Observacion: json['reca_Observacion'],
      reca_Confirmacion: json['reca_Confirmacion'],
      usua_Confirmacion: json['usua_Confirmacion'],
      usua_Creacion: json['usua_Creacion'],
      reca_FechaCreacion: json['reca_FechaCreacion'] != null ? DateTime.tryParse(json['reca_FechaCreacion']) : null,
      usua_Modificacion: json['usua_Modificacion'],
      reca_FechaModificacion: json['reca_FechaModificacion'] != null ? DateTime.tryParse(json['reca_FechaModificacion']) : null,
      reca_Estado: json['reca_Estado'],
      reDe_Id: json['reDe_Id'],
      prod_Id: json['prod_Id'],
      reDe_Cantidad: json['reDe_Cantidad'],
      reDe_Observaciones: json['reDe_Observaciones'],
      prod_DescripcionCorta: json['prod_DescripcionCorta'],
      prod_Codigo: json['prod_Codigo'],
      prod_Imagen: json['prod_Imagen'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reca_Id': reca_Id,
      'empl_Id': empl_Id,
      'bode_Id': bode_Id,
      'tras_Id': tras_Id,
      'reca_Fecha': reca_Fecha?.toIso8601String(),
      'reca_Observacion': reca_Observacion,
      'reca_Confirmacion': reca_Confirmacion,
      'usua_Confirmacion': usua_Confirmacion,
      'usua_Creacion': usua_Creacion,
      'reca_FechaCreacion': reca_FechaCreacion?.toIso8601String(),
      'usua_Modificacion': usua_Modificacion,
      'reca_FechaModificacion': reca_FechaModificacion?.toIso8601String(),
      'reca_Estado': reca_Estado,
      'reDe_Id': reDe_Id,
      'prod_Id': prod_Id,
      'reDe_Cantidad': reDe_Cantidad,
      'reDe_Observaciones': reDe_Observaciones,
      'prod_DescripcionCorta': prod_DescripcionCorta,
      'prod_Codigo': prod_Codigo,
      'prod_Imagen': prod_Imagen,
    };
  }
}