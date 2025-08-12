class DireccionCliente {
  final int dicl_id;
  final int clie_id;
  final int colo_id;
  final String dicl_direccionexacta;
  final String dicl_observaciones;
  final double? dicl_latitud;
  final double? dicl_longitud;
  final String muni_descripcion;
  final String depa_descripcion;
  final int usua_creacion;
  final DateTime dicl_fechacreacion;
  final int? usua_modificacion;
  final DateTime? dicl_fechamodificacion;

  DireccionCliente({
    required this.dicl_id,
    required this.clie_id,
    required this.colo_id,
    required this.dicl_direccionexacta,
    required this.dicl_observaciones,
    this.dicl_latitud,
    this.dicl_longitud,
    required this.muni_descripcion,
    required this.depa_descripcion,
    required this.usua_creacion,
    required this.dicl_fechacreacion,
    this.usua_modificacion,
    this.dicl_fechamodificacion,
  });

  static DireccionCliente fromJson(Map<String, dynamic> json) {
    return DireccionCliente(
      dicl_id: json['diCl_Id'],
      clie_id: json['clie_Id'],
      colo_id: json['colo_Id'],
      dicl_direccionexacta: json['diCl_DireccionExacta'],
      dicl_observaciones: json['diCl_Observaciones'],
      dicl_latitud: json['diCl_Latitud'] != null
          ? double.tryParse(json['diCl_Latitud'].toString())
          : null,
      dicl_longitud: json['diCl_Longitud'] != null
          ? double.tryParse(json['diCl_Longitud'].toString())
          : null,
      muni_descripcion: json['muni_Descripcion'] ?? '',
      depa_descripcion: json['depa_Descripcion'] ?? '',
      usua_creacion: json['usua_Creacion'],
      dicl_fechacreacion: json['diCl_FechaCreacion'] != null
          ? DateTime.parse(json['diCl_FechaCreacion'])
          : DateTime.now(),
      usua_modificacion: json['usua_Modificacion'],
      dicl_fechamodificacion: json['diCl_FechaModificacion'] != null
          ? DateTime.tryParse(json['diCl_FechaModificacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dicl_id': dicl_id,
      'clie_id': clie_id,
      'colo_id': colo_id,
      'dicl_direccionexacta': dicl_direccionexacta,
      'dicl_observaciones': dicl_observaciones,
      'dicl_latitud': dicl_latitud,
      'dicl_longitud': dicl_longitud,
      'muni_descripcion': muni_descripcion,
      'depa_descripcion': depa_descripcion,
      'usua_creacion': usua_creacion,
      'dicl_fechacreacion': dicl_fechacreacion.toIso8601String(),
      'usua_modificacion': usua_modificacion,
      'dicl_fechamodificacion': dicl_fechamodificacion?.toIso8601String(),
    };
  }

  DireccionCliente copyWith({
    int? dicl_id,
    int? clie_id,
    int? colo_id,
    String? dicl_direccionexacta,
    String? dicl_observaciones,
    double? dicl_latitud,
    double? dicl_longitud,
    String? muni_descripcion,
    String? depa_descripcion,
    int? usua_creacion,
    DateTime? dicl_fechacreacion,
    int? usua_modificacion,
    DateTime? dicl_fechamodificacion,
  }) {
    return DireccionCliente(
      dicl_id: dicl_id ?? this.dicl_id,
      clie_id: clie_id ?? this.clie_id,
      colo_id: colo_id ?? this.colo_id,
      dicl_direccionexacta: dicl_direccionexacta ?? this.dicl_direccionexacta,
      dicl_observaciones: dicl_observaciones ?? this.dicl_observaciones,
      dicl_latitud: dicl_latitud ?? this.dicl_latitud,
      dicl_longitud: dicl_longitud ?? this.dicl_longitud,
      muni_descripcion: muni_descripcion ?? this.muni_descripcion,
      depa_descripcion: depa_descripcion ?? this.depa_descripcion,
      usua_creacion: usua_creacion ?? this.usua_creacion,
      dicl_fechacreacion: dicl_fechacreacion ?? this.dicl_fechacreacion,
      usua_modificacion: usua_modificacion ?? this.usua_modificacion,
      dicl_fechamodificacion:
          dicl_fechamodificacion ?? this.dicl_fechamodificacion,
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
