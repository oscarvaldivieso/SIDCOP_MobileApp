// Archivo: lib/models/ventas/formaPago.dart

class FormaPago {
  final int foPaId;
  final String foPaDescripcion;
  final int? usuaCreacion;
  final String? usuarioCreacion;
  final int secuencia;
  final DateTime foPaFechaCreacion;
  final int? usuaModificacion;
  final String? usuarioModificacion;
  final DateTime? foPaFechaModificacion;

  FormaPago({
    required this.foPaId,
    required this.foPaDescripcion,
    this.usuaCreacion,
    this.usuarioCreacion,
    required this.secuencia,
    required this.foPaFechaCreacion,
    this.usuaModificacion,
    this.usuarioModificacion,
    this.foPaFechaModificacion,
  });

  factory FormaPago.fromJson(Map<String, dynamic> json) {
    return FormaPago(
      foPaId: json['foPa_Id'] ?? 0,
      foPaDescripcion: json['foPa_Descripcion'] ?? '',
      usuaCreacion: json['usua_Creacion'],
      usuarioCreacion: json['usuaCreacion'],
      secuencia: json['secuencia'] ?? 0,
      foPaFechaCreacion: json['foPa_FechaCreacion'] != null 
          ? DateTime.parse(json['foPa_FechaCreacion'])
          : DateTime.now(),
      usuaModificacion: json['usua_Modificacion'],
      usuarioModificacion: json['usuaModificacion'],
      foPaFechaModificacion: json['foPa_FechaModificacion'] != null 
          ? DateTime.parse(json['foPa_FechaModificacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foPa_Id': foPaId,
      'foPa_Descripcion': foPaDescripcion,
      'usua_Creacion': usuaCreacion,
      'usuaCreacion': usuarioCreacion,
      'secuencia': secuencia,
      'foPa_FechaCreacion': foPaFechaCreacion.toIso8601String(),
      'usua_Modificacion': usuaModificacion,
      'usuaModificacion': usuarioModificacion,
      'foPa_FechaModificacion': foPaFechaModificacion?.toIso8601String(),
    };
  }

  @override
  String toString() => foPaDescripcion;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormaPago && other.foPaId == foPaId;
  }

  @override
  int get hashCode => foPaId.hashCode;
}