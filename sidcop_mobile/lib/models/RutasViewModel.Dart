
class Ruta {
  final int ruta_Id;
  final String? ruta_Codigo;
  final String? ruta_Descripcion;
  final String? ruta_Observaciones;
  final int usua_Creacion;
  final DateTime ruta_FechaCreacion;
  final int? usua_Modificacion;
  final DateTime? ruta_FechaModificacion;
  final bool ruta_Estado;

  Ruta({
    required this.ruta_Id,
    required this.ruta_Codigo,
    required this.ruta_Descripcion,
    required this.ruta_Observaciones,
    required this.usua_Creacion,
    required this.ruta_FechaCreacion,
    this.usua_Modificacion,
    this.ruta_FechaModificacion,
    required this.ruta_Estado,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    return Ruta(
      ruta_Id: json['ruta_Id'],
      ruta_Codigo: json['ruta_Codigo'],
      ruta_Descripcion: json['ruta_Descripcion'],
      ruta_Observaciones: json['ruta_Observaciones'],
      usua_Creacion: json['usua_Creacion'],
      ruta_FechaCreacion: DateTime.parse(json['ruta_FechaCreacion']),
      usua_Modificacion: json['usua_Modificacion'],
      ruta_FechaModificacion: json['ruta_FechaModificacion'] != null ? DateTime.parse(json['ruta_FechaModificacion']) : null,
      ruta_Estado: json['ruta_Estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ruta_Id': ruta_Id,
      'ruta_Codigo': ruta_Codigo,
      'ruta_Descripcion': ruta_Descripcion,
      'ruta_Observaciones': ruta_Observaciones,
      'usua_Creacion': usua_Creacion,
      'ruta_FechaCreacion': ruta_FechaCreacion.toUtc().toIso8601String(),
      'usua_Modificacion': usua_Modificacion,
      'ruta_FechaModificacion': ruta_FechaModificacion?.toUtc().toIso8601String(),
      'ruta_Estado': ruta_Estado,
    };
  }
}
