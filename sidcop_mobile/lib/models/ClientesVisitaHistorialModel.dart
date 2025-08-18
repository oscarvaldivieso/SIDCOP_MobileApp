class ClientesVisitaHistorialModel {
  final int? clVi_Id;
  final int? diCl_Id;
  final double? diCl_Latitud;
  final double? diCl_Longitud;
  final int? vend_Id;
  final String? vend_Codigo;
  final String? vend_DNI;
  final String? vend_Nombres;
  final String? vend_Apellidos;
  final String? vend_Telefono;
  final String? vend_Tipo;
  final String? vend_Imagen;
  final int? ruta_Id;
  final String? ruta_Descripcion;
  final int? veRu_Id;
  final String? veRu_Dias;
  final int? clie_Id;
  final String? clie_Codigo;
  final String? clie_Nombres;
  final String? clie_Apellidos;
  final String? clie_NombreNegocio;
  final String? imVi_Imagen;
  final String? clie_Telefono;
  final int? esVi_Id;
  final String? esVi_Descripcion;
  final String? clVi_Observaciones;
  final DateTime? clVi_Fecha;
  final int? usua_Creacion;
  final DateTime? clVi_FechaCreacion;

  ClientesVisitaHistorialModel({
    this.clVi_Id,
    this.diCl_Id,
    this.diCl_Latitud,
    this.diCl_Longitud,
    this.vend_Id,
    this.vend_Codigo,
    this.vend_DNI,
    this.vend_Nombres,
    this.vend_Apellidos,
    this.vend_Telefono,
    this.vend_Tipo,
    this.vend_Imagen,
    this.ruta_Id,
    this.ruta_Descripcion,
    this.veRu_Id,
    this.veRu_Dias,
    this.clie_Id,
    this.clie_Codigo,
    this.clie_Nombres,
    this.clie_Apellidos,
    this.clie_NombreNegocio,
    this.imVi_Imagen,
    this.clie_Telefono,
    this.esVi_Id,
    this.esVi_Descripcion,
    this.clVi_Observaciones,
    this.clVi_Fecha,
    this.usua_Creacion,
    this.clVi_FechaCreacion,
  });

  factory ClientesVisitaHistorialModel.fromJson(Map<String, dynamic> json) {
    return ClientesVisitaHistorialModel(
      clVi_Id: json['ClVi_Id'] as int?,
      diCl_Id: json['DiCl_Id'] as int?,
      diCl_Latitud: (json['DiCl_Latitud'] as num?)?.toDouble(),
      diCl_Longitud: (json['DiCl_Longitud'] as num?)?.toDouble(),
      vend_Id: json['Vend_Id'] as int?,
      vend_Codigo: json['Vend_Codigo'] as String?,
      vend_DNI: json['Vend_DNI'] as String?,
      vend_Nombres: json['Vend_Nombres'] as String?,
      vend_Apellidos: json['Vend_Apellidos'] as String?,
      vend_Telefono: json['Vend_Telefono'] as String?,
      vend_Tipo: json['Vend_Tipo'] as String?,
      vend_Imagen: json['Vend_Imagen'] as String?,
      ruta_Id: json['Ruta_Id'] as int?,
      ruta_Descripcion: json['Ruta_Descripcion'] as String?,
      veRu_Id: json['VeRu_Id'] as int?,
      veRu_Dias: json['VeRu_Dias'] as String?,
      clie_Id: json['Clie_Id'] as int?,
      clie_Codigo: json['Clie_Codigo'] as String?,
      clie_Nombres: json['Clie_Nombres'] as String?,
      clie_Apellidos: json['Clie_Apellidos'] as String?,
      clie_NombreNegocio: json['Clie_NombreNegocio'] as String?,
      imVi_Imagen: json['ImVi_Imagen'] as String?,
      clie_Telefono: json['Clie_Telefono'] as String?,
      esVi_Id: json['EsVi_Id'] as int?,
      esVi_Descripcion: json['EsVi_Descripcion'] as String?,
      clVi_Observaciones: json['ClVi_Observaciones'] as String?,
      clVi_Fecha: json['ClVi_Fecha'] == null
          ? null
          : DateTime.tryParse(json['ClVi_Fecha']),
      usua_Creacion: json['Usua_Creacion'] as int?,
      clVi_FechaCreacion: json['ClVi_FechaCreacion'] == null
          ? null
          : DateTime.tryParse(json['ClVi_FechaCreacion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ClVi_Id': clVi_Id,
      'DiCl_Id': diCl_Id,
      'DiCl_Latitud': diCl_Latitud,
      'DiCl_Longitud': diCl_Longitud,
      'Vend_Id': vend_Id,
      'Vend_Codigo': vend_Codigo,
      'Vend_DNI': vend_DNI,
      'Vend_Nombres': vend_Nombres,
      'Vend_Apellidos': vend_Apellidos,
      'Vend_Telefono': vend_Telefono,
      'Vend_Tipo': vend_Tipo,
      'Vend_Imagen': vend_Imagen,
      'Ruta_Id': ruta_Id,
      'Ruta_Descripcion': ruta_Descripcion,
      'VeRu_Id': veRu_Id,
      'VeRu_Dias': veRu_Dias,
      'Clie_Id': clie_Id,
      'Clie_Codigo': clie_Codigo,
      'Clie_Nombres': clie_Nombres,
      'Clie_Apellidos': clie_Apellidos,
      'Clie_NombreNegocio': clie_NombreNegocio,
      'ImVi_Imagen': imVi_Imagen,
      'Clie_Telefono': clie_Telefono,
      'EsVi_Id': esVi_Id,
      'EsVi_Descripcion': esVi_Descripcion,
      'ClVi_Observaciones': clVi_Observaciones,
      'ClVi_Fecha': clVi_Fecha?.toIso8601String(),
      'Usua_Creacion': usua_Creacion,
      'ClVi_FechaCreacion': clVi_FechaCreacion?.toIso8601String(),
    };
  }
}
