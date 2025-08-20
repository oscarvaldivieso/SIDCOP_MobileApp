class VendedoresPorRutaModel {
  final int? secuencia;
  final int veRu_Id;
  final int vend_Id;
  final String? vendedorNombre;
  final String? vendedorApellido;
  final int ruta_Id;
  final String? rutaCodigo;
  final String? rutaDescripcion;
  final String veRu_Dias;
  final bool vend_Estado;
  final int usua_Creacion;
  final String? usuarioCreacion;
  final DateTime vend_FechaCreacion;
  final int? usua_Modificacion;
  final String? usuarioModificacion;
  final DateTime? vend_FechaModificacion;

  VendedoresPorRutaModel({
    this.secuencia,
    required this.veRu_Id,
    required this.vend_Id,
    this.vendedorNombre,
    this.vendedorApellido,
    required this.ruta_Id,
    this.rutaCodigo,
    this.rutaDescripcion,
    required this.veRu_Dias,
    required this.vend_Estado,
    required this.usua_Creacion,
    this.usuarioCreacion,
    required this.vend_FechaCreacion,
    this.usua_Modificacion,
    this.usuarioModificacion,
    this.vend_FechaModificacion,
  });

  factory VendedoresPorRutaModel.fromJson(Map<String, dynamic> json) {
    return VendedoresPorRutaModel(
      secuencia: json['secuencia'],
      veRu_Id: json['veRu_Id'],
      vend_Id: json['vend_Id'],
      vendedorNombre: json['vendedorNombre'],
      vendedorApellido: json['vendedorApellido'],
      ruta_Id: json['ruta_Id'],
      rutaCodigo: json['rutaCodigo'],
      rutaDescripcion: json['rutaDescripcion'],
      veRu_Dias: json['veRu_Dias'],
      vend_Estado: json['vend_Estado'],
      usua_Creacion: json['usua_Creacion'],
      usuarioCreacion: json['usuarioCreacion'],
      vend_FechaCreacion: DateTime.parse(json['vend_FechaCreacion']),
      usua_Modificacion: json['usua_Modificacion'],
      usuarioModificacion: json['usuarioModificacion'],
      vend_FechaModificacion: json['vend_FechaModificacion'] != null
          ? DateTime.parse(json['vend_FechaModificacion'])
          : null,
    );
  }
}
