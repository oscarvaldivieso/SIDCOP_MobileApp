// Modelo de historial de visitas de clientes basado en ClientesVisitaHistorialViewModel (C#)
// Incluye mapeo fromJson/toJson y campos opcionales. Ajusta las claves según la API real.

class ClientesVisitaHistorialModel {
  final int hcviId;
  final int? veruId; // VeRu_Id
  final int? clieId; // Clie_Id
  final String? hcviFoto;
  final String? hcviObservaciones;
  final DateTime? hcviFecha;
  final double? hcviLatitud;
  final double? hcviLongitud;
  final int usuaCreacion;
  final DateTime hcviFechaCreacion;
  // NotMapped en backend
  final String? veruDias; // Veru_Dias
  final String? cliente; // Cliente (nombre completo quizá)
  final String? clieNombreNegocio; // Clie_NombreNegocio
  final int? secuencia; // Secuencia

  ClientesVisitaHistorialModel({
    required this.hcviId,
    required this.veruId,
    required this.clieId,
    required this.hcviFoto,
    required this.hcviObservaciones,
    required this.hcviFecha,
    required this.hcviLatitud,
    required this.hcviLongitud,
    required this.usuaCreacion,
    required this.hcviFechaCreacion,
    this.veruDias,
    this.cliente,
    this.clieNombreNegocio,
    this.secuencia,
  });

  factory ClientesVisitaHistorialModel.fromJson(Map<String, dynamic> json) {
    // Aseguramos conversión robusta de numéricos y fechas
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return ClientesVisitaHistorialModel(
      hcviId: parseInt(json['hcvi_Id'] ?? json['HCVi_Id']) ?? 0,
      veruId: parseInt(json['veru_Id'] ?? json['VeRu_Id']),
      clieId: parseInt(json['clie_Id'] ?? json['Clie_Id']),
      hcviFoto: json['hcvi_Foto'] ?? json['HCVi_Foto'],
      hcviObservaciones: json['hcvi_Observaciones'] ?? json['HCVi_Observaciones'],
      hcviFecha: parseDate(json['hcvi_Fecha'] ?? json['HCVi_Fecha']),
      hcviLatitud: parseDouble(json['hcvi_Latitud'] ?? json['HCVi_Latitud']),
      hcviLongitud: parseDouble(json['hcvi_Longitud'] ?? json['HCVi_Longitud']),
      usuaCreacion: parseInt(json['usua_Creacion'] ?? json['Usua_Creacion']) ?? 0,
      hcviFechaCreacion: parseDate(json['hcvi_FechaCreacion'] ?? json['HCVi_FechaCreacion']) ?? DateTime.now(),
      veruDias: json['veru_Dias'] ?? json['Veru_Dias'],
      cliente: json['cliente'] ?? json['Cliente'],
      clieNombreNegocio: json['clie_NombreNegocio'] ?? json['Clie_NombreNegocio'],
      secuencia: parseInt(json['secuencia'] ?? json['Secuencia']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'HCVi_Id': hcviId,
      'VeRu_Id': veruId,
      'Clie_Id': clieId,
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
