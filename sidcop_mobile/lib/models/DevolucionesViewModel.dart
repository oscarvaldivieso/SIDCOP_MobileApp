class DevolucionesViewModel {
  final int devoId;
  final int? factId;
  final DateTime devoFecha;
  final String devoMotivo;
  final int usuaCreacion;
  final DateTime devoFechaCreacion;
  final int? usuaModificacion;
  final DateTime? devoFechaModificacion;
  final bool devoEstado;
  final String? nombreCompleto;
  final String? clieNombreNegocio;
  final String? usuarioCreacion;
  final String? usuarioModificacion;

  DevolucionesViewModel({
    required this.devoId,
    this.factId,
    required this.devoFecha,
    required this.devoMotivo,
    required this.usuaCreacion,
    required this.devoFechaCreacion,
    this.usuaModificacion,
    this.devoFechaModificacion,
    required this.devoEstado,
    this.nombreCompleto,
    this.clieNombreNegocio,
    this.usuarioCreacion,
    this.usuarioModificacion,
  });

  factory DevolucionesViewModel.fromJson(Map<String, dynamic> json) {
    return DevolucionesViewModel(
      devoId: json['devo_Id'],
      factId: json['fact_Id'],
      devoFecha: DateTime.parse(json['devo_Fecha']),
      devoMotivo: json['devo_Motivo'],
      usuaCreacion: json['usua_Creacion'],
      devoFechaCreacion: DateTime.parse(json['devo_FechaCreacion']),
      usuaModificacion: json['usua_Modificacion'],
      devoFechaModificacion: json['devo_FechaModificacion'] != null 
          ? DateTime.parse(json['devo_FechaModificacion']) 
          : null,
      devoEstado: json['devo_Estado'],
      nombreCompleto: json['nombre_Completo'],
      clieNombreNegocio: json['clie_NombreNegocio'],
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'devo_Id': devoId,
      'fact_Id': factId,
      'devo_Fecha': devoFecha.toIso8601String(),
      'devo_Motivo': devoMotivo,
      'usua_Creacion': usuaCreacion,
      'devo_FechaCreacion': devoFechaCreacion.toIso8601String(),
      'usua_Modificacion': usuaModificacion,
      'devo_FechaModificacion': devoFechaModificacion?.toIso8601String(),
      'devo_Estado': devoEstado,
      'nombre_Completo': nombreCompleto,
      'clie_NombreNegocio': clieNombreNegocio,
      'usuarioCreacion': usuarioCreacion,
      'usuarioModificacion': usuarioModificacion,
    };
  }
}
