class Metas {
  final int metaId;
  final String metaDescripcion;
  final String metaTipo;
  final String? metaFechaInicio;
  final String? metaFechaFin;
  final double? metaIngresos;
  final double? metaUnidades;
  final int? prodId;
  final int? cateId;
  final int vendId;
  final double progresoIngresos;
  final double progresoUnidades;
  final String? producto;
  final String? categoria;

  Metas({
    required this.metaId,
    required this.metaDescripcion,
    required this.metaTipo,
    this.metaFechaInicio,
    this.metaFechaFin,
    this.metaIngresos,
    this.metaUnidades,
    this.prodId,
    this.cateId,
    required this.vendId,
    required this.progresoIngresos,
    required this.progresoUnidades,
    this.producto,
    this.categoria,
  });

  factory Metas.fromJson(Map<String, dynamic> json) {
    return Metas(
      metaId: json['Meta_Id'] ?? 0,
      metaDescripcion: json['Meta_Descripcion'] ?? '',
      metaTipo: json['Meta_Tipo'] ?? '',
      metaFechaInicio: json['Meta_FechaInicio']?.toString(),
      metaFechaFin: json['Meta_FechaFin']?.toString(),
      metaIngresos: json['Meta_Ingresos'] != null ? (json['Meta_Ingresos'] as num).toDouble() : null,
      metaUnidades: json['Meta_Unidades'] != null ? (json['Meta_Unidades'] as num).toDouble() : null,
      prodId: json['Prod_Id'],
      cateId: json['Cate_Id'],
      vendId: json['Vend_Id'] ?? 0,
      progresoIngresos: (json['ProgresoIngresos'] ?? 0).toDouble(),
      progresoUnidades: (json['ProgresoUnidades'] ?? 0).toDouble(),
      producto: json['Producto']?.toString(),
      categoria: json['Categoria']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Meta_Id': metaId,
      'Meta_Descripcion': metaDescripcion,
      'Meta_Tipo': metaTipo,
      'Meta_FechaInicio': metaFechaInicio,
      'Meta_FechaFin': metaFechaFin,
      'Meta_Ingresos': metaIngresos,
      'Meta_Unidades': metaUnidades,
      'Prod_Id': prodId,
      'Cate_Id': cateId,
      'Vend_Id': vendId,
      'ProgresoIngresos': progresoIngresos,
      'ProgresoUnidades': progresoUnidades,
      'Producto': producto,
      'Categoria': categoria,
    };
  }
}
