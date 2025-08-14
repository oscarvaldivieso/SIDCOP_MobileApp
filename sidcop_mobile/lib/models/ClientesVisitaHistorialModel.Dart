
class ClientesVisitaHistorialModel {
  final int clVi_Id;
  final int? veRu_Id;
  final int? diCl_Id;
  final int? esVi_Id;
  final String clVi_Observaciones;
  final DateTime? clVi_Fecha;
  final int usua_Creacion;
  final DateTime clVi_FechaCreacion;
  // NotMapped fields
  final String? veru_Dias;
  final String? cliente;
  final String? clie_NombreNegocio;
  final String? diCl_Latitud;
  final String? diCl_Longitud;
  final String? esV_Descripcion;
  final int? secuencia;

  ClientesVisitaHistorialModel({
    required this.clVi_Id,
    this.veRu_Id,
    this.diCl_Id,
    this.esVi_Id,
    this.clVi_Observaciones = '',
    this.clVi_Fecha,
    required this.usua_Creacion,
    required this.clVi_FechaCreacion,
    this.veru_Dias,
    this.cliente,
    this.clie_NombreNegocio,
    this.diCl_Latitud,
    this.diCl_Longitud,
    this.esV_Descripcion,
    this.secuencia,
  });

  factory ClientesVisitaHistorialModel.fromJson(Map<String, dynamic> json) {
    return ClientesVisitaHistorialModel(
      clVi_Id: json['ClVi_Id'] as int,
      veRu_Id: json['VeRu_Id'] as int?,
      diCl_Id: json['DiCl_Id'] as int?,
      esVi_Id: json['EsVi_Id'] as int?,
      clVi_Observaciones: json['ClVi_Observaciones'] as String? ?? '',
      clVi_Fecha: json['ClVi_Fecha'] == null ? null : DateTime.tryParse(json['ClVi_Fecha']),
      usua_Creacion: json['Usua_Creacion'] as int,
      clVi_FechaCreacion: json['ClVi_FechaCreacion'] == null ? DateTime.now() : DateTime.parse(json['ClVi_FechaCreacion']),
      veru_Dias: json['Veru_Dias'] as String?,
      cliente: json['Cliente'] as String?,
      clie_NombreNegocio: json['Clie_NombreNegocio'] as String?,
      diCl_Latitud: json['DiCl_Latitud'] as String?,
      diCl_Longitud: json['DiCl_Longitud'] as String?,
      esV_Descripcion: json['EsV_Descripcion'] as String?,
      secuencia: json['Secuencia'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ClVi_Id': clVi_Id,
      'VeRu_Id': veRu_Id,
      'DiCl_Id': diCl_Id,
      'EsVi_Id': esVi_Id,
      'ClVi_Observaciones': clVi_Observaciones,
      'ClVi_Fecha': clVi_Fecha?.toIso8601String(),
      'Usua_Creacion': usua_Creacion,
      'ClVi_FechaCreacion': clVi_FechaCreacion.toIso8601String(),
      'Veru_Dias': veru_Dias,
      'Cliente': cliente,
      'Clie_NombreNegocio': clie_NombreNegocio,
      'DiCl_Latitud': diCl_Latitud,
      'DiCl_Longitud': diCl_Longitud,
      'EsV_Descripcion': esV_Descripcion,
      'Secuencia': secuencia,
    };
  }
      'HCVi_Foto': hcviFoto,
      'HCVi_Observaciones': hcviObservaciones,
      'HCVi_Fecha': hcviFecha?.toIso8601String(),
      'HCVi_Latitud': hcviLatitud,
      'HCVi_Longitud': hcviLongitud,
      'Usua_Creacion': usuaCreacion,
      'HCVi_FechaCreacion': hcviFechaCreacion.toIso8601String(),
      'Veru_Dias': veruDias,
      'Cliente': cliente,
      'Clie_NombreNegocio': clieNombreNegocio,
      'Secuencia': secuencia,
    };
  }

  ClientesVisitaHistorialModel copyWith({
    int? hcviId,
    int? veruId,
    int? clieId,
    String? hcviFoto,
    String? hcviObservaciones,
    DateTime? hcviFecha,
    double? hcviLatitud,
    double? hcviLongitud,
    int? usuaCreacion,
    DateTime? hcviFechaCreacion,
    String? veruDias,
    String? cliente,
    String? clieNombreNegocio,
    int? secuencia,
  }) {
    return ClientesVisitaHistorialModel(
      hcviId: hcviId ?? this.hcviId,
      veruId: veruId ?? this.veruId,
      clieId: clieId ?? this.clieId,
      hcviFoto: hcviFoto ?? this.hcviFoto,
      hcviObservaciones: hcviObservaciones ?? this.hcviObservaciones,
      hcviFecha: hcviFecha ?? this.hcviFecha,
      hcviLatitud: hcviLatitud ?? this.hcviLatitud,
      hcviLongitud: hcviLongitud ?? this.hcviLongitud,
      usuaCreacion: usuaCreacion ?? this.usuaCreacion,
      hcviFechaCreacion: hcviFechaCreacion ?? this.hcviFechaCreacion,
      veruDias: veruDias ?? this.veruDias,
      cliente: cliente ?? this.cliente,
      clieNombreNegocio: clieNombreNegocio ?? this.clieNombreNegocio,
      secuencia: secuencia ?? this.secuencia,
    );
  }
}
