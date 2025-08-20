class EstadoVisitaModel {
  final int? esVi_Id;
  final String? esVi_Descripcion;
  final int? usua_Creacion;
  final DateTime? esVi_FechaCreacion;
  final int? usua_Modificacion;
  final DateTime? esVi_FechaModificacion;
  final int? secuencia;
  final String? usuarioCreacion;
  final String? usuarioModificacion;

  EstadoVisitaModel({
    this.esVi_Id,
    this.esVi_Descripcion,
    this.usua_Creacion,
    this.esVi_FechaCreacion,
    this.usua_Modificacion,
    this.esVi_FechaModificacion,
    this.secuencia,
    this.usuarioCreacion,
    this.usuarioModificacion,
  });

  factory EstadoVisitaModel.fromJson(Map<String, dynamic> json) {
    return EstadoVisitaModel(
      esVi_Id: json['EsVi_Id'] as int?,
      esVi_Descripcion: json['EsVi_Descripcion'] as String?,
      usua_Creacion: json['Usua_Creacion'] as int?,
      esVi_FechaCreacion: json['EsVi_FechaCreacion'] == null
          ? null
          : DateTime.tryParse(json['EsVi_FechaCreacion']),
      usua_Modificacion: json['Usua_Modificacion'] as int?,
      esVi_FechaModificacion: json['EsVi_FechaModificacion'] == null
          ? null
          : DateTime.tryParse(json['EsVi_FechaModificacion']),
      secuencia: json['Secuencia'] as int?,
      usuarioCreacion: json['UsuarioCreacion'] as String?,
      usuarioModificacion: json['UsuarioModificacion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EsVi_Id': esVi_Id,
      'EsVi_Descripcion': esVi_Descripcion,
      'Usua_Creacion': usua_Creacion,
      'EsVi_FechaCreacion': esVi_FechaCreacion?.toIso8601String(),
      'Usua_Modificacion': usua_Modificacion,
      'EsVi_FechaModificacion': esVi_FechaModificacion?.toIso8601String(),
      'Secuencia': secuencia,
      'UsuarioCreacion': usuarioCreacion,
      'UsuarioModificacion': usuarioModificacion,
    };
  }
}
