class DireccionCliente {
  final int? diClId;
  final int clieId;
  final int coloId;
  final String direccionExacta;
  final String? observaciones;
  final double latitud;
  final double longitud;
  final int usuaCreacion;
  final DateTime fechaCreacion;
  final int? usuaModificacion;
  final DateTime? fechaModificacion;

  DireccionCliente({
    this.diClId,
    required this.clieId,
    required this.coloId,
    required this.direccionExacta,
    this.observaciones,
    required this.latitud,
    required this.longitud,
    required this.usuaCreacion,
    required this.fechaCreacion,
    this.usuaModificacion,
    this.fechaModificacion,
  });

  Map<String, dynamic> toJson() {
    return {
      'diCl_Id': diClId ?? 0,
      'clie_Id': clieId,
      'colo_Id': coloId,
      'diCl_DireccionExacta': direccionExacta,
      'diCl_Observaciones': observaciones ?? '',
      'diCl_Latitud': latitud,
      'diCl_Longitud': longitud,
      'usua_Creacion': usuaCreacion,
      'diCl_FechaCreacion': fechaCreacion.toIso8601String(),
      'usua_Modificacion': usuaModificacion ?? 0,
      'diCl_FechaModificacion': fechaModificacion?.toIso8601String(),
    };
  }

  DireccionCliente copyWith({
    int? diClId,
    int? clieId,
    int? coloId,
    String? direccionExacta,
    String? observaciones,
    double? latitud,
    double? longitud,
    int? usuaCreacion,
    DateTime? fechaCreacion,
    int? usuaModificacion,
    DateTime? fechaModificacion,
  }) {
    return DireccionCliente(
      diClId: diClId ?? this.diClId,
      clieId: clieId ?? this.clieId,
      coloId: coloId ?? this.coloId,
      direccionExacta: direccionExacta ?? this.direccionExacta,
      observaciones: observaciones ?? this.observaciones,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      usuaCreacion: usuaCreacion ?? this.usuaCreacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      usuaModificacion: usuaModificacion ?? this.usuaModificacion,
      fechaModificacion: fechaModificacion ?? this.fechaModificacion,
    );
  }
}

class Colonia {
  final int coloId;
  final String coloDescripcion;
  final String muniCodigo;
  final String muniDescripcion;
  final String depaCodigo;
  final String depaDescripcion;

  Colonia({
    required this.coloId,
    required this.coloDescripcion,
    required this.muniCodigo,
    required this.muniDescripcion,
    required this.depaCodigo,
    required this.depaDescripcion,
  });

  factory Colonia.fromJson(Map<String, dynamic> json) {
    return Colonia(
      coloId: json['colo_Id'],
      coloDescripcion: json['colo_Descripcion'],
      muniCodigo: json['muni_Codigo'],
      muniDescripcion: json['muni_Descripcion'] ?? '',
      depaCodigo: json['depa_Codigo'] ?? '',
      depaDescripcion: json['depa_Descripcion'] ?? '',
    );
  }
}
